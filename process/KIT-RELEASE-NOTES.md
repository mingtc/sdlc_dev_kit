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

### Action required

- **Give each card in flight whose acceptance criteria were reworded below their checklist line after it left `todo/` its `[decision: D-NN]` or its earlier text, and close any code fence it leaves open, before you finish the upgrade.** The landing now compares an AC's whole item with its `todo/` copy, not its checklist line alone: the checklist line, its indented lines, a blank line followed by more indented content, an indented fenced block, and a lazy line (an unindented line straight after a paragraph line that opens no list item, heading, quote, comment block or fence). A change in any of those needs the `[decision: D-NN]` on the checklist line (`forks-ac-changed-uncited`, naming the AC); a re-wrap, a blank line inserted inside the item or a trailing carriage return changes nothing, and an HTML comment added counts. A fence opened above `## QA Verdict` that does not close is refused naming its line (`forks-ac-unclosed-fence`). When the text ends first, add the closing line; when the list item holding it ends first (an unindented line inside the fence, a pasted traceback at column 0 under a bullet is the usual one), the refusal names the line the item ended on: indent every line of the fence to the item's text, or close it before that line. Quoted ACs (`> - [ ]`), nested `- [ ]` sub-items and a lazy line that starts with a number other than `1.` are not yet read as part of the item. The upgrade's open-card check names the affected cards in `in_progress/`, `dev_complete/` and `blocked/`; the line below runs the same check on the cards in those three columns of the checkout, and of each slice, and exits 0 when none is left. It does not read `qa_complete/`, where a card has landed.
  Verify: . scripts/lib/refuse.sh; . scripts/lib/card-field.sh; . scripts/lib/decision-register.sh; . scripts/lib/qa-gate.sh || exit 1; d="$(mktemp -d)"; for c in progress/in_progress/*.md progress/dev_complete/*.md progress/blocked/*.md progress/subtasks/*/in_progress/*.md progress/subtasks/*/dev_complete/*.md progress/subtasks/*/blocked/*.md; do [ -f "$c" ] || continue; id="$(kit_card_field "$c" id)"; [ -n "$id" ] || continue; IFS=$'\t' read -r lc lp <<< "$(kit_card_leave_todo "$id" . HEAD)"; ( KIT_PROGRESS_DIR="$d" kit_ac_drift_check "$c" "$id" . "$lc" "$lp" ) > /dev/null 2>&1 || { echo "$c"; rm -rf "$d"; exit 1; }; done; rm -rf "$d"
- **Give each card in flight whose QA Verdict rows are all of a module's cell-checked kind a `test` or `file:line` row, a quoted `path:line` at the end of one of its rows, or an AC of another kind, before it lands.** A passing `qa-cell` check used to count as the observed row the landing needs; it no longer does, and a table with no `test` or `file:line` row is refused `qa-verdict-no-observed` whether or not the check passed (a `FAIL_AC` row there is now refused as `qa-verdict-fail` first). A card or slice whose every AC is judged by such a kind stops at `qa_complete/`: QA gives one AC a `test` or `file:line` row and quote, or ends that AC's row with a `path:line` and a quote of the line (the row stays one row for the AC). The line below fails on a card whose QA Verdict table has begun and holds neither.
  Verify: . scripts/lib/refuse.sh; . scripts/lib/qa-gate.sh || exit 1; for c in progress/in_progress/*.md progress/dev_complete/*.md progress/blocked/*.md progress/subtasks/*/in_progress/*.md progress/subtasks/*/dev_complete/*.md progress/subtasks/*/blocked/*.md; do [ -f "$c" ] || continue; kit_qa_verdict_begun "$c" || continue; kit_qa_verdict_rows "$c" | awk -F'|' '$2 !~ /shadow-check/ { k = $4; gsub(/[` \t]/, "", k); n++; if (k == "test" || k == "file:line") ok = 1; c = $5; gsub(/`/, "", c); gsub(/\\"/, "\001", c); m = split(c, p, "\""); t = 0; for (i = 1; i <= m; i++) { if (i % 2 == 1) { if (p[i] ~ /[^ ,()]+:[0-9]+/) t = 1 } else if (i < m && t) { q = p[i]; gsub(/^[ \t]+|[ \t]+$/, "", q); if (length(q) >= 8) ok = 1; t = 0 } } } END { exit !(n == 0 || ok) }' || exit 1; done
- **Move any checklist line in an open card's `## Acceptance Criteria` that is not `- [ ] <id> — <text>` out of the checklist, before you finish the upgrade.** The landing now grades every checklist line of that section, so a "definition of done" list, nested `- [ ]` sub-steps, a `* [ ]` or indented bullet, an id with a dot (`AC4.1`) or followed by a hyphen and a letter or digit (`AC-1`, `S1-AC1`) is refused at the upgrade, the hand-off, `qa_complete` and the landing (`forks-ac-ungraded`). Rewrite each such line as `- [ ] AC<n> — <text>` with a distinct id, or make it plain prose or move it to another section, then commit the card with `./scripts/register-commit.sh`. An AC you dropped after the card left `todo/` stays on the card struck through with its ruling (`- [ ] ~~AC3 — …~~ [decision: D-NN]`). The command below prints each offending line and exits 0 when none is left (it does not see two lines that share an id; the upgrade's open-card check does).
  Verify: for d in progress/todo progress/in_progress progress/dev_complete progress/blocked progress/qa_complete; do [ -d "$d" ] || continue; find "$d" -name '*.md' -exec awk 'FNR==1{f=0;c=0;s=0} {sub(/\r$/,"");l=$0;o="";while(l!=""){if(c){i=index(l,"-->");if(!i){l="";break};l=substr(l,i+3);c=0;continue};i=index(l,"<!--");if(!i){o=o l;l="";break};o=o substr(l,1,i-1);l=substr(l,i+4);c=1};$0=o} /^[ \t]*(```|~~~)/{f=!f;next} f{next} /^##[ \t]/{h=tolower($0);sub(/^##[ \t]+/,"",h);sub(/[ \t]+$/,"",h);s=(h=="acceptance criteria"||index(h,"acceptance criteria (")==1);next} s && /^[ \t]*(>[ \t]*)*([-*+]|[0-9]+[.)])[ \t]+\[[ xX]\]/ && !/\[[ xX]\][ \t]+~~([^~]|~[^~])*~~[ \t]*(\[decision:[^]]*\][ \t]*)?$/ && !(/^(>[ \t]*)?(-|[0-9]+[.)]) \[[ xX]\] [A-Za-z][A-Za-z0-9]*[ \t]*(—|-|:)/ && !/^(>[ \t]*)?(-|[0-9]+[.)]) \[[ xX]\] [A-Za-z][A-Za-z0-9]*-[A-Za-z0-9]/) {print FILENAME ": " $0}' {} + || echo "awk failed in $d"; done | { ! grep .; }
- **Class at least one fast gate `core` in `scripts/verify.sh`, if every gate you declared is class `full`.** `verify.sh --quick` skips `full` gates and used to print a green summary over none run, so a landing's pre-merge and post-merge checks passed on nothing; it now refuses (exit 2) and says to class a gate `core`. A table with a `core` or `select` gate is unchanged, and so is the full run.
  Verify: ./scripts/verify.sh --list | grep -E '^  (core|select) ' > /dev/null
- **Pass `--full` to any script of yours that reads a `check-board.sh` arm's lines; an arm of your own in `check-board.d` needs no change.** The default report now folds an arm that found nothing into one named line, so a script that greps the default report for a quiet arm's `✓` line, or for its heading, no longer finds it. `./scripts/check-board.sh --full` prints the report as before. An arm of your own in `scripts/check-board.d/` is folded only if it printed nothing but `✓` lines, returned 0 and said nothing about a skip; one that signals a finding any other way (status 3, a line without `✓`, `skipped: …`) is printed in full, so it needs no change.
  Verify: ./scripts/check-board.sh --full > /dev/null
- **Land any edit of your own to the scripts the landing, card and slice tools run, before your next landing.** `finish-pr.sh`, `move-issue.sh` and `subtask.sh` now refuse to run unless those three, the libraries they source and `check-board.sh` are the trunk's committed copy. An edit still uncommitted, left on a branch, or committed here and not pushed refuses them, naming the files. Commit it and land it through the trunk's copy: from a freshly pulled main checkout on the trunk, `./scripts/finish-pr.sh <ID> --worktree <branch checkout>`. A project that never edited those files has nothing to do.
  Verify: git diff --quiet "$(git symbolic-ref --short refs/remotes/origin/HEAD)" -- scripts/finish-pr.sh scripts/move-issue.sh scripts/subtask.sh scripts/check-board.sh scripts/lib
- **Give every arm of your own in `scripts/check-board.d/` a name of letters, digits, `.`, `_` and `-` and an exact `# check-board-arm: advisory` or `# check-board-arm: deciding` line.** An arm with a bad file name that declares `deciding`, an arm whose name is bad and whose kind cannot be read, and an arm whose declaration is missing or misspelled (`decidng`) were skipped and the verdict stayed `clean`. Each now prints a `⚠` line naming the file with a `Next:`, and the verdict is not `clean`, so `release.sh` gate (d) refuses until you rename the file or fix the line. A bad-named `advisory` arm stays report-only. A project with no arm of its own, or only well-formed ones, has nothing to do.
  Verify: for f in scripts/check-board.d/[0-9][0-9]-*.sh; do [ -f "$f" ] || continue; case "${f##*/}" in *[!A-Za-z0-9._-]*) exit 1;; esac; k="$(awk '/^# check-board-arm:/ { sub(/^# check-board-arm:[ \t]*/, ""); sub(/[ \t\r]+$/, ""); print; exit }' "$f")"; [ "$k" = advisory ] || [ "$k" = deciding ] || exit 1; done
