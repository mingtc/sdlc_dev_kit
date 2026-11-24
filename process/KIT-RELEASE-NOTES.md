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

**A release's section opens with a `Linux:` line** saying whether the kit's self-test ran on Linux at the commit
the release was cut from, with the host and the tally when it did. A release can be cut without that run;
*not tested* then says so, and means only that.

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

1. **It stages the upgrade and commits nothing.** (A run whose only work is a module's record writes it and stops, with no checklist and no `--finish`: [`contracts/kit-upgrade.md`](contracts/kit-upgrade.md) § 2.) Every file you never changed is replaced by the new
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
   `process/upgrades/<from>-to-<to>.md` (`-2`, `-3`, … added when the versions are equal and the name is taken; the record of what was done, whatever merge strategy landed the
   upgrade) and removes `.kit-upgrade/`. It refuses while an item is unmarked, while a staged file it reads was edited or an item the first run listed is gone, while the new
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

### Changed

- **`./scripts/test/run.sh --core` also runs the early-exit reader's deterministic row.** `case_an_ac_bullet_reader_does_not_fail_when_the_body_runs_on_after_the_bullet` makes a card's body larger than one pipe write, so the defect that failed a card move now and then under load fails it every time; it is a core row now, where it was only in the full run.
- **The self-test's cell-check case reads the released notes where they now are.** `./scripts/test/run.sh` on the `0.13.1` kit fails one case, `case_the_cell_check_rule_verify_line_fails_on_a_begun_table_with_no_observed_row_and_only_on_one`: it read the `Verify:` line of an older release's Action required item out of `process/KIT-RELEASE-NOTES.md` alone, and the cut that made `0.13.1` moved that item into `process/KIT-RELEASE-HISTORY.md`. The case now reads the notes, then the history, through one helper in the test library, so it passes on a released tree. Nothing to do; a self-test case you added that reads a released item out of the notes alone has the same flaw and can use the same helper (`notes_verify_line`, `notes_item_head`).
- **`./scripts/pack.sh` lists, verifies, unpacks and removes the packs a project holds, and `./scripts/test/run.sh --list` counts the cases a pack holds.** A pack is a file of kit files shipped packed instead of loose; `unpack` records what it wrote beside the pack and `remove` takes back only those files; this release ships none, so `pack.sh list` finds nothing, `pack.sh unpack --all` does nothing and the harness runs the cases it ran before. The `CASES` array in `scripts/test/run.sh` now holds the smoke list, and `scripts/test/CASE-LIST` names the rest; if you added your own cases to that array, keep them in it when the upgrade merges the file.
- **The hygiene instruments say more and refuse more.** `scripts/hygiene/staleness_greps.py --root <not a directory>` exits 2, and a root with nothing in scope prints `n/a-control-failed` instead of `(no suspicion)`; every run prints how many files it read, and says artifact paths are read from the repository root only. `reachability_walk.py --self-test` no longer passes a probe that only the instruments' own sources cite, so on a tree whose probe nothing else cites it now ends `SELF-TEST FAIL`; point `BLIND_SPOT_PROBE` at an extension-less file of yours that is cited. The `BLIND SPOT` line counts directory and broken symlinks as well as file links, and a markdown link target written `a%20b.md` or `<a b.md>` now resolves instead of reading as an orphan. Nothing to do unless you wired one of these into a script that read their output.
- **`finish-pr.sh` and `subtask.sh new` take `--role <R>`, and a usage error prints one line, not the whole help.** The acting role could be given three ways (`--role` on `move-issue.sh` and `subtask.sh move`, `FINISH_PR_ROLE` and `SUBTASK_ROLE` for the others), and a wrong guess printed the script's whole header (91 lines for `finish-pr.sh`). Both now accept `--role <R>`, which wins over the variable; a bad option or a missing argument prints the error, one synopsis line and `--help`. `--help` is unchanged. A killed `finish-pr.sh` also removes its pre-merge worktree now, and `release.sh`'s version bump keeps the mode of the file it rewrites.
- **Two PM skills are adapted, not authored here.** `.claude/skills/write-spec/` and `.claude/skills/product-brainstorming/` come from Anthropic's `knowledge-work-plugins` under the Apache License 2.0; each directory now carries that `LICENSE` and a `NOTICE` saying what this kit changed, and the kit's `LICENSE` and `README.md` say the material is not relicensed. Nothing to do; if you redistribute those two skills, keep their `LICENSE` and `NOTICE` with them.

## [0.13.1] — 2026-11-24

Linux: tested — the kit's self-test ran on Linux 5.15.153.1-microsoft-standard-WSL2 x86_64 at 6e9f4970, the commit this release was cut from: 841 PASS, 0 FAIL, 4 SKIP.

### Action required

- **Name every add-on, template fragment and rule id in lowercase letters, digits and `-`, starting with a letter: a capital is now refused on every platform.** The name checks read a pattern range, and under bash 3.2 (the macOS default) with a UTF-8 locale a range like `a-z` also matches capitals, so `Foo` was accepted there and refused elsewhere; the shipped self-test was red on a stock Mac for the same reason. The checks now list the letters, so a fragment file, an add-on name, a requirement id or a rule id spelled with a capital is refused with the same `Next:` it always carried. Rename any such file before you upgrade.
  Verify: find process/fragments.d -type f ! -name README.md 2>/dev/null | awk -F/ '{ n = $NF; sub(/\..*/, "", n); if (n ~ /[A-Z]/) bad = 1 } END { exit bad }'
- **A design row says which comparison made it `identical`, and Dev makes both design images at handoff (design module 0.6.2).** The design module's QA cell check refuses a bare `identical` and takes `identical (image)` (the pin PNG and the build PNG compared) or `identical (structure)` (the pinned `.dc.html` read against the source; refused unless the pin's canvas is a wireframe canvas in effect at the pin); a seat that can do neither writes `diffs: <element ids>` or asks. Dev commits `dev/evidence/<card-id>/UX-NNN-<state>-pin.png` (`git show <pin>:requirements/design/<canvas>/renders/<Screen>-<state>.png > …`) and `…-build.png` to the trunk at handoff; `dev/evidence/README.md` exempts these fixed names from naming a file for its AC. A card already holding a PASS design row with a bare `identical` is refused at landing: rewrite the row. The line below names each such card; it does nothing in a project without the module.
  Verify: bad=0; for c in progress/{in_progress,blocked,dev_complete,qa_complete}/*.md progress/subtasks/*/{in_progress,blocked,dev_complete,qa_complete}/*.md; do [ -f "$c" ] || continue; awk -F'|' '$3 ~ /PASS/ && $4 ~ /design/ { p = $5; gsub(/"[^"]*"/, "", p); gsub(/`/, "", p); if (p ~ /@[0-9a-fA-F]+: *identical *([;,]|dev\/|UX-|$)/) f = 1 } END { exit !f }' "$c" && { echo "$c: a design row says a bare identical"; bad=1; }; done; [ "$bad" = 0 ]
- **Give every checklist line of a refactor card in flight, under `## Behaviors Preserved`, a `B<n>` id, before you finish the upgrade.** The landing now reads `## Behaviors Preserved` as the refactor card's acceptance criteria, the way it reads `## Acceptance Criteria`: a `- [ ]` line there that is not `- [ ] B<n> — <text>` (a notes-deliverable item written without an id, a `* [ ]` or indented line, an id with a dot) is refused `forks-ac-ungraded`, and a B id dropped or renamed after the card left `todo/` needs a `[decision: D-NN]` as a removed AC does (`forks-ac-changed-uncited`). Rewrite each such line as `- [ ] B<n> — <text>` with a distinct id, or make it plain prose, then commit the card with `./scripts/register-commit.sh`; a behavior you dropped stays on the card struck through with its ruling (`- [ ] ~~B3 — …~~ [decision: D-NN]`). The command below prints each offending line and exits 0 when none is left (it reads a commented-out line as a line, so it may name one the landing would not, and it does not see a removed id, which needs the card's history).
  Verify: for d in progress/todo progress/in_progress progress/dev_complete progress/blocked progress/qa_complete; do [ -d "$d" ] || continue; find "$d" -name '*.md' -exec awk 'FNR==1{f="";s=0} {sub(/\r$/,"")} {y=$0;sub(/^ ? ? ?/,"",y);z=substr(y,1,1);k=0;while(z!=""&&substr(y,k+1,1)==z)k++;q=substr(y,k+1);if(f==""){if(k>=3&&(z=="`"||z=="~")&&!(z=="`"&&index(q,"`"))){f=z;m=k;next}}else{if(z==f&&k>=m&&q~/^[ \t]*$/)f="";next}} /^##[ \t]/{h=tolower($0);sub(/^##[ \t]+/,"",h);sub(/[ \t]+$/,"",h);s=(h=="behaviors preserved"||index(h,"behaviors preserved (")==1);next} s && /^[ \t]*(>[ \t]*)*([-*+]|[0-9]+[.)])[ \t]+\[[ xX]\]/ && !/\[[ xX]\][ \t]+~~([^~]|~[^~])*~~[ \t]*(\[decision:[^]]*\][ \t]*)?$/ && !(/^(>[ \t]*)?(-|[0-9]+[.)]) \[[ xX]\] [A-Za-z][A-Za-z0-9]*[ \t]*(—|-|:)/ && !/^(>[ \t]*)?(-|[0-9]+[.)]) \[[ xX]\] [A-Za-z][A-Za-z0-9]*-[A-Za-z0-9]/) {print FILENAME ": " $0}' {} + || echo "awk failed in $d"; done | { ! grep .; }
- **Push the commits your local trunk holds before your next landing: `register-commit.sh`, `move-issue.sh`, `finish-pr.sh`, `subtask.sh` and `archive.sh` now refuse while the local trunk holds commits its remote lacks (`trunk-ahead`, `trunk-diverged`).** It used to land the commit on the remote's tip and warn afterwards, which left the local trunk diverged from the remote and grew the divergence with each landing. The refusal changes nothing, and its `Next:` gives two routes. First, for any commit that did not land through the gate (a branch merged into the local trunk by hand): set the commits aside on `<trunk>-unlanded-<sha>`, put the local trunk back on `<remote>/<trunk>`, and land that branch through `./scripts/finish-pr.sh <ID> --branch <name>`. Second, only for commits meant for the trunk as they are: `git push <remote> <trunk>` when the trunk is ahead; a merge of `<remote>/<trunk>`, then the push, when it is diverged. A trunk only behind its remote, or equal to it, lands as before. The remote is `origin` unless `KWT_REMOTE` names another. A landing no longer moves a local trunk ref that holds commits its remote lacks: the ref stays where it is and the landing says so (it used to reset that ref to the remote's trunk, silently, when the trunk was checked out in no worktree).
  Verify: r="${KWT_REMOTE:-origin}"; t="$(git symbolic-ref --short "refs/remotes/$r/HEAD" 2>/dev/null)"; t="${t#"$r"/}"; [ -n "$t" ] || t="$(git config init.defaultBranch)"; [ -n "$t" ] || t=main; ! git rev-parse -q --verify "refs/heads/$t" > /dev/null || ! git rev-parse -q --verify "refs/remotes/$r/$t" > /dev/null || [ "$(git rev-list --count "refs/remotes/$r/$t..refs/heads/$t")" = 0 ]
- **`kit-init.sh` and `verify.sh` refuse starts that used to pass: move any gate command in `scripts/verify.sh`'s `GATES` table that holds shell syntax into a script before you upgrade.** A gate command with shell syntax (`&&`, `;`, a redirection, `$`, parentheses, a backtick or a backslash) is refused where it is declared, in `kit-init --gate-command` and in the `GATES` table, because the runner executes its words and never interprets them: put the command in a script and name the script. `kit-init` also refuses, before it writes or pushes anything, a kit that is not at its repository's root, and a `--trunk` that the remote's own HEAD does not name (a local `git remote set-head` does not satisfy it; a remote it cannot ask refuses too); a `host:path` ssh alias is accepted as a remote URL. In a project that already has a `.gitignore`, `kit-init` adds the `.env` entries to it, and `setup.sh` no longer seeds a `.env` that git would not ignore.
  Verify: ! awk '/^GATES=\(/ { f = 1; next } f && /^\)/ { exit } f && !/^[[:space:]]*#/' scripts/verify.sh | cut -d'|' -f3- | grep -E '[&;<>()$`\\]'
- **Set `signoff` on every issue you pass a runner, or its QA leg will verify the change and not land it.** `tranche-runner.js` and `wave-runner.js` now hold the landing of an issue that carries no `signoff`: the QA leg reviews as before, leaves the branch unmerged and the card in `dev_complete/`, and the run logs `LAND_READY` with the route below (a success, not a failure). Set it per issue, in each issue object of the `issues` array (tranche) or the `wave1` and `wave2` arrays (wave), wherever your orchestrator or script builds that payload: `"signoff": "not_needed"` where the change reuses an established pattern and adds no new public surface, or `"recorded"` once the operator has signed the new surface off (the orchestrator's rule, unchanged); any other value is refused at 0 agents. To land a held branch, read its diff and run `./scripts/finish-pr.sh <issue id>` from the main repo directory, or set `signoff` and run again. A docs-path issue lands nothing and needs neither. If you edited your copies of the two runners, make the same change by hand.
  Verify: grep -q "'signoff'" .claude/workflows/tranche-runner.js && grep -q "'signoff'" .claude/workflows/wave-runner.js
- **The pre-merge gate in `finish-pr.sh` runs in a fresh detached worktree at the branch tip, not in your gate checkout: if your gate needs installed dependencies or other ignored files, declare `POST_MERGE_PREP` before your next landing.** An uncommitted edit or an untracked file in the checkout could turn a red branch green; it no longer reaches the gate. The worktree has none of your installed dependencies: if the gate needs them, declare `POST_MERGE_PREP` in `scripts/config.sh` (the trunk's declaration; it already prepares the post-merge worktree). A prep that fails refuses the landing (`premerge-prep-failed`), and a worktree that cannot be made refuses it too (`premerge-tree-unavailable`), each with a `Next:`.
  Verify: . scripts/lib/decision-register.sh || exit 2; d="$(mktemp -d)" || exit 2; git show HEAD:scripts/config.sh > "$d/c" || exit 2; p="$(kit_declared_value "$d/c" POST_MERGE_PREP)"; rm -f "$d/c"; git worktree add --detach --quiet "$d/t" HEAD > /dev/null 2>&1 || { rmdir "$d"; exit 2; }; rc=0; (cd "$d/t" && { [ -z "$p" ] || sh -c "$p" < /dev/null; } && ./scripts/verify.sh --quick) || rc=$?; chmod -R u+w "$d/t" 2> /dev/null; git worktree remove --force "$d/t"; rmdir "$d"; exit "$rc"
- **Keep a gate that runs on your trunk, or the move to `qa_complete/` by hand will refuse.** `move-issue.sh <id> qa_complete` without a `finish-pr.sh` landing behind it (a change you squash-merged by hand, or a card closed after a direct commit to the trunk) now runs the trunk's `./scripts/verify.sh --quick` on the trunk tip, in a fresh worktree, and refuses on a red, on a runner that did not run (an empty `GATES` table, or `--quick` over gates that are all class `full`) and on a gate that could not run; nothing is changed when it refuses. Declare at least one `core` or `select` gate in `scripts/verify.sh` (`./scripts/verify.sh --list` prints the table), and fix a red trunk before you close the card. The `qa.md` fallback that told QA to squash-merge by hand is gone: when `finish-pr.sh` cannot run, stop and hand off. A project that lands only through `finish-pr.sh` meets nothing new.
  Verify: ! ./scripts/verify.sh --list | grep -q 'the table is empty'
- **Take a card through `qa_complete/` before `done/`, and name a subtask by its full id.** `move-issue.sh <id> done` now refuses a card that is not in `qa_complete/` (it used to retire a card from any column, by any role, unreviewed); the sweep, `./scripts/archive.sh`, is what writes `done/`. `subtask.sh move` now takes only the full slice id, `<PARENT>-s<N>`: a parent id used to match every slice and move the first, and one id filed in two columns is refused naming both cards. A script, role document or habit of yours that moves a card straight to `done`, or a slice by its parent's id, must change: move the card to `qa_complete/` and let the sweep retire it, and name the slice.
  Verify: ! grep -rEq 'move-issue\.sh[[:space:]]+[^[:space:]|;&]+[[:space:]]+done([[:space:]]|$)' scripts .claude --exclude-dir=test --exclude=move-issue.sh 2>/dev/null

### Changed

- **A card move no longer fails now and then on a loaded machine, and kit-init's self-check with it.** `move-issue.sh` to `dev_complete` read a card's acceptance bullet through a program that stopped reading early while the card was still being written to it; on a busy machine the writer found the pipe closed and the move exited non-zero with `printf: write error: Broken pipe` and no refusal. The reader, and the other programs on the move, landing and `kit-init.sh` path that stopped early, now read to the end. Nothing to do; if a move failed that way, run it again.
- **The kit ships a `.gitattributes` that pins its shell programs, Python and Node scripts, and hooks to LF, so a checkout through `core.autocrlf=true` still runs.** Git for Windows' default (or a user-set config) wrote CRLF into every script of a clone of the kit, and day one died on `env: bash\r: No such file or directory`. The zip is unaffected; a clone, and the public mirror, were not. `kit-upgrade.sh` places the file like any other; if your project has its own `.gitattributes`, merge its patterns into yours by hand.
- **The date patterns in `archive-progress.sh` and `release.sh` no longer use `{n}` interval expressions inside awk.** An older mawk (the default `awk` of Debian 11 and 12 and of Ubuntu 20.04 and 22.04) reads `[0-9]{4}` as text, so `release.sh` could refuse `release-doc-date-missing` over a heading that already carried its date. The self-test now refuses an interval expression in any shipped awk program.
- **The stacked-branch refusals print a rebase onto the remote's trunk.** `stacked-branch-squashed-base` and `stacked-branch-unlanded-base` in `finish-pr.sh` now print `git fetch <remote> && git rebase --onto <remote>/<trunk> …`; they named the local trunk, which a fetch never moves, so a stale one gave a branch still missing the base's squash.
- **A commit the drift report keeps against the release gate is acknowledged with `./scripts/drift-ack.sh <sha> --role <Role> --reason "<why>"`.** `check-board.sh` arms `[e]` (no `[Role]` prefix) and `[h]` (a generated trailer) kept a commit they reported for good, and `release.sh` refused the cut on `board-drift` with no route short of rewriting published history; the `[e]`/`[h]` entry that said "Nothing to do" left that refusal out. The command refuses a sha outside the window the arms read, a missing or empty reason, a role you do not declare and a sha already acknowledged, and lands one row in the new `progress/drift-acknowledged.tsv` through `register-commit.sh`. The arms then list the commit with its role, date and reason and stop counting it, so `board-drift: clean` holds while it stays on show, and `release.sh` prints each one. One record covers a commit that bypassed the rule and one the rule never reached (a branch begun before adoption, a clone with no hook); the reason says which. A new arm `[e2]` reports any commit that edited the record by hand, and acknowledging that commit clears it. New files: `scripts/drift-ack.sh`, `scripts/lib/drift-window.sh`. No action unless your report is red on such a commit.
- **A clone of the kit gets its `process/KIT-MANIFEST` from `./scripts/kit-manifest.sh`, and the refusals that need the file name it.** The zip carries the manifest and a clone of the repository does not, so a clone could not run the self-test, and `kit-upgrade.sh` refused it as a source with a message that said `process/KIT-VERSION` was missing too. In an unmodified clone the script writes the manifest from the commit, never the working tree: it refuses while a tracked file differs, because the file would record the edit as shipped. It calls the function the release build calls, so the file matches the zip's. `kit-upgrade.sh`, `kit-init.sh`'s skip line, check-board arm `[v]` and the self-test's refusal now name the file that is missing and this command; the README's clone note says the step. No action for a project unpacked from a zip.
- **A line opening `**Answer` inside a question's own text is no longer read as an answer.** `check-board.sh` arm `[t]` and `register-commit.sh`'s unlanded-answer guard count an answer only below the file's `**To answer:**` line, the one `ask.sh` writes, and the last such line is the file's own. A question file written by `ask.sh` reads as before; one written by hand needs that line above its answer, or neither reads the answer. A report line and a landing check; no other action.
- **`check-board.sh` arm `[a]` no longer reads clean over a hand move that a `--note-only` entry followed, and says how many cards it could not judge.** It judges the last Activity bullet that carries a `→ <folder>` arrow, where it read only the last bullet and skipped a note (which has none). A clean line now reads `none across <n> column(s): <j> judged, <u> not judgeable`; a card with no `## Activity` section is counted apart. `done/` is still not read. A report line: a board that now reads drift had a card in the wrong folder.
- **`check-board.sh` reads `core.hooksPath` back and says when the commit guard is not wired.** A clone has none (the setting lives in `.git/config`, which is never committed), so the commit-message and pre-commit guards did not run there while the report said they still did. Arm `[g]` now prints `git hooks: core.hooksPath = scripts/githooks  ✓`, or a `⚠` line naming `./setup.sh --kit-only`, the one act that sets it; its `hooks: off` line and the `/start` skill claim the guard only where it is wired. A report line: the verdict does not move.
- **The brainstorming companion's WebSocket now needs the session token in the URL, and a browser must connect from the server's own origin.** `start-server.sh` prints a URL ending `/?token=<hex>`: open it as printed. A bare `http://localhost:<port>/` still loads the page, but its socket is refused, so no selection reaches the agent. A page open in the same browser can no longer send the agent a selection. Without `--project-dir`, the session directory under `/tmp` now has a random name and is owner-only.
- **A landing or a release run through a stubbed gate says `STUB`, never `PASS`, and no longer prints the switch.** `finish-pr.sh --help` and the refusal of a caller-supplied gate command stop naming the test-only marker, and `release.sh`'s refusal stops naming its own. If a script of yours reads `POST_MERGE_GATE:`, it can now also see `STUB` (only from a run that used a test-only gate command); the squash subject then carries `[STUB gate]` before `(squash-merge <branch>)`, and the Activity note says so. Nothing changes for a landing through the real gate.
- **A leftover board lock whose pid is alive no longer wedges the board.** A lock whose recorded process began after the lock was taken (its pid was reused after a crash or reboot) is reaped by the next op. A lock held by an older live process still refuses `kanban-lock-held`, but past the age an op runs (`KWT_LOCK_STALE`, 120s) the refusal prints the `ps` check of the holder and the exact `rm -rf` of the lock, where it said to leave it alone. `KWT_LOCK_WAIT` and `KWT_LOCK_STALE` now take their value from the environment.
- **Four refusals and warnings now print a route that works.** `finish-pr.sh` on a branch whose whole diff already landed (a landing cut short after its push) refuses `branch-already-landed` and names `move-issue.sh <ID> qa_complete --landed-at <sha>`, where it named a rebase; for a branch the remote does not have it no longer prints a `git fetch` that fails, and says the card has no code and names the move back to `in_progress`. A `.kanban-wt` you deleted by hand is pruned and recreated by the next op, where every run read it as offline and failed on `no file matching`; `register-commit.sh`'s advice names `git worktree prune`. When local trunk is both ahead of and behind the remote, the looks-pushed warning says to merge `<remote>/<trunk>` first and gives the command, where it printed a push the remote rejects.
- **`notify.sh` refuses a `NOTIFY_BACKEND` that holds a `/` or `..`.** A backend is a file name under `scripts/notify/`; `../x` reached `scripts/x.sh`, a script outside the adapters, and ran it. `notify.sh test` now exits 1 (`notify-no-adapter`) with a message that lists the available backends and a `Next:`, and a send warns and exits 0, as it does for any backend with no adapter. A plain file name is unchanged.
- **The fence and item reader reads more of a card as CommonMark does, for the landing and the design module's link check.** What follows a list marker on its own line is the item's first line, so a fence or quote opened there (`- ```sh`, `1. > note`; the `0.13.0` note said it was not read) is read; a thematic break (`- - -`, `---`) is no item and no lazy line of the one above; an HTML block start (a comment block, `<div>`, `<pre>`; not `<span>`) ends an item's paragraph; a tab after a `>` counts from the line's start. A card refused for an unclosed fence it did not have is accepted. One new refusal: a block quote ends at a blank line, so a fence inside a quote that holds a blank line without `>` is an unclosed fence (`forks-ac-unclosed-fence`; put `>` on the blank line). An HTML block is not read: its lines are read as paragraph text.
- **`check-board.sh`'s `TEST_GLOBS vs scripts/test/**` line now says what it is.** It names the kit's own self-test, not your tests, and ends with a `Next:` (add `"scripts/test/*"` to `TEST_GLOBS` to have edits to it ablation-checked, or leave the line). It is still a report and never moves the verdict; `scripts/config.sh`'s `TEST_GLOBS` comment says the same.
- **`kit-upgrade.sh` refuses a `.kit-upgrade/` that is a symbolic link, or has one inside it.** It stages copies there and `--finish` reads them back, so a link would take them to wherever it points. The refusal (`upgrade-staging-link`) names the link and how to remove it; nothing is written.
- **`module.sh enable` over an enabled module that has a recorded file or block missing says the module is not whole.** It used to say "already enabled; nothing to do". It now prints the same missing-things line as `status` and names the route back: `module.sh disable <m>`, then `module.sh enable <m>`.
- A note, README or child index in `progress/history/` is no longer refused by `archive-progress.sh` as a rotation cut off before its index row: only a file that opens with the header the rotation writes (`archived_at:` or `cutoff:`) counts as a chunk. A half-written chunk is still found. No action.
- `subtask.sh` no longer refuses on a locally edited `scripts/config.sh`: the file every project fills in on day one is not held with the scripts the slice tool runs. Its other held files are unchanged. The `0.13.0` item that says it is held, and its `Verify:`, describe that release; the `Verify:` still passes on a tree whose `config.sh` is committed and pushed. No action.
- In the brainstorming skill's foreground mode (`--foreground`, Windows, `CODEX_CI`), `start-server.sh` now runs the server by `exec`, so the pid in `state/server.pid` is the server's and `stop-server.sh` stops it instead of reporting it stopped while it ran. If you edited `start-server.sh`, make the same change. No other action.
- **The template-text warning at a `dev_complete` move no longer fires on text the Dev must leave.** `move-issue.sh` skips the `## QA Verdict` and `## Ablation` sections and angle-bracket text inside code spans and indented code blocks (the Activity section's example entry), and cuts each printed line at 100 bytes; a minted card's head no longer carries an `<angle-bracket>` of its own. A card the Dev has filled now moves with no warning, which lists only placeholders left in the Dev's own sections. It still warns, never refuses.
- **`AGENT_CHECK: UNRUNNABLE` for a missing identity record now says what to do.** `finish-pr.sh` and `subtask.sh` print `Next: wire the harness hooks (copy .claude/settings.json.example to .claude/settings.json) …` under the line; until the hooks are wired the same-agent check does not run and does not stop the landing.
- **The publish-the-card step names `register-commit.sh`.** `new-bug.sh`, `new-issue.sh` and the mover's "no file matching" error print `./scripts/register-commit.sh --role <Role> --message "<id>: mint" <path>` instead of `git add … && git commit … && git push`, and `archive.sh`'s recipe for a missing `done/` column does the same; the pre-commit hook refuses the plain commit off the trunk.
- **The rebase a stacked branch needs after its base squash-lands is in the Dev role doc, and QA reviews a branch that is only behind the trunk as it is.** `dev.md` § Handoff to QA gives `git fetch <remote> && git rebase --onto <remote>/<trunk> <old-base-tip> <branch>` then `git push --force-with-lease` (the `stacked-branch-squashed-base` refusal names the commit and prints the command); `qa.md` step 2 no longer asks for the trunk tip in the branch, and says QA never makes that rebase (the landing refuses a verdict whose author also wrote the branch's commits): with no Dev seat running, a Dev worker is spawned for it.
- **`new-bug.sh --discovered-in` accepts a slice id.** `<PREFIX>-NNN-sM` is now valid beside `<PREFIX>-NNN` (it was refused as not looking like `<PREFIX>-NNN`), so a bug found while reviewing a slice can cite the slice; `qa.md` § Bug filing and the usage text say so.
- **The refusal for a lander that is not the trunk's copy names a route for an untracked held file.** `finish-pr.sh` and `move-issue.sh` add an `Untracked here (<files>)` line: such a file is not part of the trunk's copy, so delete it, or commit and land it through the trunk's copy, then re-run.
- `check-board.sh` arms [p] and [j] read a table cell that holds `\|` as one cell. A `CORPUS.md` row with `\|` before its Status cell, or a downtime-queue Status cell with `\|` in it, was skipped before and is now read, so a dangling or landed claim in such a row is now reported and the report can move from clean to drift.
- **An id may widen past three digits, and the archive sweep and the staleness report now read it.** `archive.sh` lists and indexes a sweep newest first by the id's number (it sorted by name, so `-999` came above `-1000`), and `staleness_greps.py` reports a stale claim about an id of four or more digits (it read exactly three). `process/contracts/id-minting.md` § 2 now states the width once: a number starts at three digits, is never padded further and never renumbered, and `NNN` means "the number". The decisions register's note says a new register starts at three digits too; an id already minted with two stays as written. No id is renumbered or re-padded, so nothing to do.
- **The design module is at 0.6.4: a comment sent to Claude is now the go-ahead for the change it asks, and the Designer reads the threads awaiting reply on every pull and after every publish** (0.6.3), with smaller fixes to its link check and self-test (0.6.3, 0.6.4). A project with the module enabled reads them in `modules/design/RELEASE-NOTES.md`; nothing to do.