- **Merge the new `scripts/githooks/commit-msg` into yours (its checklist item), keeping your `ROLE_PREFIXES` line.** The new `prepare-commit-msg` hook (below) arrives by itself, but it only calls your `commit-msg`: with the old one a refused cherry-pick prints "commit again with a subject…", which does not apply to a replay, and an empty subject is still accepted.
  Verify: grep -q 'commit-msg-empty-subject' scripts/githooks/commit-msg && grep -q 'KIT_REPLAY' scripts/githooks/commit-msg
- **Put a space after the id in every register heading, and give each card number one spelling, before your next release.** A register heading whose id runs into other text (`### D-08: title`) is no entry to any check now; `check-board.sh` `[d]` names it and `[l]` reports every citation of it as not an entry, so the verdict reads `findings above` and `release.sh` refuses until it is cleared. Rewrite it as `### D-08 — title` (a space or the end of the line after the id). Likewise `[d]` reports cards whose ids are one number in two spellings (`ABC-1` and `ABC-001`) as a duplicate, since an id is its integer: renumber the later one and rename its file, branch and Activity lines to match.
  Verify: ! ./scripts/check-board.sh --full 2>/dev/null | grep -E 'DUPLICATE id|followed by something other than a space' > /dev/null

### Changed

- **`kit-upgrade.sh` refuses a new kit whose copy of a module you enabled would place a fragment that every mint refuses.** Such a fragment (a `KIT-MODULES` line of its own, or a byte 035 to 037) was written, or staged for a merge, and the refusal came only at the next card minted from its template (`new-issue.sh`, `subtask.sh` and the other mints). The upgrade now refuses before it writes anything (`module-fragment-bad`), as `module.sh enable` does, naming each fragment and where it would go; the `Next:` says to fix the file in the new kit. A kit whose module fragments are clean upgrades as before; nothing is required of you.
- **The self-test's trunk-chain cases no longer go red on a machine whose global git config sets `init.defaultBranch`.** `case_trunk_fallback_warns`, `case_trunk_chain_announces_every_fallback` and `case_seam_shape_reformat_is_loud` remove the project's own key to reach the last link of the trunk chain, and a key set in your global or system git config still answered, so the three failed on such a machine. Their last-link calls now run with the machine's git config out of reach. Nothing is required of you.
- **A QA verdict can cite the last line of a file with no final newline; `kit-upgrade.sh` writes nothing through a symbolic link; `module.sh status` with no name ends non-zero on a refusal; the staleness greps read a claim only where it is said.** The verdict check counted a cited file's lines with `wc -l`, which does not count a last line with no newline, so a pointer to that line was refused as past the end of the file. A kit file that is a symbolic link in your tree, or lies under a directory that is one, was copied through the link to wherever it pointed (or, on a dangling link, the run could stop part-written); it is now a merge item, its new copy staged under `.kit-upgrade/files/` and the link left as it is. `module.sh status` with no name printed a refusal for a record it cannot read (a module name or a file path that leaves the project) and still ended 0; it now ends as `status <name>` does. `scripts/hygiene/staleness_greps.py` counts a claim phrase only with the landed artifact in the same sentence of its line (a table row is one sentence), and a phrase between a pair of double quotes on that line is a mention, not a claim, so it reports fewer suspicions. Nothing to do.
- **A fragment's slot-line or control-byte refusal now says where the fix goes, and `module enable` refuses such a fragment before it writes.** A slice's refusal adds that the fix must be committed and pushed, since `subtask.sh` reads the fragments from the trunk; a fragment a module placed names the module, its source to fix and a disable then enable to place it again. `module.sh enable` and `kit-init.sh --with` refuse a module whose fragment would carry a `KIT-MODULES` line or a byte 035 to 037 (`module-fragment-bad`), where before it enabled cleanly and every mint then refused. Nothing to do.
- **`module.sh status` and `enable` no longer count a module's file or block that you removed and committed.** Their line "N of M recorded things are missing" printed on every run after a deletion made on purpose. It now counts a missing thing only while its removal is not committed (deleted or staged, not yet committed, or placed by an enable that was never committed, as a disable stopped part-way can leave it), and reads `…, and their removal is not committed: removed here (commit the removal if it is on purpose; git restores one), or left by a disable that stopped part-way (./scripts/module.sh disable <name> finishes it).` Nothing to do.
- **A board op that holds the kanban lock now ends after the git command it is running, not over it.** A TERM, HUP or INT sent to `move-issue.sh`, `finish-pr.sh`, `archive.sh`, `register-commit.sh` or `subtask.sh` itself (its own pid, not its process group) used to end it at once, release the lock and leave a `git push` running that another op could race; the signal is now answered when the push has returned, and the op exits 143, 129 or 130 with the lock released after. A git command that hangs (a push or fetch to a remote that stops answering) is not interrupted by TERM: send KILL, which still leaves a push running on its own.
- **`kit-init.sh` over a run that was cut off names every commit it made on the trunk.** When its self-check pushed a move and the run ended before your checkout caught up, the "already lived" refusal listed too few commits to revert, and following it left the scratch card moved on the trunk. It now reads the trunk's log and prints `git merge --ff-only <remote>/<trunk>` before the `git revert --no-commit` line; a checkout that has diverged from the trunk is told to `git pull --rebase` first, and one that is not on the trunk gets no merge line.
- **On a machine whose `awk` is mawk or busybox, a PRD minted with a `story-fields` fragment no longer has a second blank line above the fragment.** mawk is the `awk` of a Debian or Ubuntu without gawk; it and busybox create an array element before they evaluate the right side of its assignment, which made the mint's test for a second fragment in the same slot always true. gawk and macOS's `awk` were not affected. Nothing to do; a PRD already minted keeps the blank line it got.
- **Each release's notes now say whether the kit's self-test ran on Linux.** From the next release, the release's section opens with a `Linux:` line: *tested*, with the host and the tally, when the self-test ran on Linux at the commit the release was cut from; *not tested* otherwise (§ How versions work). Nothing is required of you.
- **A checklist bullet inside a code fence is no longer an AC id for the landing.** A card that shows an example `- [ ] AC12 — …` in a fenced block no longer needs a verdict row for it (`qa-verdict-ac-mismatch` named it). What is read as a fence: an opener of three or more backticks or tildes on a line indented by at most three spaces, or, inside a list item, up to six columns (a tab counts to the next multiple of four); a backtick opener's info string holds no backtick; the closer is the same character, at least as long, with nothing after it. A fence inside a blockquote is not read as one. A bullet outside a fence is graded wherever it sits above `## QA Verdict`, `## Acceptance Criteria` or not. A fence opened above `## QA Verdict` and never closed is refused (see Action required). A relaxation otherwise: nothing is required of you.
- **A fragment holding a control byte is refused at the mint** (`fragment-control-byte`, the file named, a `Next:` line). The mint carries a slot's newlines as 035 and separates slots with 036, so in a slot fragment a 035 turned into a newline and a 036 dropped the text after it, silently; 037 passed through. Frontmatter and body-end fragments were never damaged, and are now refused too. None of the bytes is plausible in a hand-written fragment; take it out. The test harness's skip reason for a tree with no module manifests now names the manifest, which is the file that is absent.
- **Small script fixes.** `set-models.sh` refuses (exit 2) a model or effort id that is not letters, digits and `. _ : / @ [ ] -` (an apostrophe broke the runner's JavaScript, a backslash was eaten, a `|` added a table column) and rewrites only the agent file's frontmatter `model:` / `effort:`, not a body line that starts with one; it refuses a pin file whose `---` frontmatter does not open on line 1 (`pin-shape-unrecognised`), where it used to rewrite a body line after a `---` rule or print a success it had not written. `archive.sh`'s default preview and `--dry-run` no longer need a role tag the project's hook declares (`--apply` still does). `notify.sh` treats `NOTIFY_BACKEND=stall` (the watchdog, not an adapter) as no adapter instead of running it; every other script in `scripts/notify/` is still an adapter. The hygiene tools `reachability_walk.py`, `citation_index.py`, `duplication_scan.py` and `cold_signal.py` exit 2 on a `--root` that is not a directory, and `duplication_scan.py` and `cold_signal.py` on an out-of-range `--n`, `--min` or `--days`. `verify.sh` refuses a gate whose command is only whitespace. `new-prd.sh` skips a file that carries no number (it died on an unbound variable beside `PRD-overview.md`) and counts a numbered file with or without a slug (`PRD-003.md`). The brainstorming companion's `stop-server.sh` deletes a session directory only when its path has no `..`. `check-board.sh`: `[j]` reads a lower-case claim id (`xyz-001`), `[g]` counts a blank between two inline comments, and `[f0]` warns on an untracked path with a space.
- **The kit now states the platforms it runs on: macOS, Linux, or Windows through WSL 2, and its self-test has run green on each.** `README.md` says it beside the git and POSIX-shell requirement, with two conditions: on WSL keep the project in WSL's own filesystem, not under `/mnt/c`; and run `./scripts/test/run.sh` as an ordinary user, because a case that makes a file unreadable cannot prove anything as root. Native Windows (Git Bash, PowerShell) is not supported. Three behaviours moved with it, none needing action: on a GNU userland `kwt__mtime` (the board worktree's stale-claim age) now reads the file's mtime with `stat -c %Y` before `stat -f %m`, because GNU's `stat -f` prints a filesystem report and left that age an arithmetic error; a killed `kit-upgrade.sh` over modules sharing a block host is finished by running it again under `core.autocrlf=true` with CRLF files, where it was refused as your own uncommitted change; and two cases of the self-test no longer need `shasum` on the machine.
- **`check-board.sh` has a new report-only arm `[v]`: `scripts/` against `process/KIT-MANIFEST`.** It names a file the manifest lists that is not on the trunk's `scripts/` (a `⚠` line, unless the manifest marks it `DELETE-IF-UNUSED`, which it names as allowed), and lists a script the manifest does not list as your own or a module's. It checks presence, not content (a symlink counts as present), and never changes the verdict unless it could not run. With no `process/KIT-MANIFEST` it says it skipped.
- **A board op ended between its commit and its push now prints the unpushed commit and the commands that publish it; a refused archive sweep leaves nothing staged; `kit-init.sh` run again after a cut-off names every commit to undo.** A board op stopped by a catchable signal after its local commit used to exit silently, and the next op refused over that commit. Its exit now names the commit, says the push may or may not have landed, and prints the fetch, rebase and push to run, which are safe either way. A SIGKILL still prints nothing; the next op's refusal names the commit and prints the same commands. `archive.sh` left the sweep staged in the board worktree when a hook refused its commit; it now does what the other board ops do (a Next, nothing left staged). The "already lived" refusal printed "revert the initialization commit", which is refused again over the self-check's scratch card; it now prints `git revert --no-commit` over each commit the newest kit-init run made, then a `[<role>]`-tagged commit and the push. Nothing is required of you.
- **`scripts/test/run.sh`'s header allows concurrent runs.** It said to run one copy at a time; nothing a run writes has a fixed name, and two runs in separate trees gave the same outcomes as one. Two runs cannot share one tree (`case_isolation` compares it). A comment only; no behaviour changed.
- **A row of any kind that quotes a resolving `path:line` is an observed row for the landing.** A `test` or `file:line` row was the only one; now a row of another kind whose pointer cell has a `path:line` that resolves, then a quote found on that line, held to the floor of a `file:line` quote, counts too. The table keeps one row per AC, and a quote that does not match counts for nothing. `qa-verdict-no-observed` says so. A relaxation: nothing is required of you.
- **An upgrade whose only work is a module's record now writes the record and stops.** When the kit's version is the one you record and nothing else is to write, merge, remove, check, add or replace, but an enabled module's record names another version than the kit holds (or carries a `pending` section), `kit-upgrade.sh` moves the record, names the module, and writes no checklist and no `.kit-upgrade/`: commit `process/MODULES` (a module with uncommitted changes under a path it places, or to the block it adds to a file, staged or not, or a block left damaged, takes the full path instead, as after a killed run; an uncommitted edit elsewhere in such a file does not). There is no `--finish` and no archive to commit for it. Nothing to do.
- **A second upgrade at the same kit version no longer refuses at `--finish`.** When the version your tree records and the version the upgrade installs are equal (an enabled module that added a file, or core drift, at an unchanged version), `--finish` archives the checklist as `process/upgrades/<v>-to-<v>.md`, and the next such upgrade as `<v>-to-<v>-2.md`, then `-3`; before, the second was refused with `upgrade-archive-exists` and a manual rename. An archive of the same name for two *different* versions is still refused. Nothing to do.
- **The `check-board.sh` verdict reads `clean (N advisory)`, not `clean ✓`, when N advisory arms in `check-board.d` reported a finding.** The line still starts `board-drift: clean`, so a script that matches that is unchanged. Nothing to do.
- **`register-commit.sh` refuses a path whose letter case differs from what the trunk tracks (`register-path-case-differs`).** `Progress/todo/<card>.md`, `Docs/note.md` or `docs/Note.md`, where the trunk tracks `progress/`, `docs/` and `docs/note.md`, reached the same file on a filesystem that folds case and skipped the guards that compare paths as typed, so a card could land twice. It is refused on any filesystem, before anything is written, and the Next names the trunk's spelling; the call is not rewritten for you. Two new paths of one call that differ only in case are refused too. A case-only rename is not a register write: make it with `git mv` on a branch and land it through your normal route. ASCII letters always fold; other letters fold only where your system's `awk` folds them under a UTF-8 locale (macOS awk and gawk do; mawk and busybox awk do not), and a path whose name differs from a tracked one only in Unicode normalisation (NFC against NFD) is not judged. A path with a control character in its name is refused (`register-path-control-character`), and a trunk file list that cannot be read refuses (`register-trunk-unreadable`). A path whose directory the trunk does not track at all still lands. Nothing to do unless one fires.
- **New refusals for a path or an id spelled another way.** `register-commit.sh` refuses a path with a `.` part or a `//` (`register-path-not-canonical`; write `progress/todo/<card>.md`, not `./progress/todo/<card>.md`), which used to pass a guard the plain spelling failed. `finish-pr.sh`, `move-issue.sh` and `subtask.sh new` refuse a bare prefix or an id that is not `<PREFIX>-<digits>` (`issue-id-malformed`, exit 2; `move-issue.sh` given a slice id points at `subtask.sh move`); a bare prefix used to select the last card listed in `finish-pr.sh` and the first in `subtask.sh new`. `finish-pr.sh` refuses two cards for one id in `dev_complete/` (`card-id-ambiguous`, exit 1) rather than taking the last. `new-issue.sh`, `new-bug.sh` and `new-refactor.sh` refuse `ABC-1` or `ABC-0001` beside `ABC-001`. The forks check reads a register heading as every other check does, so a colon heading is no entry there either. Nothing to do unless one fires.
- **A write that fails part-way now says so, leaves what it found, and names the way on.** `register-commit.sh` refuses a directory, an unreadable or ignored path, and a path with `..` or a leading `/`, and a path that is or passes through a symbolic link on the trunk (`register-path-through-link`; to delete a link itself, remove it from your checkout and name its path) before it copies anything, and puts the board worktree back if a later step fails; `move-issue.sh`, `subtask.sh`, `finish-pr.sh` and `register-commit.sh` put it back when the commit hook refuses and print `Moved:` only after the commit; `register-commit.sh` writes its `landed` record after the push. `set-models.sh` refuses before its first write when a pin, the ladder, a runner or `.claude/model-pins.record` cannot be rewritten, and no longer prints a success line over a failed one. `module.sh disable` no longer counts a removal that failed or drops the record over a file still in force: it names the path, exits 1, keeps every row of the module in `process/MODULES` until a run finishes, and a re-run retries it (it also exits 1, saying how much it had removed, when the record cannot be dropped or written; `enable` and `status` count the recorded things the module still places that are missing, and say they were removed here or left by a disable that stopped part-way, which `disable` run again finishes; a disable run again also names the first run's deletions in its commit line); a dangling link at a placed path is kept and named. `archive-progress.sh --apply` checks every target is writable first, builds the chunk, the log and the index beside their targets before renaming them in, matches the index header at the start of the line as its insert does, takes only a plain `--milestone` name, and on every run refuses a chunk the index does not name (`rotation-chunk-unindexed` prints the row to add; `rotation-chunk-orphan` names the chunk to delete) instead of rotating over a cut-off run. `consumers/update_vendored.sh` (your copy of it) exits non-zero with no pin line when the vendored copy cannot be written. `kit-init.sh` refuses the shipped placeholder as `--prefix` before it writes, no longer fails after stamping over a `.gitkeep` of yours deeper under `progress/`, and, over a run cut off before its commit, prints a `git stash push --include-untracked` line that clears it. Nothing to do. If you keep your own copy of `consumers/update_vendored.sh`, re-copying it is optional: it adds the failed-write exit.
- **A QA cell check's refusal now quotes what the check printed (up to twenty lines, each whole) and leads its `Next:` with the check's own step.** A long first line no longer hides the reason, and the step a check prints after its reasons, such as the design module's, is no longer cut off. Nothing is required of you.
- **A refusal for a card's content now exits 1, not 2.** The QA Verdict check, the forks check, the ablation check and the landing's board-property check (through `finish-pr.sh`, `move-issue.sh` and `subtask.sh`), `ask.sh` for an undeclared role and `subtask.sh` for a subtask named as a parent exit 1, as the exit table says: refused with nothing landed. 2 stays the usage error (an unknown option, a missing value). A script of yours that branched on 2 for these refusals must branch on 1.
- **A new hook, `scripts/githooks/prepare-commit-msg`, refuses a `cherry-pick` or a rebase's pick whose subject carries no role tag (or tags a role outside your set), and `commit-msg` refuses an empty subject.** Those picks ran no message hook, so an untagged commit replayed onto the trunk reached it unjudged. The new hook runs `commit-msg` on a commit that is the replay's own (a stale `CHERRY_PICK_HEAD` does not count); the refusal prints three commands that fit the operation: reword the commit, keep it as it is (`MSG_OK=1 git commit -C CHERRY_PICK_HEAD`, with `&& git cherry-pick --continue` or `&& git rebase --continue` after it where the operation goes on) and stop the operation where it is (`git cherry-pick --quit` leaves the picked change staged; `git rebase --quit` leaves a detached HEAD at the partly rebased tip, your branch where it was, and the change staged). A rebase over an unpushed commit made before the rule, or with `MSG_OK=1`, now stops at that commit; `MSG_OK=1 git rebase …` carries it through, and `git_push_with_retry`'s own rebase says a hook refused rather than that it conflicted. `rebase --apply` runs the patch-application hook, as `am` does, and, for the patch's own commit, prints `git rebase --quit` (it leaves a detached HEAD at the progress made and your branch where it was) with the advice to run the rebase again without `--apply` (a commit you make yourself in the stopped rebase gets the ordinary refusal). Three replays are still judged by no hook once the message is final, `cherry-pick -e`, a pick finished with `rebase --continue` after a conflict, and a `fixup -C` in `rebase -i` (it reaches the new hook, which does not judge it); the drift report's `[e]` catches them. An ordinary `git commit --no-verify` is unchanged; during a replay `--no-verify` does not skip this hook. A commit with no subject (`--allow-empty-message`) is refused unless `MSG_OK=1`, and `check-board.sh` `[e]` reports one already on the trunk instead of skipping it, which makes the verdict findings and so `release.sh` gate (d) refuse; nothing in the kit clears it, so a project that has one cannot cut until its history is rewritten. `commit-attribution.md` § 2 now says which entrances are refused at write time and which are caught after the fact. `kit-upgrade.sh` places the new hook with its executable bit; the `commit-msg` merge above is the one thing to do.
- **`set-models.sh --class` leaves the untyped-leg runner fallback alone, and a parked role's pin is edited by hand; `--all` writes all three.** The wording said "the three never disagree" for every use. Behaviour is unchanged. Nothing to do.
- **The write-spec skill, the PM's ready checklist and the card template now say every acceptance-criteria line carries an `AC<n>` id.** A PRD line without one gets it as it is copied; a line with no id is refused at the Dev hand-off. Nothing to do.
- **A hand-made move of a card into `progress/qa_complete/` is refused at commit when its QA Verdict table fails the table check.** `scripts/githooks/pre-commit` runs the check `move-issue.sh` runs first, on the staged card, on the trunk checkout and on any branch (the board worktree is not judged, nor a card whose staged copy is the unchanged card in the head of a merge, cherry-pick or revert in progress; a squash merge is judged like any commit, so bring the trunk in with a plain merge). It prints the failing rows, a `git mv` that puts the card back with its edits, and the `move-issue.sh` command with `--role QA`. Evidence pointers are read at `HEAD`; the AC-drift and add-on move checks are not run. Any outcome but the library's own card-content refusal (a library that cannot load, an unexpected exit status) is refused as `pre-commit-qa-check-broken`. `MSG_OK=1` is the declared bypass.
- **`module.sh enable` and `kit-init.sh --with` refuse more manifests, and the upgrade's dirty-host `Next:` says when to pop.** A block host or a directory above a new file spelt in another case than the project's (`project.md` for `PROJECT.md`), and a `role:` tag the project's role set already carries, are refused before anything is written, each saying what to change in the module's manifest. `--with` also refuses two modules where one places a file below the other's file or under a path the other's `.gitignore` block ignores, and no longer reads a directory you named `.GIT` as a case-blind filesystem. The `Next:` of `kit-upgrade.sh`'s uncommitted-paths refusal says to commit the upgrade's changes before `git stash pop`. No shipped module is affected.
- **The `forks:` check reads the live register from the trunk as well as the branch, and both refusals for a changed AC name the exit.** A ruling that landed on the trunk after the branch was cut used to be refused both ways: `forks: none` as a fork the field omits, `forks: [D-NN]` as an id that is not live. It now passes under `forks: [D-NN]` with no merge of the trunk, and still refuses under `forks: none` when the ruling names the card; an id the branch itself retired is still not live. An AC bullet rewritten or added after `todo/` that cites `[decision: D-NN]` stays a fork whichever ruling it names: `forks-contradicted` and `forks-ac-changed-uncited` each say to keep the citation on the bullet and name the id in `forks:` (`forks: [D-NN]`), so neither sends you back to the other. An Activity or Out of Scope citation of a ruling the trunk has since withdrawn, or the branch retires, is no longer skipped as already made. The citation is read as committed, not checked for relevance to the card.
- **`kit-upgrade.sh --finish` runs the `Verify:` commands of the items the first run staged, and refuses a checklist or staged notes that were edited.** It reads which items to run from `.kit-upgrade/action-items` rather than from the checklist, so a deleted, renumbered or re-worded Action required item is `upgrade-checklist-item-missing`; a staged copy of the new kit's notes that has uncommitted edits, or no longer matches the staged manifest's sha256, is `upgrade-staging-edited`; absent staged notes are `upgrade-staging-missing` (an upgrade staged by an older copy has no item list: the refusal prints the one command that discards it, commits that and keeps `.kit-upgrade/arrived`; run the new copy again, which starts over). The archive lists the sha256 of each staged copy. A write that fails after the archive is written puts KIT-VERSION, KIT-MANIFEST and the archive back, so its Next, "run `--finish` again", is accepted. The core items are derived again from the staged notes and the version still in `process/KIT-VERSION`, and a module item needs an entry in its staged notes; a failed stamp write now saves a copy first, refuses before writing if that fails, and puts the tree back otherwise. Staged copies are trusted as committed, not as tamper-proof: someone who edits the notes and the manifest together and commits, or removes a module item with its checklist line, passes.
- **`finish-pr.sh` refuses when the branch moved while the pre-merge gate ran, and a tag named like the branch no longer decides any landing check.** The landing resolves the branch once, as `refs/heads/<name>`; the QA read, the forks, ablation and board-property checks, the gate and the squash all use that revision, not the name; a commit that arrived meanwhile used to be squashed unread under a note naming the earlier revision. The refusal (`branch-moved-during-gate`) lands nothing and says to re-run. No action.
- **`ask.sh` files each question in its own file even when several are asked in one second, keeps a backslash in the working default as typed, and refuses a channel that leads outside the repository through a symbolic link.** Two asks by one role in the same second used to share a file, so one answer reconciled both; the name is now claimed with an exclusive create. A default such as `C:\new\table` was rewritten into a newline and a tab in the register's Ruling line over a WITHDRAWN entry; it now lands as typed. A `PROJECT.md` channel whose existing path components resolve through a link to a place outside the repository, or a channel file that is itself a link, is refused with `ask-channel-unusable` and a Next, and nothing is written; a link that stays inside the repository still works. `process/contracts/ask.md` § 2 states it.
- **The landing's AC check reads every checklist line of `## Acceptance Criteria`, refuses a card with none, and asks a ruling for an AC removed or renamed after `todo/`.** A line of another shape (`* [ ]`, an indent, `AC4.1`, no id), an id directly followed by `-` and a letter or digit (`AC-1`, `S1-AC1`: read as the id `AC` before, so every such line folded into one graded criterion) and an id two lines share were never graded one for one; each is now refused by name (`forks-ac-ungraded`) at the upgrade, the hand-off, `qa_complete` and the landing. A numbered (`1. [ ]`) or quoted (`> - [ ]`) checklist line is graded when it carries an id and refused when it does not. A card with no `- [ ] <id> — …` line is refused (`forks-ac-none`); it used to die with no message. A card that had an AC when it left `todo/` and no longer lists it needs a `[decision: D-NN]` on an Activity line written since, that names it, or on the bullet kept struck through completely (`- [ ] ~~AC3 — …~~ [decision: D-NN]`); `forks-ac-changed-uncited` names it. The `## Acceptance Criteria` heading is matched as a lower-case prefix, so a subtask card's `Acceptance Criteria (sliced from the parent)` is read too. Each refusal's `Next:` says the fix.
- **`finish-pr.sh` refuses when the branch moved while the pre-merge gate ran, and a tag named like the branch is no longer what it reads.** The squash merges the revision the QA Verdict was read at and the gate ran on, not the branch name; a commit that arrived meanwhile used to be squashed unread under a note naming the earlier revision. The refusal (`branch-moved-during-gate`) lands nothing and says to re-run. No action.
- **The board-property checks no longer read as passed over a check that did not run.** `check-board.sh` arms [d] [i] [l] [p] [q] [r] and the landing's check of them (`BOARD_PROPERTY_CHECK`) now say `⚠ … DID NOT RUN` and the verdict is `findings above`, not `clean`, when a library they depend on is missing or loaded only in part, or a reader, a card's frontmatter read or a register or citation read failed (a failed read of a register file or a citation no longer reads as an empty register or as nothing cited; in the `forks:` checks, wherever they run, a register git cannot fetch (its blob, its tree, or the diff of it) refuses `forks-register-unreadable` too, while arm [q]'s ruling history still skips one without saying so; a register path that is absent still reads as no register); an id shape that `REGISTERS` declares and grep rejects is named as the fault, not a file; the landing refuses `board-property-unreadable`, printing the reader's own last words and saying whether the file is on the trunk (fix it there) or on the branch (hand it back). Every arm now reads cards and registers byte-wise, so a byte your locale cannot decode (a stray Latin-1 character in a card) no longer hides a finding; an arm of your own in `scripts/check-board.d/` still runs in the locale you launched it in. Arms [a] [c] [j] [m] [n] [t] [u] do the same when their own reader of a card, `progress.md`, `PROJECT.md` or the downtime queue exits non-zero (`⚠ … DID NOT RUN`, no `✓` line, verdict `findings above`, reports-only arms included); reports-only headers now say "unless it could not run"; arm [v] does the same when its read of `process/KIT-MANIFEST` or `scripts/` fails; **the remaining arms ([b] [e] [f] [h] [k] [o] [s], [g]'s reads other than its blank reader, and two of [c]'s three readers) do not check their readers' exit status**. The report reads the trunk with every tracked file, so a `.gitattributes` `export-ignore` on a board column no longer hides a card, and a `FAIL_AC` or `FAIL_REGRESSION` token on the `shadow-check` row now refuses a PASS landing like any other row. A post-merge `verify.sh --quick` that refuses to run is `POST_MERGE_GATE: UNRUNNABLE`, not a FAIL. The rule is `process/contracts/drift-report.md` § 4 item 7.
- **The design module's checkers close a few rare gaps (module 0.6.1).** The link check reads a tag whose quoted attribute holds a `>` (a quote opens a value only after `=`); an alias inside a longer token value, a change between two invalid byte sequences, and a shared element after an unclosed `<td>`, `<tr>`, `<li>`, `<dd>`, `<option>` or `<rt>` no longer read as `clean`; an artboard whose canvas moved together with an edit reads `differs at HEAD`, not `missing`; a superseded screen's pin line says so and to re-pin; and an approval's sha or a card's pin this clone cannot see names `git fetch --unshallow` (a CI job that runs the gate needs full history). Nothing is required of you.
- **The design module has an optional wireframe mode for a canvas** (`- **Mode:** wireframe [decision: D-NN]` in its `CANVAS.md`, module 0.6.0). A canvas kept current as a wireframe of flow and content, with the build as the visual anchor, no longer has its gate 1 approvals reset by a change of text, numbers or style (only a change of structure does), takes gate 2 as `build`, and `check-design-links.py --strict` shows its `UNCOVERED` and `STALE-PENDING` findings as `UNCOVERED-WIRE` and `STALE-PENDING-WIRE` without counting them. The line needs a ruling the register holds, or the mode is not in effect. Without the line nothing changes.
- **The design module's `render.py` prints `OVERFLOW <board> <content>px > <board>px` after an `OK` line when a board's content is taller than its size in `canvas.json`**, so a reader who cannot view the PNG still sees a cut-off table. It is a report; the exit code is unchanged. The Designer role doc also says a script that writes boards is committed under `requirements/design/<canvas>/tools/`.
- **A work branch can commit its own card's Dev evidence by itself.** The pre-commit hook refused every metadata-only commit off the trunk, so evidence a leg produced after its code commit had no route but the trunk or a rider on a code commit. It now lets through a commit whose every staged path is under `dev/evidence/<card>/` for the card the branch's last name segment carries (`<kind>/<card>-<slug>`); another card's directory, a directory that only starts like the id, the card file and any other metadata path in the same commit keep the refusal, which now names the path that passes. A rename counts as a deletion of its source plus an add, so moving a card into the directory is refused; a change to or deletion of an evidence file the trunk already holds is refused too, in a code commit as well, since a QA row may cite its sha (add a new file instead). `dev/evidence/README.md` states once who commits evidence and when (a file a QA `artifact` row will cite still goes to the trunk first), and `dev.md` carries the one line. A path a test reads is still code by `CODE_GLOBS`.
- **`commit-msg` warns when a subject's role tag differs from the first word of the hat file.** One `Warning:` block on stderr; the commit is made and the exit status does not change. It says nothing with no hat file (the commit gate refuses that), under the operator waiver, under a script's per-commit declaration, under `MSG_OK=1` and in the standing kanban worktree; a linked worktree with no hat file of its own is compared against the main checkout's, as the commit gate reads it, and the warning prints the file it read. The gate itself still reads existence, not content.
- **`check-board.sh` `[f]`, now headed "remote branches and worktrees left by a landed card", lists a linked worktree whose card has landed (`[f4]`).** The landing removes no worktree, so one on a branch of a card in `done/` or `qa_complete/` (or a detached one named for it) stayed until somebody noticed. The line names each with its branch and whether it holds uncommitted or untracked changes, and says to remove it with `git worktree remove <path>`; it removes nothing and never changes the verdict, because removal also deletes ignored files such as installed dependencies. `finish-pr.sh`'s note about a branch a worktree holds now names the same command.
- **A bracketed `[decision: D-NN]` in a card's Activity or Out of Scope is no longer a fork when the register already held that ruling as the card left `todo/` and nothing since has changed it (a card that amends the ruling itself still counts).** `finish-pr.sh` and `move-issue.sh … dev_complete` used to refuse it under `forks: none`, though the card template's own Activity example is exactly that bracket. A citation of an entry added to the register since, or of any id elsewhere on the card (the Problem, a changed AC bullet), still counts, and the refusal's `Next:` says to write the id without brackets where the card only applies the ruling.
- **`new-issue.sh`, `new-bug.sh` and `subtask.sh new` without `--stories` write `stories: []`** and leave no `<story ids>` blank (in the References line and seed entry of an issue, the Expected and Related PRD lines of a bug); they used to leave the template's example id `PRD-NNN-F1-S1` (a slice, a `[<…>]` placeholder), which no gate looks at. Name the stories on the card once the PRD's stories are known.
- **`check-board.sh` arm [q] no longer names a register entry whose Ruling changed only by gaining or losing the `[cross-cutting]` marker at its head.** That edit used to be reported on every run for good, as "Ruling changed without a stamp". A change to the ruling's text still is, marker or no marker.
- **A `test` row's verdict pointer can name a test: `path:"<test name>"`.** `qa.md` step 4 and the landing gate take the quoted name in place of a line number, when it opens the cell or follows a `;`. Everywhere else, including every other kind of row, `word:"…"` reads as prose exactly as before; the one exception is a `test` row whose text right after a `;` is `word:"…"`, which now reads as a name, and its refusal says to put a space after the colon. A pointer to a directory is now refused, naming it. The gate finds the one line that holds the name at the revision being landed, so a bounce that adds tests above it no longer sends QA back to re-point the row. The name is read as text, in no test framework's terms: it must occur exactly once in the file, or the landing refuses (`qa-verdict-pointer-unresolved`) saying whether it is absent or how many times it occurs. A plain quote that has moved is still refused; when it occurs once elsewhere in the file, the refusal now says which line it is at.
- **A refused `artifact` row names the row, its pointer cell and the token it could not read**, and says to put a note in double quotes (`(the error state)` after a pair is what used to be refused with only the generic form). `qa.md` now says, for every kind of row, that each `word:number` outside double quotes in a pointer cell is read as a `path:line` and must resolve.
- **Who commits an image is stated once, in `dev/evidence/README.md`:** QA cites an image by its blob sha and never takes or reads one; Dev or the project's tooling commits the file, a build screenshot included; a human or the orchestrator compares, and QA records the result. `qa.md`, the `design` module's verdict fragment and requirements README, and the design cell check's `Next:` line now say the same, where they said QA commits the screenshots. `qa.md` step 4 also says to edit and commit the verdict table from the primary checkout, not the Dev's worktree.
- **`release.sh` no longer stops when whatever reads its output closes it.** `./scripts/release.sh X.Y.Z 2>&1 | head -n 18` used to end the script of a broken pipe after the release commit and before the tag, and the recovery text it prints for that state was never read; it now keeps reading its own output after the reader has gone (`kwt_hold_output`, now in `scripts/lib/hold-output.sh`, which `lib/kanban-worktree.sh` sources), so the cut completes: stdout and stderr, a pipe, a socket or a stream closed outright (`>&-`). What the reader never saw is not shown. A rule in your own `AGENTS.md` or role files against piping `release.sh` into `head` can go. No action.
- **`move-issue.sh`, `subtask.sh`, `finish-pr.sh`, `register-commit.sh` and `archive.sh` no longer stop when whatever reads their output closes it.** `./scripts/move-issue.sh … | head -1` used to end the script at its next write, after the move was committed in the board worktree and before it was pushed, and the next board operation was then refused over the unpushed commit. Each script now keeps reading its own output after the reader has gone (`kwt_hold_output`, which `lib/kanban-worktree.sh` sources), stdout and stderr alike, and publishes the move. This holds for a pipe, a socket (a Node harness's child stdio), and a stdout closed outright (`>&-`). A signal sent to the whole process group still stops it, and it now ends with that signal, not a broken pipe. What the reader never saw is not shown. A rule in your own `AGENTS.md` or role files against piping these five scripts into `head` can go (`release.sh` too, the line above). No action.
- **`finish-pr.sh`, `move-issue.sh` and `subtask.sh` now refuse to run unless every file they run is the trunk's committed copy**: each script, the libraries it sources and `check-board.sh`. A branch or an uncommitted edit that rewrote a check used to pass its own landing, or a card's or slice's move to `qa_complete/`. They compare with the trunk of the repository they are run in, so a copy of `scripts/` outside it is held too; a deleted listed file counts as a difference; and with no trunk ref to compare with (the fetch failed, the tracking ref is gone) they refuse before writing to the board worktree, so fetch first. The refusal names the files and the way out: a branch that is only behind the trunk's scripts is rebased on it, otherwise the trunk's copy runs from a freshly pulled main checkout on the trunk (`finish-pr.sh` gates a branch's checkout with `--worktree <path>`). It writes no progress record. `--help` is unaffected.
- **A signalled `release.sh` now stops.** A TERM or INT to the script during a cut used to print its abort text and then carry on to commit, tag and push, and a HUP printed that text while the commit still landed; it now restores the bump (or, when the release commit already exists, says so and leaves it) and exits 143, 130 or 129. The account names the commands that finish or abandon the cut, including `--publish-only` when you publish.
- **The board tools' refusals over unpublished work in the board worktree no longer tell you to publish it as the usual answer.** This covers unpushed commits (on the trunk, and on a branch the worktree is attached to) and uncommitted changes. Each lists every commit with its author and subject, and says that pushing publishes all of it unchecked. A commit is offered for publishing only if you saw a failed op name it among its "Commits that did NOT land" (an author is no test: a hand commit carries the same one); uncommitted changes only if you saw an op fail mid-write. Local trunk work the board worktree was built from is not the tool's to publish: whoever made it publishes it from the main checkout when it is ready, never through the worktree, and anyone else asks; on an attached branch no op commits, so it asks. Every other case asks, and the ask's default is "leave them and stop", not "publish them". A push that fails because the remote is unreachable now names the commits that did not land too.
- **The `design` module now ships `/design-pull` and `/design-publish`**, the Designer's canvas order as commands, with `normalise-canvas.py` and `resolve-anchor.py`. They read the canvas by sha from one listing, show you the diff and commit only on your go-ahead, send only what changed and stop on any warning that a person's edit was replaced; nothing passes through you. Optional requirements: Claude Code 2.1.228 or later, and `/login` (the commands make a read-only call first and say what to do if it is refused). Module 0.5.0; `kit-upgrade.sh` carries an enabled project to it. No action.
- **The `design` module now ships a renderer, contrast and target audits, a Material 3 token generator and a token converter.** `render.py` draws boards with Chrome (it needs a design runtime you supply; the module cannot ship it), `contrast-audit.py` measures token pairs and 44 px targets, `m3-tokens.mjs` (Node 22 or later, optional) writes token files from a seed colour using a vendored Apache-2.0 colour library, and `dtcg-convert.py` writes a design system's `tokens.json` and `tokens.css`. The Designer role drops those needs-the-next-version lines. A project that does not enable the module changes no behaviour.
- **A path any test reads is now stated to be code.** A test that reads a board file, a spec or a design canvas runs against what the trunk holds, and a metadata commit runs no gate, so one can turn the trunk red unseen. `MANUAL.md` § The code-vs-metadata rule and the `CODE_GLOBS` comment in `scripts/config.sh` now say to list such a path in `CODE_GLOBS`, and the design module's `requirements/design/README.md` says a test reads the canvas at the card's pin, never at HEAD. Nothing is refused differently. No action; if a test of yours reads a metadata path, add the glob.
- **`DECLARED NONE` is the one cheap answer for something this project decided it has no use for.** Two warnings that repeated on every run until answered now close with it: a `TEST_GLOBS` (or `CODE_GLOBS`) entry that matches no file takes a trailing `# DECLARED NONE — <why>` comment on its own line in `scripts/config.sh`, and a role doc's `Model & effort contract` row carrying `DECLARED NONE` anywhere in it is no longer counted by `check-board.sh` `[s]` as `<fill in>`. An entry or row without it warns as before; an entry marked so that does match a file is a finding in `[g]` that holds graduation back (remove the marker, or the files); and a `DELETE-IF-UNUSED` member the project has no use for is deleted, since `DECLARED NONE` is not an answer for one and `[g]` says so. Nothing here changes the verdict. `process/SEED.md` says so beside each item. No action required.
- **`check-board.sh` prints its findings first and folds the arms that found nothing into one line.** The report is now the preamble, every arm holding a `⚠` line, every other arm in full, one line (`── no findings, folded …`) naming each folded arm, then the verdict. One of the kit's own arms is folded when it holds no `⚠` and no skipped or did-not-run wording; an arm from a module or your own `check-board.d` is folded only when it printed nothing but `✓` lines, returned 0 and said nothing about a skip, and one that returned status 3 prints a `status 3` line naming it and is never folded. The graduation arm keeps its `hooks:` and `→ graduation` lines. A clean report went past the SessionStart hook's byte budget on day one, so the hook cut findings off behind clean headings; past its budget the hook now also keeps the graduation `hooks:` and `→ graduation` lines and every `status 3` line first, then as much of each `[+name]` section as fits (an arm that returned 3 from its status line backwards, newest first, where its findings are), and says when it cut one short. `check-board.sh --full` prints every arm in order with its count and source, as before. The verdict line and every `⚠` line are the same in both, so `release.sh` gate (d) and `kit-init.sh` still key on the verdict. A script that reads an arm's line must call `--full` (see Action required).
- **`finish-pr.sh`'s refusal for an empty `GATES` table names the way out.** When a branch declares the project's first gates, the trunk's runner has nothing to judge it by and the refusal said only "fix scripts/verify.sh". It now says the trunk's table is empty and to land `scripts/verify.sh` on the trunk first with `./scripts/register-commit.sh`, then re-run `finish-pr.sh`. It still refuses; a gate refused for any other reason reads as before.
- **The `## Ablation` prompt asks for any build step between the break and the red line.** The card templates, `dev.md`'s checklist item and `qa.md`'s re-run step say to name it on the `Broken:` line when the red line appears only after a rebuild, so a re-run does not read a working ablation as broken. `finish-pr.sh`'s check of the section is unchanged.

## [0.12.4] — 2026-11-01

### Changed

- **The `design` module now ships its card gate, a design-rows check and a QA design-cell check.** A card arriving in `in_progress/` or `dev_complete/` is refused, with a `Next:` line and nothing changed, unless its `design:` entries are pinned to commits that resolve, of screens approved at a commit that is an ancestor of the pin and still true on the trunk (or waived by a recorded decision), and a `design:` of `none` or one that lacks a screen the card's ACs cite is refused when an AC is tagged `(UI)` (a story's `UI:` line alone is only a report line); the module's own notes carry the Action required entry for cards already in flight; a card that was in progress and is back from `blocked/` is checked only for being pinned, since drift is reported, not blocked. A card cannot reach `qa_complete/` while an AC tagged `(UI)` or citing a screen has no verdict row of kind `design` with an entry for each state it cites. The QA gate refuses a PASS row of kind `design` whose cell is not `identical`, cites a pin the card lacks, names PNGs the **trunk** does not hold (QA commits them there with `register-commit.sh`), has an image that is no PNG or a build image equal to the pin image, or a pin image that is not the render the pin commit holds for that screen. Slices are covered. A card cannot leave `todo/` pinned to a commit that holds no render of the state. The landing gate's one-observed-row rule now counts a PASS row whose evidence kind has a `qa-cell` check that ran and passed, so a card or slice whose every AC is of such a kind can land (no module is named). Each check is the module's own file read from the trunk; a check that cannot run (no Python, no answer from the tool) refuses as broken; a project that does not enable the module changes no behaviour.

