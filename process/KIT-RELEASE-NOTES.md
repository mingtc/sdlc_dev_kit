<!-- KIT-CLASS: KIT — the kit's OWN release notes, written for the project that adopted it.
     It travels unedited and is never a project's own release notes: yours are whatever
     scripts/release.sh's RELEASE_DOCS seam declares. -->
# The process kit — release notes

**What changed in the KIT, release by release, and what an adopted project must do about it.**
This file describes the development-process kit you are running — not your product. Your own
release notes are whatever your `scripts/release.sh` declares in its `RELEASE_DOCS` seam.

- **Which version am I on?** [`KIT-VERSION`](KIT-VERSION), one line, beside this file.
- **The full engineering log** — every change with its reasoning, and the change file behind it —
  lives in the kit's own repository, not in this copy. A copy of it here would go stale the day
  you started editing your kit, and it links to files that exist only in that repository.

## How versions work

| Bump | Means |
|---|---|
| **MAJOR** | A project already running on the kit has to change how it works: a role renamed, a status folder added or removed, a contract's invariant changed. Every such change is listed under **Action required**. |
| **MINOR** | New material or changed guidance you can adopt when you like. Nothing breaks if you ignore it. |
| **PATCH** | Corrections: wrong paths, broken links, wording, a refusal that should have fired and did not. |

## How to upgrade an adopted project

**There is no updater, and that is deliberate.** The kit is *copied* into your repository on day
one and becomes yours — your adapter, your role set, your gates. An automated overwrite would
discard exactly the local hardening the kit tells you to do. So an upgrade is a read, not a run.

**First, how does a newer version reach you, and whose job is that?** The party who gave you the
kit sends you the next zip; if nobody gave it to you, nobody will, and checking for one is yours to
schedule. Write down which — and, if it is yours, on what trigger — in
[`PROJECT.md`](../PROJECT.md) § The kit, upstream.

Once you hold a newer release:

1. Read every version entry below that is newer than your [`KIT-VERSION`](KIT-VERSION).
2. Apply the **Action required** items — those are the only ones that can break you.
   Kit feedback, unless `PROJECT.md` sets `kit-feedback: manual` or `off`: an **Action required** item you could not apply as written is a `K-NN` in `process/KIT-FEEDBACK.md`, with the item named in its *The moment.* block — `process/MANUAL.md` § Kit feedback.
3. Adopt whatever else you want from **Changed** / **Added**, file by file, the same way you would
   any other change: through your own board, with your own gates.
4. Update your `KIT-VERSION` to the version you have reached, so the next reader knows where you
   are.

Diffing your kit against a newer release is a legitimate way to do step 3 — but expect the diff to
include your own local law, which is not drift.

### Or let git do step 3 — a three-way merge against the release you are running

**An option, not the procedure.** The read above stays the default, and it is still how you decide
every conflict this produces. Nothing here ships: it is plain git over your own history.

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

Without either — no first commit that passes ONCE and no zip of your version — the read is the
route.

**Before you commit — what this does not do for you:**

- **Steps 1 and 2 still apply.** This moves text. An **Action required** item is something to *do*,
  and applying its release does not do it. Step 4 needs no action unless you edited `KIT-VERSION`
  yourself: the new release's copy arrives with everything else.
- **A clean hunk arrives without a question.** That is what makes this cheap, and it is why nothing
  is committed for you: `git diff --cached` is everything you are about to adopt, and it gets the
  review any change gets.
- **A line the kit ADDS arrives unstamped**, clean or conflicted: `kit-init.sh` stamped the lines
  that existed when it ran. What it stamps: in `.claude/roles/` and `.claude/templates/`, `<PREFIX>`
  becomes your prefix, and so does `KIT-` (before a non-digit in the role docs, before anything in
  the templates); `<project-name>` becomes your project name; `<trunk>` (templates) and the word
  `main` (both, and only if your trunk is something else) become your trunk. In `scripts/`: your
  prefix, PRD prefix and project name in `config.sh`, your gate in `verify.sh`, and — if you passed
  `--roles` — your role set in every script that enforces the shipped one. **In these checks the
  angle-bracket tokens are literal** — they are what to search for, not blanks to fill. The first two
  lines must print nothing; the third must show **your** prefix (the § Known gaps check):

  ```sh
  git grep -nE '<PREFIX>|<project-name>|KIT-[^0-9]' -- .claude/roles | grep -v 'KIT-CLASS:'
  git grep -nE '<PREFIX>|<project-name>|<trunk>|KIT-' -- .claude/templates | grep -v 'KIT-CLASS:'
  ./scripts/new-issue.sh --help | grep -o -- '--id [A-Z]*-NNN'
  ```

  If your trunk is not `main`, this must print nothing too:

  ```sh
  git grep -nw main -- .claude/roles .claude/templates
  ```

  And if you passed `--roles`, so must this:

  ```sh
  grep -lF -- "$(git show kit:scripts/githooks/commit-msg | sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p")" scripts/*.sh scripts/githooks/*
  ```

  Stamp by hand whatever they print.
- **A file you replaced or deleted conflicts whenever the kit changes it.** A `README.md` or
  `CLAUDE.md` you made your own is left as a content conflict (`git checkout --ours <file>` keeps
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
names what is still entangled, what it costs you, and how to check each one in your own copy. The
kit's repository additionally carries the open, not-yet-fixed findings under `changes/open/`.

### UPGRADING CAN UN-CONFIGURE YOUR PROJECT — what to re-check, and why

**The upgrade above is a read, not a run, because an automated overwrite *"would discard exactly the
local hardening the kit tells you to do."* That reason is right, and the kit does not yet act on it as
strongly as it warrants: the hardening is ENUMERABLE, and the kit does not enumerate it.**

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

- **If your `.claude/roles/qa.md` still ends a regression bullet with `…Bugs filed: <PREFIX>-NNN. Merged."` and then
  squash-merges via `finish-pr.sh`, replace its *FAIL on regression* block and the `Major`/`Minor` paragraph under it** with
  the shipped ones. The old order leaves the branch unmerged under a card that says it merged.

- **The self-test harness is split into files.** `scripts/test/run.sh` is still the one command. It
  keeps its header, startup guards, `CASES` and the run loop, and sources `scripts/test/lib/*.sh`,
  then `scripts/test/cases/*.sh`. The case list and every case's verdict are unchanged.

  **What to do:**
  1. **Before upgrading, run `git diff kit -- scripts/test/run.sh`.** Empty: take the new
     `scripts/test/` whole. Anything printed will conflict: keep the new `run.sh`, and re-apply each
     edit in the file its region moved to, which the table after this list gives. To find a function:
     `grep -n '^<name>()' scripts/test/lib/*.sh scripts/test/cases/*.sh`.
  2. **`scripts/test/` is one unit** with `process/KIT-MANIFEST`. Copy all of it: a new `run.sh` on
     its own refuses, because it defines no case.
  3. **Every `*.sh` under `scripts/test/lib/` or `scripts/test/cases/` is now harness**: loaded, and
     read by the cases that census the harness's own text. Keep nothing else there.

  | Was in `run.sh` | Now in `scripts/test/` |
  |---|---|
  | header, startup guards, `CASES`, registry guard, run loop, summary | `run.sh` |
  | neutral config (`KIT_NEUTRAL_*`), recorders, `make_sandbox` (the sandbox board's status set), `seed_*`, `_neu_*`, `_kit_neutral_*`, `origin_*`, `_plant_in_function` | `lib/fixtures.sh` |
  | `move-issue.sh`, `next-id.sh`, `commit-msg`, push failure, trunk chain, config seam, progress record, dirty guard | `cases/board.sh` |
  | `finish-pr.sh`; `verify.sh` and its guard floor | `cases/landing.sh` |
  | `archive.sh`, `archive-progress.sh`, rotation day | `cases/archive.sh` |
  | workflow runners, agent definitions, the settings example | `cases/runners.sh` |
  | `check-board.sh`'s arms, `cb_*`, `_lived_signals` | `cases/check-board.sh` |
  | `kit-init.sh`, creation scripts, minted cards, role enforcement, `kit_init_sandbox`, `has_issue_template` | `cases/kit-init.sh` |
  | `release.sh`, the consumer updater, `rel_*`, `has_release` | `cases/release.sh` |
  | conformance over the shipped set: skills, CLI shape, help windows, the floor, templates, exit codes, the manifest | `cases/shipped-tree.sh` |
  | cases that read the harness itself, ship state, isolation | `cases/harness.sh` |

- **`finish-pr.sh`'s post-merge check usually read the branch you had just landed, not the trunk —
  and printed `POST_MERGE_GATE: PASS` naming your trunk.** It ran the gate in the checkout that had
  passed the pre-merge gate, which is required to sit at the branch tip, and nothing moved it after
  the merge. It read the trunk only when the landing switched that checkout there.
  It now reads the **landed commit** in every posture, and its human line names the commit it read.

  **What to do:**
  1. **Re-check any PASS recorded before this version.** A pre-fix `POST_MERGE_GATE: PASS` was a
     reading of the trunk **only if the same run also printed `Switched the main checkout to
     <trunk>` and its `post-merge verify --quick: PASS` line names your main checkout's path.**
     For every other PASS — `--worktree`, a detached checkout, a checkout on another branch name,
     the trunk held by another worktree, a checkout with uncommitted changes — run
     `./scripts/verify.sh` on your trunk once.
  2. **An automation keyed on `POST_MERGE_GATE:` must handle a third word, `UNRUNNABLE`**: nothing
     about the trunk was measured (no tree could be read, its gate is not executable, or the gate
     ran and its summary counts only gates that could not run). Treat it as no reading — never as a
     pass, and not as a red trunk. The exit code is unchanged.
  3. **The human line changed** to `post-merge verify --quick: PASS|FAIL on <trunk> at <sha> (… in
     <tree> — <how it got there>)`. Anything parsing the old sentence must be updated; the machine
     line is still one bare word.
  4. **Your checkout may be moved, conditionally, and the run says so.** Already on the trunk and
     containing the landing: not moved. Clean: **detached at the landed commit and left there** —
     including the worktree you passed to `--worktree`; check a branch out before working in it.
     Uncommitted tracked changes: not moved; a temporary worktree is read and removed instead.
  5. **A red in any post-merge reading is now COULD NOT RUN** when the gate's own summary shows
     it was environmental (gates that could not run, none that failed) — previously it would have
     been a FAIL.
  6. If you carry an edited copy of `scripts/finish-pr.sh`, port its post-merge block by hand.

- **The runners have a new RUN-OUTCOME member, `NO_VERDICT`, and an out-of-set verdict no longer
  spends the fix round.** If anything you run reads the outcomes `.claude/workflows/wave-runner.js`
  or `.claude/workflows/tranche-runner.js` return — a report template, a dashboard, a script that
  tallies a run — teach it `NO_VERDICT`: the last review leg of an issue returned nothing, or a
  value outside the four verdict tokens. It HALTS the run and means **unreviewed, not failed**; do
  not count it as a failure. Behaviour change: a review verdict outside the four tokens used to be
  treated as a FAIL and sent the issue through the fix round; it now halts as `NO_VERDICT` with no
  fix round. If you carry edited copies of the runners, port two edits: the `isVerdict` guard on
  the fix-round trigger (`qa && isVerdict(qa.verdict) && !isPass(qa.verdict)`), and the
  `NO_VERDICT` branch ahead of the FAIL branch. `process/templates/run-report.template.md` § 1 has
  the matching verdict-path line. Not yet covered: the review of a park.

- **If your remote is a local bare repository made from the old recipe, point its HEAD at your
  trunk:** `git -C /path/to/<project>.git symbolic-ref HEAD refs/heads/<trunk>`, then in each existing
  clone `git remote set-head origin <trunk>`. The old recipe left the bare repository's HEAD on git's
  own default branch, so a fresh `git clone` of it checks out nothing, and in such a clone
  `scripts/check-board.sh` reports `trunk: GUESSED from the kit's last-resort constant`. The recipe
  (`kit-init`'s refusal, README, `process/GIT-HOSTING.md` § 3) now sets it at creation.

- **If `kit-init` completed on your repository but shipped kit files never reached your trunk,
  commit them.** It happened on the empty-first-commit path the old recipe offered, and when a
  shipped file was ignored (a global excludes file often ignores `CLAUDE.md`). Run `git status` and
  `git status --ignored`: commit the **kit** paths they name — `README.md`, `PROJECT.md`,
  `CLAUDE.md`, `AGENTS.md`, `setup.sh`, `.env.example`, `consumers/`, `docs/`, and any other path
  listed in `process/KIT-MANIFEST` — with `git add -f -- <those paths>` (not a blind `git add -A`,
  which would take your own files too), a role-prefixed subject, and a push. Delete a shipped file
  instead if you do not want it. `kit-init` now refuses, writing nothing, while a shipped path is on
  disk but not committed — ignored ones included — and prints the exact command; its recipe's first
  commit now commits the kit as unzipped.

- **Kit feedback is now recorded by default — decide whether you want that.** `PROJECT.md` gains
  § The kit, upstream. Its `kit-feedback:` line is `auto` unless you change it, and **a `PROJECT.md`
  with no such line is read as `auto`**. Under `auto`, seats write to `process/KIT-FEEDBACK.md` at
  named moments, without being asked: a local ruling that resolves a kit contradiction or silence,
  session close, a kit upgrade, and an orchestrated run's close. Each session's `progress.md` entry
  then ends with a `kit-feedback:` line. The moments and the line are in `process/MANUAL.md` § Kit
  feedback. The checklist lines are in the session-end checklists of the PM, Dev, QA, Refactorer
  and Orchestrator role docs. A dispatched leg records a finding as a `kit-finding:` line in its
  `progress.md` entry, and the orchestrator writes the entry. **Choose one:** keep `auto`; set
  `manual`, which is today's behaviour (written on request); or set `off`, for a project whose
  findings are not meant for the kit. Then fill *Feedback is sent to* and *Kit updates reach this
  project by*, where "nobody" is a legal answer. **Nothing is ever sent automatically.**

- **A wave run may have dropped issues — green or halted — so check your past run reports.** Until
  this release, when a leg's `agent()` call THREW inside `.claude/workflows/wave-runner.js` (the
  runtime does this once the turn's token budget ceiling is reached, and on a call it refuses), the
  issue vanished from the results and the wave was judged on the rest; a wave whose issues all
  vanished passed. **To check a past run:** compare the issue ids you dispatched with the ids in its
  returned `results` — an id missing from a wave that ran was dropped, and its work may be
  half-done: look for its branch, its board folder and any landing commit on the trunk before
  re-dispatching it. (Issues of a wave the run never started are unrun, not dropped.)
  `git log --oneline --grep '→ qa_complete'` lists what reached QA-complete; a dispatched id with no
  match is a question to check, not proof of a drop — `LAND_READY`, parked and failed issues are
  legitimately absent. For `.claude/workflows/tranche-runner.js`, a run that ENDED IN AN ERROR
  instead of a result lost every outcome it had recorded, landings included: reconcile it against
  the trunk rather than the report.
- **The runners have another RUN-OUTCOME member, `LEG_ABORTED`.** Anything that reads the runners'
  outcomes must accept it: a leg's call threw before the issue reached an outcome — **state
  unknown, not failed** — and the run halts. Each such record carries `error` naming the leg. If
  you carry edited copies of the runners, port: the `leg()` wrapper and `await leg(` at every
  `agent()` call; in the wave runner, the per-thunk catch, the null-to-`LEG_ABORTED` mapping in
  place of `.filter(Boolean)`, the re-throw of an unmarked error, and `waveOk(rs, dispatched)`; in
  the tranche runner, the loop body's `try/catch`.

- **If you carry edited copies of the runners, port `precondition_failure` WITH its routing — or do
  not take the new review instruction.** `.claude/roles/qa.md` and `process/MANUAL.md` step 6 now tell
  a reviewer who cannot form a verdict to set `precondition_failure` and omit `verdict`. An edited
  runner without the change sets no `additionalProperties`, so a reviewer can send
  `precondition_failure` beside an invented PASS and the old runner LANDS it on a gate that never ran.
  Port all of it: the `precondition_failure` property in `QA_SCHEMA` and `PARK_SCHEMA`, `verdict` out of
  both `required` lists, `preconditionFailed` / `formedVerdict`, and every review decision routed
  through `formedVerdict`.

- **`scripts/verify.sh` exits `3` — not `1` — when nothing failed but a gate could not run.** A
  gate whose command never started (a missing interpreter, an uninstalled dependency — exit 126 or
  127) was counted `could not run` in the summary but made the runner exit `1`, the same as a real
  failure. Now: `0` green, `1` at least one gate **failed** (it still wins when both happen), `2`
  the runner refused its table, **`3` nothing failed and at least one gate could not run.**
  **Action required only if something of yours tests the status for exactly `1`** (for example
  `[ $? -eq 1 ]`, or a `case` with `1)` as its only red arm): add `3` as a red that means "fix the
  environment", or treat any non-zero as red. `if ./scripts/verify.sh`, `|| exit`, `set -e` and CI
  steps need nothing. **If you run your own gate runner instead of the kit's** (you implemented
  `contracts/verify-gate.md` yourself), § 5 now asks it to give the two reds different non-zero
  statuses; until it does, `finish-pr.sh` still reads its summary line for an exit `1`, as before.
  `finish-pr.sh` and `release.sh` now say **COULD NOT RUN** instead of FAILED when the gate exits `3`.

- **The one-gate `scripts/verify.sh` that `kit-init --gate-command` writes now exits with the
  frame's statuses, not its gate's.** It used to `exit "$GATE_RC"`: a gate that could not start
  printed `FAIL` and exited 126/127, and a gate that fails with its own `2` or `3` reached
  `finish-pr.sh` as "refused" or **"COULD NOT RUN — nothing was measured"** — still refused, but
  with a false diagnosis. **Do you have it?** Your `scripts/verify.sh` says `GENERATED by
  kit-init.sh` near the top (`grep -n 'GENERATED by kit-init.sh' scripts/verify.sh`). A project that
  kept the kit's full frame (a `GATES=(` table) is not affected. **Action required if you have it:**
  either adopt the full frame (the kit's `scripts/verify.sh`) and declare your gate in its `GATES`
  table, or replace the file's last two lines — the `if … PASS … else … FAIL … fi` line and
  `exit "$GATE_RC"` — with the mapping from a freshly generated one: `0` → exit 0 (`PASS`),
  `126`/`127` → exit 3 (`UNRUNNABLE`), anything else → exit 1 (`FAIL`, keeping `rc=<code>` in the
  line), followed by the count line `gates declared: 1 · ran: … · passed: … · failed: … · could not
  run: … · skipped: 0`. The quickest way to get the exact text is to run `kit-init.sh --gate-command`
  in a scratch unpack of this version and copy its tail.

- **A branch no longer judges itself: the trunk's `scripts/verify.sh` gates any branch that changes it.** `finish-pr.sh` ran
  the branch's own runner, so a branch could weaken or delete the gate that judged it and land green. Now the trunk's copy
  runs against the branch's tree (QA's review gate likewise, `qa.md` step 3) and the run says so. **If a branch legitimately
  changes `verify.sh`:** it must pass the trunk's current gate; the change governs the NEXT landing. To tighten a gate the
  trunk cannot yet pass, land the gate change on its own first. A killed run may leave `scripts/.verify-trunk.*`; delete it.

### Added

- **A default for which hat signs day one's commits.** `process/contracts/role-gate.md` § 2a
  declares the pre-role hat as a setting: `[PM]` for every commit a seat authors on day one, up to
  and including the first spec. The unpacked kit's first commit, code and tests, and the
  initializer's own commits fall outside it. A project that wears another hat records the
  departure, its span and its reason in `process/LOCAL-PROCEDURES.md`. **Nothing to do.**

- `process/templates/KIT-FEEDBACK.skeleton.md` gains a visible "leaves your project — review and
  cut before sending" header, a handwritten `## About this project`, and a per-entry *The moment.*
  block. Copy the header and the About block into your existing `process/KIT-FEEDBACK.md` by hand;
  existing entries stay as they are.
- Entries now quote a kit script's own diagnostic line only: never test output, source, diffs or
  file contents.

- **`check-board.sh` reports two new things, and neither changes the verdict.** `[m] PRD coverage`:
  of your landed issues, how many carry `prd: n/a`, and how many of those give no `prd_reason:`.
  `[n] kit-feedback line`: under `kit-feedback: auto` (the default, including when `PROJECT.md` has
  no such line), whether your newest `progress.md` session entry ends with its `kit-feedback:` line —
  a missing line is reported with ⚠, never refused; under `manual` or `off` it is not checked. Both
  are marked `reports only`, so `kit-init`'s self-check ignores them. **Nothing to do.**

### Changed

- **Shipped scripts carry their rules, not their history.** Script comments keep each rule and a one-line
  reason; incident accounts, superseded designs and restated rules are removed, and some `--help` text is shorter
  with the same usage, options and exit codes. **Nothing to do.**

- **`PASS-with-AC-correction` is scoped where it is stated.** The verdict applies to an AC's
  *illustration*, never to its *requirement*. That limit was in `process/MANUAL.md` step 6 but
  fifty lines below the verdict table, and `.claude/roles/qa.md`, `process/templates/run-report.template.md`
  and a comment in `.claude/workflows/wave-runner.js` restated the verdict as "the AC was wrong".
  All now carry the scope, and the table's cell states it. **One new instruction in the run
  report's § 2:** a wrong *requirement* is a PM decision — § 9 with PM as its owner if the issue can
  be parked, a stop if it cannot. The token `PASS_AC_CORRECTED` is unchanged. **Nothing to do.**

- **`process/doctrine/generality.md` — § A.1 counts independence per surface, and § C restates its
  evidence with a dated count.** Consumers who could not have coordinated may still have shared the
  constraint — for example the same agent harness, vendor tooling, exercise design or product — and
  on a surface that shared thing shapes, their agreement now counts as one. § C now states a dated
  count across every consumer observed so far: the flip-flop test (§ A.2) met a real disagreement
  between consumers and sorted it correctly as a setting, the closest case to the sheet's own
  falsifier was examined and judged not one, and the evidence is still called thin because every
  consumer shared one environment. **Nothing to do:** the four questions are unchanged.

- **`process/contracts/acceptance-tier.md`: a tier mark that is wrong on its face is now removed
  when found, by whoever finds it** (outside a calibration ritual, which records it as a finding).
  It applies only to the named classes — a presentation-pinning artifact, or a test whose subject is
  the repository's own machinery rather than the product — and only with a named reason checkable
  against the tree and the corpus manifest. Adding a mark, or re-deciding one that turns on intent,
  stays write-time and author-only. `process/doctrine/conformance-tier.md` § A.4 carries the pointer.
  **Nothing to do.**

- **`process/doctrine/generality.md` § A.2 — a fourth row and a discoverability caution.** When
  consumers agree on an outcome by different arguments, it is a rule whose test is unstated: ship it
  with one sentence stating what it tests. When a consumer resolves a surface the opposite way
  because they never found the answer you already ship — their reason would dissolve given it —
  that is not a setting: the remedy is a pointer from where they were, and the answer is checked
  first, because a defective answer may make the dissent the better call. **Nothing to do:** the
  four questions are unchanged.

- **The corpus manifest has a legal forward-reference marker on day one.** `requirements/CORPUS.md`
  (and its skeleton) accepted only `forward-referenced (<ISSUE-ID>)`, and no issue id exists at
  SEED step 4. It now also accepts `forward-referenced (SEED step <N>)` on day one, for a row a
  later seed step lands; the step form does not outlive day one. **Nothing to do:** a project past
  day one never writes the step form.

- **`process/KIT-FEEDBACK.md` on day one is "empty rather than fabricated", not "empty".** SEED's
  day-one checklist, the skeleton, `process/doctrine/distribution.md` § A.8 and
  `process/EXTRACTION.md` said the file must be empty; the reason behind it (findings are noticed in
  week one and lost by week three) argues for writing a finding down the day it happens. A day-one
  finding now belongs in the file; an entry written only to fill it does not. **Nothing to do.**

- **"Direct to the trunk" names the ref, not a checkout** (`process/MANUAL.md` § The code-vs-metadata
  rule). Metadata committed on the trunk branch from a linked worktree lands on the trunk just the
  same; the checkout that held the trunk can be detached rather than moved to a branch — though not
  while a leg is working from it. **Nothing to do.**

- **`PASS-with-AC-correction` now states when it is available, wherever it is handed to a
  reviewer.** The reviewer must have checked the fact themselves against a citable source — "the AC
  looks off to me" is a FAIL or a question, never this — and the AC amendment carries the corrected
  illustration **and its source**. Both were already the rule in `process/MANUAL.md` § The Dev → QA
  handoff, step 6; `.claude/roles/qa.md` § The third verdict and the QA prompts in
  `.claude/workflows/wave-runner.js` and `.claude/workflows/tranche-runner.js` now say so.
  **Nothing to do.**

- **An AC whose deliverable is prose describing code behaviour is now held to its claims, on both
  sides of the handoff.** *Dev:* for such an AC, "it is a description" is no longer a
  test-or-justify justification — each behavioural claim needs a test or a `file:line` QA can
  check it against (`.claude/templates/ISSUE.template.md`, `.claude/roles/dev.md`'s Definition of
  Done, and the Dev prompts in `.claude/workflows/wave-runner.js` and
  `.claude/workflows/tranche-runner.js`). *QA:* such an AC is graded claim by claim, and a claim
  that can be neither tied to a falsifier the suite resolves nor located at a `file:line` leaves
  the bullet unmet — `FAIL_AC`, naming the claim (`process/MANUAL.md` § The Dev → QA handoff step
  4, `.claude/roles/qa.md` step 4, and both runners' QA prompts). **A pure-docs AC — prose that
  makes no claim about behaviour — is unaffected.** Issues already minted from the old template
  keep their wording; the rule binds at review either way. **Nothing to do.**

- **`process/doctrine/instruments.md` § A.8 names the shadowed guard; `.claude/roles/qa.md` step 5
  asks for it.** A check added beside an existing one can satisfy the existing check's tests (they
  assert only that an input is refused, not which check refused it), so the old check can be deleted
  with every gate still green. The defence: break the old check with the new one in place and
  confirm its own test reddens. An unaddressed shadow is a FAIL even with the suite green. No
  mutation harness is required. **Nothing to do.**

- **An AC that names a gate the tree under review does not hold is a precondition failure**
  (`process/MANUAL.md` § The Dev → QA handoff, step 6; `.claude/roles/qa.md`; `.claude/roles/dev.md`'s
  Definition of Done). That happens, for example, when the gate's machinery is still on an unlanded
  branch, and the gate runner cannot report it. Do not grade such an AC from other evidence: run the
  gate against a tree holding both the change and the gate — this branch's diff applied onto the tree
  that carries it — and name that tree and commit, or halt before a verdict and report it, naming the
  AC. **Nothing to do.**

- **`.claude/skills/orchestrate/SKILL.md` now says how a run's id reaches every leg**, so a run's
  progress records carry `run=<id>`. An orchestrator that picks the id at step 0 passes it in every
  dispatch brief, and each leg prefixes its shipped-script and board commands with
  `KIT_PROGRESS_RUN=<id>`; an operator can instead set it before launching the session. An `export`
  inside an agent's tool call did not survive past that call on the harness measured. Confirm by
  grepping the main checkout's progress record (every worktree writes there). **Nothing to do**, but if you want your runs grouped, set
  the id that way.

- **`.gitignore` now ignores `.claude/settings.local.json`** — the agent harness's per-checkout,
  per-person settings file, which can carry an `env` block such as a run id that would be stale in
  every other clone. The harness ignores it for you only when it wrote the file itself, and only on
  that machine. **For a running project, optional:** add the line `.claude/settings.local.json` to
  your `.gitignore`. If `git ls-files .claude/settings.local.json` prints it, it was committed
  already: before anyone runs `git rm --cached .claude/settings.local.json`, tell every teammate to
  copy their own `.claude/settings.local.json` aside — the next pull DELETES it from their clone (or
  refuses, if they edited it) — and put it back after pulling. `.claude/settings.json` (the shared
  one) is unaffected.

- **An upgrade can now be a three-way merge — as an option; the read stays the default.** § How to
  upgrade gains a plain-git route for step 3: a `kit` branch holding the release you run exactly as
  shipped — your Day-one first commit, checked against that release's `KIT-MANIFEST`, or else the
  zip of your version — the new release committed onto it, and `git cherry-pick --no-commit kit` onto
  a branch of your own. Lines only the kit changed arrive by themselves; your local law and
  `kit-init.sh`'s stamps stay; lines you both changed are left as conflicts for you to decide. It
  refuses a dirty tree and a zip that is not the version you named, commits nothing for you, and
  gives a back-out that touches only what the attempt did. Lines the kit added arrive unstamped, so
  it lists the checks to run before you commit. **Nothing to do** unless you want the cheaper route.

- **`prd: n/a` now asks for a one-line reason.** The issue, bug and refactor templates carry a
  `prd_reason:` line under `prd:` — leave it empty when a PRD is named; with `prd: n/a`, say in one
  line why no PRD covers the work. `n/a` stays legal, and `.claude/roles/pm.md`'s lite path names
  it. The reasons show where a PRD is missing:
  `grep -h '^prd_reason:' progress/qa_complete/*.md progress/done/*.md` lists them. **Optional for a
  running project:** add the line to your own templates; nothing reads it as a gate.

- `process/KIT-FEEDBACK.md`'s § Sending names a destination (`PROJECT.md`'s *Feedback is sent to*),
  or says the file stays put and nobody goes looking for a recipient.

- `process/doctrine/distribution.md` no longer tells a project that ships to nobody to stop before
  § A.8, in its scope line or in § B's first row.

- **A leg that returned nothing is no longer filed as a judgement.** In `.claude/workflows/wave-runner.js`
  and `.claude/workflows/tranche-runner.js`: a park review that returned nothing, or a verdict outside
  the four tokens, is now `NO_VERDICT` (was `PARK_UNVERIFIED` — and in the tranche runner it had spent
  the park fix round and could end `LANDED` on a park nobody reviewed); a Dev leg that returned
  nothing or a status outside its schema — first pickup or either fix round — is now `LEG_ABORTED`
  (was `BLOCKED_DEV`, or `FAILED_AFTER_FIX_ROUND` / `PARKED_OK` after a fix round), and no further leg
  runs on it. `PARK_UNVERIFIED` and `BLOCKED_DEV` now mean only what they say: the last park review's
  FAIL, and a Dev that reported `blocked`. Ratified in `process/MANUAL.md` § The RUN-OUTCOME
  vocabulary; `process/templates/run-report.template.md` § 1 has the paths. **If a dashboard counts
  those tokens,** some rows move to `LEG_ABORTED` or `NO_VERDICT`.

- **A reviewer that cannot form a verdict now says so instead of inventing one.** In
  `.claude/workflows/wave-runner.js` and `.claude/workflows/tranche-runner.js`, the QA and park
  review schemas gain an optional `precondition_failure` (name the gate that could not run, or the
  gate an AC names that the tree does not hold), and `verdict` is no longer required. A reply naming
  one is filed as `NO_VERDICT` — unreviewed, not failed — whatever token came with it; any non-empty
  value counts, so the field is omitted, never filled with "N/A". The four verdict tokens are
  unchanged. `process/MANUAL.md` step 6 and `.claude/roles/qa.md` say how to use it;
  `process/templates/run-report.template.md` § 1 says to quote it.

- **A runner's result now carries what every leg wrote.** Each record with an outcome returned by
  `.claude/workflows/wave-runner.js` and `.claude/workflows/tranche-runner.js` gains `leg_notes`: one
  entry per leg that replied, in call order, with its `summary`, `deviations`, `notes`,
  `premise_refuted` and `precondition_failure` where filled — on every outcome, including `LANDED` and
  `LAND_READY`, which used to return none of it (so `premise_refuted` on a landed issue was lost).
  Additive: existing fields are unchanged. `process/MANUAL.md` § The RUN-OUTCOME vocabulary states the
  result shape; the `progress.md` `kit-finding:` lines remain the durable record of a leg's kit
  findings. **Nothing to do.**

- **`check-board.sh`'s graduation arm reads `PROJECT.md` as written.** Command usage in your own
  docs — `` `tool <input.csv>` ``, a fenced example — is no longer counted as an unfilled blank; a
  code span holding only one `<…>` still is. **A `PROJECT.md` that no longer carries its
  `KIT-DISPOSITION: FILL` line is now read where it used to print "skipped"**, so it can produce a
  finding: any blank left is reported, and none reads as graduated. **Nothing to do** — if a blank
  you had missed is now reported, fill it.

- **`kit-init.sh` signs its own commits with the pre-role hat, not the first role in your set.** Its
  initialization and self-check commits used to take their tag from whichever role `--roles` (or the
  hook) listed first; they now carry the hat `process/contracts/role-gate.md` § 2a declares (`PM` by
  default), or the one you name with **`KIT_INIT_ROLE=<role>`**. If your role set does not contain
  that hat, kit-init now **refuses before writing anything** and says to set `KIT_INIT_ROLE`.
  **Nothing to do for a project already initialized**; a new one that narrows `--roles` past `PM`
  sets the knob.

- **Some restated rules are now pointers, and the copies that stay are declared and checked.** `README.md`'s
  extra copies of the bare-remote recipe, `orchestrator.md`'s and `MANUAL.md`'s account of `finish-pr.sh`'s
  post-merge reading, and `pm.md`'s paraphrase of the third verdict now name their source. Each rule's canonical
  site lists its deliberate copies in a `RULE-COPIES` comment; a self-test case goes red when a listed copy loses
  the rule's key sentence or an unlisted shipped file gains it. **Nothing to do** unless you reworded a listed
  copy — the case names it.

- **The self-test holds the two workflow runners' shared code identical**; each runner's `// Own COMMON lines` comment
  declares the brief lines only it has. **Nothing to do** unless you changed one runner's shared code alone — the new
  case names the difference.

- **`verify.sh --scope` says who decides whether an item matched.** The frame hands each item to your `select` gate's runner
  and never resolves it, so a runner that exits 0 on no match reads green; the `SCOPE: NARROWED` line now says so. **If your
  `select` runner exits 0 on no match,** declare one that refuses instead.

- **A `--worktree` landing now deletes its local branch.** When the gate checkout sat on the branch, `finish-pr.sh` left the
  branch and printed a `branch -D` for you; it now detaches that checkout at the landed commit first (where the post-merge
  check left it anyway), then deletes the branch. Check a branch out there before working in it again.

- **A runner leg that names an agent type now runs on that type's pinned model and effort.** Both runners sent the run default
  (`opus`/`medium`) on every call, overriding `devAgentType`/`qaAgentType` pins (e.g. `refactorer-worker` ran at `medium`, not
  `high`); a typed leg now sends only the model/effort its issue names. Expect those legs to cost what their pins say. The
  wave's shared brief no longer tells the main-checkout leg to work in its own worktree.

- **Where a contract sheet and any prose disagree, the sheet wins** — now stated in `process/MANUAL.md` § The three documents,
  so it reaches every harness (only `AGENTS.md` said it). `PROJECT.md`'s configuration-seam row marks `scripts/config.sh` a
  fixed name, like `verify.sh`.

- **`process/EXTRACTION.md` is current.** § 1 lists `dev/` to copy (its index and folder READMEs travel; `dev/downtime-queue.md`'s
  rows are yours); § 1.3 says `kit-init.sh` refuses while a shipped path is on disk but not committed; § 2.2 names `new-issue.sh`,
  `new-bug.sh` and `new-refactor.sh` as carriers of `todo` — renaming that column breaks every creator.

### Fixed

- **The kit zips for `0.4.0`, `0.5.0` and `0.6.0`, as built by the release ritual, probably shipped
  this file un-rolled.** Each was built before its notes were rolled, so in an affected copy the
  section headed `## [Unreleased]` IS that release's entry, and its `## [<version>] — <date>`
  heading never arrived. Check yours: if `grep -c '^## \[<your KIT-VERSION>\]' process/KIT-RELEASE-NOTES.md`
  prints `0`, your copy is affected; a kit rebuilt from the release tag is not. In the one release
  measured (`0.6.0`), nothing else differed from the tagged release except `process/KIT-MANIFEST`'s
  hash for this file, and `KIT-VERSION` was correct. **Nothing to do:** this file's section for your
  version is the correct record, and you may retitle your copy's `## [Unreleased]` heading to match
  it. From this release on, the zip is built from, and checked against, the tagged commit.

- **`kit-init` no longer dies half-way when a path it commits is ignored.** With `.claude/` (or
  another path the initializer commits) in `.git/info/exclude` or a global excludes file, it stamped
  `scripts/config.sh`, the gate runner, the role docs and `core.hooksPath`, then failed at
  "Committing the initialized tree", and every later run refused as already-lived. It now refuses
  first, writing nothing, and prints the un-ignore (a `!/.claude/` line in `.gitignore`). **If you
  hit the old failure** (a run that died there, then "already lived"), from the repository root:

  ```
  git restore --staged --worktree --source=HEAD -- scripts
  git ls-files --error-unmatch .claude >/dev/null 2>&1 && git restore --staged --worktree --source=HEAD -- .claude
  git config --unset core.hooksPath
  git status --porcelain --untracked-files=no
  ```

  The last command must print nothing before you go on. Then add `!/.claude/` to `.gitignore`,
  commit that one file with a role-prefixed subject, push, and re-run `./scripts/kit-init.sh`.

- **Progress records written from a linked worktree now land in the main checkout's
  `.progress-records/`**, and survive the worktree's removal. Before, they landed under the worktree
  and were deleted with it. `KIT_PROGRESS_DIR` still overrides the location. A bare repository's
  linked worktree, a submodule, and a `--separate-git-dir` repository's linked worktree write in their
  own checkout, as before — carry an absolute `KIT_PROGRESS_DIR` there. Expiry now runs against the
  one shared directory, so keep `KIT_PROGRESS_TTL_DAYS` one value per repository. **Nothing to do.**

- **The board scripts no longer need git 2.31.** `scripts/lib/kanban-worktree.sh` used a `git
  rev-parse` flag that arrived in git 2.31; on an older git every board script failed with a message
  that named neither git nor its version. It now works on older git and gives the same answer on
  current git. **Nothing to do.**

- **`check-board.sh` no longer leaves part of a trunk copy in your temp dir when it is killed.** When
  a supervisor, a timeout or `kill <pid>` sent TERM or HUP mid-run, it removed its temp copy while
  `tar` was still writing into it, and `tar` re-created thousands of files that look like part of a
  checkout. It now waits for the copy to finish before cleaning up. Other signals and SIGKILL are
  still out of reach, and a Ctrl-C was never affected. A detached checkout is now named
  `a detached HEAD at <sha>` instead of `DETACHED`, which read like a branch name. **Nothing to do.**
  A stray from before this fix is a `tmp.*` directory in your temp dir holding part of your project,
  and is safe to delete.

- **The self-test (`scripts/test/run.sh`) no longer leaves directories in your temp dir.** Every run
  left four: one whole sandbox and three empty ones. **Nothing to do.** Leftovers from older runs are
  `tmp.*` directories in your temp dir and are safe to delete.

- **`finish-pr.sh --worktree` no longer refuses your main checkout when you name it through a
  symlink.** The check that the path is a worktree of this repository compared a symlinked spelling
  with the resolved one, so the main checkout named through, say, a macOS `/var/…` path (really
  `/private/var/…`) was refused as *"not a git worktree of THIS repo"*. Both sides are now resolved;
  a genuinely foreign repository is still refused. **Nothing to do.**

- **`new-prd.sh` no longer leaves a half-made PRD when it fails.** It built the file in `requirements/`, so a late
  failure left it there and the next run took the following number; it now builds aside and moves the PRD in last,
  as `new-issue.sh` does. **Nothing to do.**

- **Cards and PRDs made by the creation scripts get your umask's permissions, and the final move is a rename.** They
  were built in the system temp dir, so arrived `-rw-------` (and on macOS were copied across filesystems); they are now
  built beside their destination as a hidden `.mint.*` file, removed on failure. Git always recorded them as ordinary
  files. **Nothing to do** — `chmod 644` any earlier card you want others to read.

- **`subtask.sh new` no longer leaves a half-made card in the kanban worktree when it fails.** It built the card in
  place, so a failure part-way left a partial card there; it now builds it aside, moves it in before committing, and
  gets your umask's permissions. **Nothing to do.**

- **The self-test no longer fails on a project that completed day one** because its `README.md` was replaced — a check
  added this release measured the kit's README even after SEED had you replace it. **Nothing to do.**

- **`qa.md`'s regression path could publish "Merged." on a card nothing merged, and let a Critical bug land.** A
  `Blocker`/`Critical` now always sends the issue back (`FAIL_REGRESSION`); a PASS with `Major`/`Minor` bugs lands with
  `./scripts/finish-pr.sh <ID> --note "Review — PASS. Bugs filed: <ID>."`; bugs are filed from the trunk, where the
  card is published.

- **`move-issue.sh` can move a parent issue that has subtasks.** Once a parent had any subtask, every move refused with
  "multiple files match", so a decomposed issue could never land. It now looks only at `progress/<column>/`, and
  `move-issue.sh <PARENT>-sM` refuses instead of moving the subtask off its tree — move subtasks with `subtask.sh`.
  **Nothing to do.**

- **`archive.sh` no longer leaves the board worktree dirty when `progress/done/` is missing.** `--apply` rewrote `ARCHIVE.md`
  in `.kanban-wt/` and then refused, so every later board command refused as dirty. It now refuses before writing, and
  `--dry-run` refuses the same board. **If you hit it:** `git -C .kanban-wt checkout -- ARCHIVE.md`, then re-run.

- **The self-test runs on a project whose role set is part of the shipped one.** After `kit-init --roles 'PM|Dev|QA'` (or
  any set that is a substring of the shipped alternation), `./scripts/test/run.sh` aborted at fixture setup naming
  `_neu_roles`. **Nothing to do** beyond taking the updated `scripts/test/`.

- **`check-board.sh`'s downtime-queue arm [j] reads the same source as the rest of the report.** It read
  `dev/downtime-queue.md` and `progress/` relative to where you ran it, so from a subdirectory or the SessionStart hook it
  reported a present queue as absent. It now reads `<remote>/<trunk>` (or the working tree, labelled) and names it.
  `DQ_FILE` is relative to the repository root — make an absolute value repo-relative.

- **`next-id.sh` no longer repeats an id minted on the trunk after your branch was cut.** It read only your checkout; it
  now also reads `<remote>/<trunk>`'s board and `ARCHIVE.md` as last fetched (it never fetches) and prints which it read
  on stderr. Filing from the trunk after `git pull --ff-only` is still the rule: the card has to be published there.

- **`subtask.sh new` takes only an open issue as a parent.** It accepted a subtask id (nesting a tree nothing can resolve),
  a parent in `done/` (whose tree the next `archive.sh` sweep retires, new card included) and a leftover tree with no
  parent card. Each now refuses. Follow-up work on a retired issue is a new issue.

- **`archive.sh` refuses a card whose name is already in `progress/done/`, before writing anything** — it rewrote `ARCHIVE.md`
  and then failed on the move, leaving `.kanban-wt/` dirty. **If you hit it:** `git -C .kanban-wt checkout -- ARCHIVE.md`,
  resolve the duplicate, re-run.
- **`archive-progress.sh` checks `progress/history/INDEX.md` before it writes.** A malformed or header-less index left the
  chunk written and `progress.md` rewritten with no index row (the header-less case silently). Both now refuse first.
  **If you hit it:** add the chunk's row to `INDEX.md` by hand, or restore both from git and re-run.

- **`kit-init --roles` refuses a role set it cannot stamp.** `&` was silently mis-stamped (`PM|A&B` became `PM|APM|…|ArchitectB`),
  `@` stopped kit-init half-way with files rewritten, and a quote broke the commit-msg hook. It now refuses before writing
  unless the set is letter-led alphanumeric names joined by `|`. **If you initialized with such a set,** check
  `ROLE_PREFIXES` in `scripts/githooks/commit-msg`.

- **`new-issue.sh`, `new-bug.sh` and `new-refactor.sh` refuse an `--id` already taken on the trunk.** Their check read only your
  checkout, so a card created on a branch could reuse an id minted on the trunk later; they now also read `<remote>/<trunk>`
  as last fetched (never fetching) and name it. With no configured trunk they print the same "trunk is a GUESS" warning
  `next-id.sh` does.

- **`archive.sh` no longer nests a subtask tree inside an already-retired one.** When `progress/done/subtasks/<parent>/` existed,
  the sweep moved the live tree inside it and reported success; it now refuses before writing. **If you hit it:** move the
  nested tree's contents up one level by hand.

- **`kit-init --trunk` stamps any legal branch name verbatim.** A trunk whose name holds `&`, `|` or `@` (all legal in git) was
  mis-stamped into the role docs or stopped kit-init half-way; it is now escaped. **If you initialized with such a trunk,**
  check `.claude/roles/` and `.claude/templates/` for `main` where your trunk should be.

- **`kit-init` no longer over-matches a hand-edited default.** A `PROJECT_NAME` default in `scripts/config.sh` or a
  `KWT_TRUNK_LAST_RESORT` default in `scripts/lib/kanban-worktree.sh` holding `.` or another regex character rewrote unrelated
  words; both are now matched literally, and a non-alphanumeric `ISSUE_PREFIX` default is refused before any write. **If you
  edited one of these before running kit-init,** diff `.claude/roles/` against the kit for words that changed.

- **`finish-pr.sh`'s recovery step 3 works as printed, and "Done." names a branch it could not delete.** The printed step used
  `git branch -d … && git push --delete …`, which refused a squash-merged branch and skipped the remote delete on a re-run; it
  is now `git branch -D …; git push <remote> --delete …`. A surviving branch is named on the "Done." line; the exit status
  stays 0.

- **Day one's instructions work as written.** `process/SEED.md` step 1 commits the kit before pushing (the push failed with no
  commit); step 4 copies `process/KIT-FEEDBACK.md` from its skeleton; `README.md`'s *first published commit* variant ends
  with `git -C .kanban-wt reset --hard origin/<trunk>`, without which the next board command refused.

- **`process/contracts/kanban-worktree.md` now says the sync never discards:** it refuses over uncommitted tracked changes (discarded
  only on explicit instruction) and over unpublished commits, as `board-mover.md` and the scripts already did. `drift-report.md`
  § 6: only an arm implementing no § 2 invariant must not change the verdict. `issue-creation.md`: a mutating tool with no
  preview refuses `--dry-run` as an unknown option.

## [0.6.0] — 2026-09-18

### Action required

- **If you run more than one agent session at a time, add one line to
  `process/LOCAL-PROCEDURES.md` — and it is the one obligation that may NOT live in a prompt.**

  **The finding.** An agent session that is *prompted* — it advances one burst per message and then
  stops — **cannot send anything while idle**, because sending is an act. So it cannot report the
  one state you need from it: that it has stopped. Two such sessions that agree to keep each other
  informed go quiet together, and **the silence is indistinguishable from work.**

  **And the part that decides where the fix goes.** An obligation delivered only in a session's
  opening instructions **is a conversation citing itself.** It binds the session that heard it and
  **evaporates at the next restart** — the successor inherits your queue, your board and your whole
  repository, and does not inherit the prompt. Measured on one pair across one restart boundary:
  eight unprompted progress notes before, **none** after, from a successor that was landing work,
  bouncing reviews and closing board asymmetries the entire time. It simply never knew it owed
  anyone a note, and nothing in the repository told it.

  **What to do — it is one copy-paste, and `SEED.md` step 8 now carries it for new projects:**

  ```markdown
  ## Standing obligations — these bind EVERY session, including one nobody briefed

  - **If you are working a queue while anyone else waits on you, write a one-line progress note
    at every job boundary and at least every `<interval>` — into `<the shared log or channel>`.**
    A note is not a question and it does not pause your work. You cannot be asked for it: an idle
    session cannot send anything, so silence from you is indistinguishable from work.
  ```

  Fill the two blanks with your own interval and your own destination. **It belongs in
  `LOCAL-PROCEDURES.md` rather than anywhere else** because that file is already on your
  session-start read order, which is the only property that matters here.

  **Skip it honestly if it does not apply.** A project where no session ever waits on another does
  not need the line and adding it is ceremony. **A project that runs sessions in parallel and skips
  it will not find out until a restart**, which is the expensive way to learn it.

  **The spawner's side is doctrine, not an action** —
  [`doctrine/subagent-control.md`](doctrine/subagent-control.md) § A.15: only the spawner has a
  clock (and the act that ends the run **retires** what it armed); notes come from inside the work;
  age is read from artifacts and **never asked**; overdue has a named act and a named owner; pause
  and done are **files**, so a human who cannot see the sessions can still stop them. Scoped to
  **prompted** workers on purpose — a fleet of autonomous loops does not need the first item, so
  the intervals are a setting with a default and never doctrine. Pointers from
  [`contracts/liveness-watchdog.md`](contracts/liveness-watchdog.md) § 2 and
  `.claude/roles/orchestrator.md`'s conductor's belt.

- **Your PRDs' § Decision Log becomes a CITATION LIST, and a dangling `D-NN` citation now REDDENS
  `check-board.sh` — which your release gate reads.** Two things changed together.

  **1. Where a decision lives is now decidable — the fork/fact split.** A **fork** (two defensible
  answers existed and one was chosen) is a `D-NN` entry in `requirements/DECISIONS.md`. A **fact**
  (what the product does changed; there was no fork) amends the PRD. The one-question diagnostic:
  *could a competent stranger, reading only the PRD, arrive at a different answer and be reasonable?*
  Yes → fork. No → fact. Where a fork **constrains** a requirement it gets both — the ruling in the
  register, the PRD **citing the id** — and **never the text in both places**, because the second copy
  is the one that drifts. The rule is stated once, in
  [`templates/DECISIONS.skeleton.md`](templates/DECISIONS.skeleton.md) § *Which decisions live HERE*;
  `MANUAL.md` § Execution discipline item 6, `.claude/roles/pm.md`, `.claude/templates/PRD.template.md`,
  `.claude/templates/ISSUE.template.md` and `requirements/README.md` point at it rather than restate it.

  **2. Citations are now checked.** `check-board.sh` gains arm **`[l]`** — `contracts/drift-report.md`
  § 2's declared-reference-integrity invariant. It reports two findings separately: a citation that
  resolves to **no entry**, and a citation of a **retired** id. **It DECIDES the verdict** (it is not
  advisory and carries no `reports only` token), so a dangling citation holds a release gate shut
  wherever your ritual matches the board verdict. That consequence was chosen deliberately: an advisory
  finding is something a seat must decide whether to chase on every run, and a decision-to-chase is a
  cost paid forever, where a deciding check is answered once and then quiet.

  **WHAT YOU MUST DO — and the good news is that nothing forces it on a timetable.**

  - **If your PRDs' Decision Logs are empty, you owe nothing.** Start citing when you next rule.
  - **If a Decision Log holds entries, migrate it — per entry, by hand.** Apply the diagnostic to each:
    promote a **fork** to a `D-NN` in `requirements/DECISIONS.md` and replace the entry with a
    citation; leave a **fact** as an amendment to the PRD body and delete the log line. **This cannot
    be scripted** — the diagnostic is the whole point, and no instrument can apply it.
  - **Migration is NOT gate-forced.** Arm `[l]` finds **dangling** citations, never un-promoted
    entries, so an unmigrated project is not reddened — it is simply not yet getting the benefit. The
    only way to go red is to *write* a citation whose id does not exist or has been retired.
  - **The citation marker is `[decision: D-NN]`, and it is format law.** It is **anchored** on purpose:
    a bare `D-NN` cannot be told apart from prose *about* a ruling, so a card discussing a retired id
    would be misread as citing it. Only text carrying the marker is read as a citation.
  - **If you cite the register from somewhere other than a PRD or an issue card, declare it.** Arm
    `[l]` reads `CITATION_SURFACES` at the top of `check-board.sh` — a declared list, not a tree walk.
    Each record is `<dir>|<filename pattern>|<what it is>`, resolved with `find` rather than a shell
    glob — without `globstar` a `progress/**/*.md` glob collapses to one level and silently misses
    every subtask card while still reporting the surface covered. It ships with two records:
    `requirements|PRD-*.md` and `progress|*.md`. A surface you do not declare is not
    checked; a declared one that is absent SKIPS with its reason rather than passing.
  - **`scripts/` is deliberately not a surface** and you should not add it: scripts carry ids in
    comments and test fixtures, which are mentions rather than citations.

- **If you run a DURATION watchdog, the run that armed it must now retire it — and if your close
  ritual is a list of handles, check whether it can.** `process/contracts/liveness-watchdog.md`
  § 2 armed a duration watchdog
  at launch and **said nothing anywhere about the end of that run**; the word *disarmed* appeared
  in the sheet only in § 1a's ABSENCE column, where it is correct by design. § 2 now carries the
  paired invariant, § 1a a `retired` row, § 3 a refusal, and § 5 the enumeration on both sides of
  the interface. `MANUAL.md` § Execution discipline item 4(i) gains the matching clause.

  **This binds the DURATION half only.** The ABSENCE watchdog is still *armed once, and never
  disarmed* — its subject is the project, which has no end, so it has no ending act to be retired
  by. Nothing about the absence half changed.

  **The failure this closes is not forgetfulness — it is shape.** A close ritual is normally a list
  of handles: pids, session directories, process names. **A scheduled wake-up has none of those**,
  so it was never eligible for a list of that shape — which is why care with the list is not the
  fix, and enumerating what was armed is.
  Measured here: a coordinated run's own recurring wake-up fired eleven and a half minutes after
  that run's own close. That one was harmless. The previous run's strays were not — two samplers
  still running **six days** after its close, both pointed at deleted paths, one appending rows to
  a tracked file every five minutes, and clearing them became the next run's blocking precondition.

  **What you must do,** once, in your own tree:

  1. **Write down what a run of yours arms** — every watcher, sampler, alarm and **scheduled
     wake-up or timer**, each beside the act that retires it. That list is the fix; the rest is
     bookkeeping.
  2. **Make your close ritual walk that enumeration**, rather than the handles it happens to hold.
  3. **Confirm by reading the scheduler back.** If your close check is a process listing, it
     **cannot see a wake-up** — *nothing in `ps`* is a reading about processes, not an answer about
     arms. The read-back is the same gesture arming it already made.
  4. **Check for strays from runs you have already closed.** This is the one that costs something
     today: anything armed before you adopt this was never retired by anybody.

  **Walking an empty enumeration is a normal close and must complete without error.** A retirement
  step that failed on a run that armed nothing would make every clean close look broken, which is
  how a step gets skipped.

  **We have not measured what this costs you.** The chore is listed here because the kit's own
  MAJOR rule places a changed contract invariant under Action required, not because anyone has sized
  it against a real adopter tree. If your runs arm nothing but processes you already kill by name,
  step 1 is the whole of it.

### Added

- **Progress records — `scripts/lib/progress-record.sh` and `process/contracts/progress-record.md`.**
  Shipped scripts already announced their phases to stdout, in three different shapes, and **nowhere
  a reader could open once the terminal had scrolled**. There is now one record shape, one place,
  and it is **transient by construction**: `.progress-records/` (gitignored, one file per UTC day),
  records expiring on a short TTL swept as a side effect of writing. *Nobody should ever have to dig
  through old logs for anything* — durable insight stays in reports, the card's Activity log and
  your change files.

  **Four required fields — timestamp, actor, class, description — and everything else is an
  OPTIONAL FIELD, never a different payload.** A reader that understands only those four reads every
  record. That is the invariant worth knowing if you write your own producer or your own reader: a
  format with a fork in the middle has to be learned twice.

  **NOTHING IS REQUIRED OF YOU, AND THIS IS NOT UNDER Action required BECAUSE IT CANNOT BREAK YOU.**
  It is never a gate and never a dependency: no gate's verdict, no script's exit status and no
  script's output changes because a record was or was not written, and deleting
  `scripts/lib/progress-record.sh` outright leaves every converted script byte-identical in stdout,
  stderr and exit status. That is measured by ablation in the self-test harness, not asserted. **If
  you never look at `.progress-records/`, nothing about your project changes** — though you may want
  the ignore rule, which the shipped `.gitignore` carries.

  **No role gains a reporting obligation.** The role-side record is written by `move-issue.sh`,
  which was already handed the hat and the id as arguments — so attribution is assigned by the
  caller rather than reported by the agent.

  **Two producers are converted on purpose, and the rest of the population is deliberately left
  alone**: `scripts/verify.sh` (per-gate start and outcome, plus one run summary — its summary
  block is unchanged, since roles quote that block into reviews) and `scripts/move-issue.sh` (the
  board transition, recorded after the push and never before). If you want to convert more, the
  contract sheet's § 5a carries the derivation commands rather than a list to trust.

- **The progress record's `actor` column now has a DECLARED SHAPE, and a run id you can group by —
  `process/contracts/progress-record.md` § 5b.** Three of the four required columns were declared
  well enough to filter on; `actor` was not — `<role>:<issue-id>` was a convention, so anything a
  caller typed was equally acceptable and a reader filtering by agent was matching whatever each
  call site happened to say. It is now two declared kinds: the role side, `<role>` or
  `<role>:<issue-id>`, and the script side, `<name>.sh`.

  **The role vocabulary is DERIVED FROM YOUR OWN `scripts/githooks/commit-msg`, never from a list
  in the kit.** If you narrowed `ROLE_PREFIXES` on adoption, this column narrowed with it and there
  is nothing to re-type. The match is case-sensitive, exactly as your commit-msg hook's is, so one
  seat cannot end up spelled two ways in the same column.

  **A run/session id rides as a declared EXTRA rather than a fifth column.** Set
  `KIT_PROGRESS_RUN` and every record that process writes carries `run=<id>`, so an orchestrator
  and the subagents it spawned can be collected with one grep across a day's records — and across
  the two day files a run spanning midnight lands in. Unset or empty writes **no key at all**, and
  a `run=` passed as an explicit argument beats the environment, which is how a caller changes the
  id on the fly. **Its propagation is yours to arrange:** a subagent spawned with a cleared
  environment writes records with no `run=` and says nothing about it — no writer can tell that
  apart from "no run in scope", so the dispatching site owns passing it on. Stated as a limit
  rather than left implied.

  **NOT UNDER Action required, and the reason is the design rather than a judgement call.** An
  actor outside the shape **still writes** — normalised to `unknown` with the offered value
  preserved in `declared-actor=`, exactly as an unrecognised class has always been carried in
  `declared-class=`. Nothing refuses, nothing is dropped, and no exit status changes, so no script
  you run starts failing. A typo becomes *visible* instead of silently corrupting the filter.

- **`.claude/skills/orchestrate/SKILL.md` § Dispatch attribution** — what a watcher can read while a
  run is still in flight, and **nothing in it is load-bearing**: omit any of it and the run is
  unaffected, so there is nothing to migrate and nothing that breaks.

  **Attribution is assigned by the dispatcher, never reported by the agent** — an agent that never
  says which issue it is on cannot misreport it. The section's numbered clauses are the list, and each
  has to pay off with nothing watching: **a `<verb>:<subject>` label on every dispatch**, where the verb names the seat
  *and the round* (`dev`, `qa`, `dev-fix`, `qa2`, `park-qa` — the shape the shipped runners in
  `.claude/workflows/` already pass, now written down rather than improvised) and the subject is one
  of three kinds — a tracked id, an artifact path, or **a question**; **phases declared before the
  first dispatch** rather than counted afterwards; **five lifecycle states** where `failed` and
  `abandoned` are deliberately distinct, because both are "not running" and conflating them is how a
  real failure reads as a tidy-up; **position reported as a step in a published sequence, never as a
  percentage**; a **staleness threshold that is the project's seam, not a kit constant**, the same
  refusal `scripts/notify/stall.sh` already makes; and the convention that **a script names its steps
  as it begins them**, in whatever shape that script already uses.

  **The `ask:` lane is the new kind.** A leg dispatched to *answer* something — derive a population,
  take a measurement, return a verdict on a claim — produces an answer, not a diff, and is **done when
  the question is answered, not when a file changes**. Dispatching one as a `dev` leg mis-states its
  definition of done and gets it graded against a diff it was never going to produce.

  **The five states are not a second outcome vocabulary.** They are lifecycle *positions*; the
  RUN-OUTCOME list in `process/MANUAL.md` remains the sole authoring site for how a finished leg
  ended, and the new section says so where it could be misread.

  A scoped pointer was added to `.claude/roles/orchestrator.md` § Attribution, which until now
  described only the post-hoc `[Dev]`/`[QA]` commit trail and said nothing about a leg still running.

- **`process/doctrine/generality.md`** — a new doctrine sheet: **when one consumer's request may
  become everyone's rule.** It governs the moment a request arrives from someone who uses what you
  ship and you are deciding whether to change **the shipped thing** because of it.

  Four questions, and the second carries the weight: **would the opposite request be equally
  reasonable from a different consumer? If yes it is a SETTING, not a rule** — and the answer to a
  setting is a **declared seam with a default**, never a change to shipped behaviour. The sheet
  requires you to *name* the consumer who would want the opposite, because *"someone might disagree"*
  is available about every rule ever written and therefore refuses nothing. The other three: is the
  evidence one consumer or several (the weakest, and it sets the burden of proof rather than deciding
  the outcome); does the argument survive the donor being **anonymous**; and **what would falsify it**.
  Two further clauses: a **held** request is recorded with the observable event that would release it,
  and none of this may be **wired as a gate** — no check in your repository knows what a different
  consumer would want.

  **The counter-case has equal weight and is stated before § A**: over-applying this produces a
  product that learns nothing. **The test is not *how many consumers* — it is *does the argument need
  this consumer*.** A reviewer who reads the sheet as *"one consumer means no"* is reading it wrong.

  **Nothing you run changes, and there is no new gate.** § B is a fill-in table for your own project —
  who your consumers are, where a disposition is recorded, what a seam looks like in your tree — and
  the sheet tells you to delete § B wholesale if your project ships to nobody. Its § C states its own
  evidence base, which is thin and says so; expect the sheet to be tuned as more consumers arrive.
- **`doctrine/instruments.md` § A.1 — a reporting instrument's control must execute on EVERY run and
  appear in its own output.** § A.2 already asks every green to owe an ablation, and
  `contracts/self-test-harness.md` § 2 says where that ablation lives. Both bind a **guard** —
  something that can go red. A **reporter** always exits 0 and its output is prose a person reads, so
  there is no red to ablate and the only place a control can be read is the line the reader is
  already looking at. The shape: ask, on every run, a question whose answer cannot legitimately be
  empty, and print it beside the verdict; if it comes back empty, report the verdict as
  `n/a-control-failed` rather than as a zero. **The unit is the PREDICATE, not the file** — an arming
  record kept per file will credit a later-written predicate with a control taken for a different
  one, so re-arming is owed when an instrument meets a new subject, new paths, or gains a new
  feature. **Nothing refuses**: this is doctrine, and the reason is
  `contracts/self-test-harness.md` § 6's — a gate whose cost is a wall gets disabled, and a disabled
  gate reads as armed.
- **Two cross-references that were owed.** § A.2 now points at
  `contracts/self-test-harness.md` § 2's *ablation is an artifact* invariant, and § A.8 at its § 6
  ruling that **a check that is mechanically decidable may be a gate; a check that is heuristic must
  be advisory, and must publish its own precision.** The relationship was documented from the
  contract end only; both ends are now wired.
- **The self-test now DRIVES every exit code a shipped program publishes, and the set of programs it
  checks is derived from the manifest rather than typed.** A program whose header declares a table of
  two or more exit codes starting at `0` is telling every caller to **branch** on them, and until now
  nothing drove one — an assertion that a run merely "failed" collapses exactly what a table exists to
  distinguish. `scripts/test/run.sh`'s new `case_declared_exit_codes_are_driven` derives that
  population, drives **both** the programs it finds through every code each declares, and **names any
  member it does not drive, with its codes**, in its own result line — so the next program to publish
  a table appears there rather than going quiet. **The two subjects, and the defect each guards:**

  - `scripts/notify/stall.sh` — moving / STALLED / UNKNOWN / usage error. An unreadable remote must
    report UNKNOWN and never STALLED: a watchdog that confuses *"nothing moved"* with *"I could not
    look"* raises an alarm on every network hiccup, and the operator who mutes it has muted the real
    one too. The case also proves the watchdog cannot be simplified into a local `git rev-parse`: a
    backdated checked-out tip beside a fresh branch nobody checked out must still read as *moving*.
  - `scripts/finish-pr.sh` — the same shape with a **mutated trunk** behind it instead of a muted
    alarm. Its `1` says *nothing landed, safe to re-run* and its `3` says **LANDED, do NOT re-run**:
    opposite instructions, not degrees. A caller that collapses `3` into `1` re-runs a landing that
    already happened. The `3` arm plants the failure in the **tree** rather than the program — a
    trunk with no `progress/qa_complete/` column — so the gate, the squash, the push and the branch
    retirement all happen for real and only the board advance breaks; it then asserts that the
    change IS on the trunk and the card IS still in `dev_complete/`, rather than asserting the
    number alone.

  **No action required.** If you have edited either program, this case will now tell you: a code
  added to ITS table with no arm driving it reddens, and so does a change that collapses two of its
  answers into one. **The codes are compared per program, never pooled** — both declare `0 1 2 3`
  and their `3`s mean opposite things. **For a program the case only DISCLOSES, the effect is
  different and worth knowing:** add a code to such a program's table and the result line simply
  grows to name it — the run stays green, because disclosure is not a gate. `scripts/test/run.sh` is
  not wired into `scripts/verify.sh` and remains an on-demand tool.
### Changed

- **`process/doctrine/generality.md` § C states its evidence base correctly.** It said the content
  half of the cross-consumer question rested on one consumer's request; the second consumer's request
  existed and was committed, so the population is two and the two do not overlap. **The sheet's
  conclusion is unchanged and deliberately so** — the four questions remain *reasoned rather than
  measured*, because two requests landing on two different surfaces are a population, not a reversal,
  and no question has yet had to separate two consumers who disagree. **Nothing to do:** no rule
  changed, only the paragraph that says how well evidenced the rules are.

- **A declaration in this kit now says which program reads it — or says that none does.** Six
  documents and one guard changed, and the shape is the same in each: a rule that stated a format,
  a marker or a shape named nothing that reads it, so it read exactly like an enforced rule while
  being kept only by hand. **What this changes for you is what you can trust a document to mean**,
  and in two places it changes what your own board report says.
  - **`contracts/drift-report.md` gains two entries and a posture.** Where your project keeps a
    deferred-work queue whose rows name items, the report states which rows claim to be open against
    items that have already landed — *conditional on your keeping such a queue, and it reports only,
    never changing the verdict*. **A project with no deferral queue owes this reading nothing.** The
    dependency-symmetry entry gains a destination: an advisory finding your session does not fix goes
    to that queue, which is **an obligation on the reader and not on the check** — the check is
    unchanged and still never decides. And invariant 3 now says that where the running log is bounded
    in more than one way, each reading declares its own posture: in the shipped implementation the
    current section decides and the whole file reports only.
  - **The board report's register reading stopped saying "nothing to check yet" about a populated
    register.** If your register's entry headings have drifted off the declared `### D-NN` shape —
    headings one level deeper, or the register rewritten as a table — the report previously printed
    `0 entry headings (nothing to check yet)`, which is what it also prints for an empty register.
    **The two are now distinguished, and the drifted case is a finding that sets the verdict.** *You
    may see a new warning on a register that has been quietly unread.* One shape remains invisible
    and is now named in the report's own output: an id written without its declared separator —
    `D01` where the shape says `D-01` — carries neither the heading mark nor the id shape.
  - **`requirements/DECISIONS.md`, `dev/downtime-queue.md` and `dev/README.md` now name their
    readers**; the two agent definitions that cited "the ladder" by nickname now cite its path; and
    `EXTRACTION.md`'s marker register states that **no program reads it**, with the reason, rather
    than leaving a reader to infer one from its two read siblings.
  - **`doctrine/instruments.md` § A.13 states the rule**: *readerless is fine; undeclared readerless
    is not.* Its numbering is deliberate and its section is named in the Part One seam's exception
    list, so a guard author told to "stop at this line" is still sent to it.
  **No Action required.** Nothing starts refusing, no file moved, no command or flag changed. The
  two behaviour changes are a new advisory reading that needs a queue you may not keep, and a
  register warning that fires only where a register had drifted off its own declared shape.

- **The progress-record library's worked example no longer splits its own extras field, and the
  contract now states the caller's obligation.** The header's format example reads `step=13/13`
  where it read `step=13 of 13`. **This matters to you if you copied that line**, because extras are
  read back by splitting the field on spaces: `step=13 of 13` reaches a reader as the key `step=13`
  followed by two bare tokens `of` and `13`, so the one worked example the file offered was an extra
  that did not survive being read back.

  **The rule behind it is now written down** in `process/contracts/progress-record.md`
  § Reserved extra keys: **an extra's VALUE is one token, and that is YOUR obligation as the caller
  — the writer carries it verbatim rather than repairing it.**

  **Nothing enforces this, deliberately, and you should know that rather than discover it.** The
  library will not normalise an extra you pass, and it will not refuse one. It cannot: a value you
  typed is yours, and a writer that repaired it would be rewriting your data — the same overreach
  the actor validator already refuses one column over. So **a spaced extra still writes, and still
  splits the field when a reader tokenises it.** If you pass extras with spaces in their values
  today, they keep working exactly as before and nothing will tell you they are splitting.

  **To do:** nothing is required. If you want the property, join the value yourself — `13/13`,
  `13_of_13`, anything without a space.

- **`scripts/test/run.sh` is single-instance per machine, and its header now says so — run one copy
  at a time.** Two concurrent runs may collide in the sandbox **even against separate trees and
  separate bare remotes**, which is the configuration in which it was seen: of two runs started in
  parallel, one finished normally and the other aborted mid-suite with a FIXTURE FAILURE naming a
  sandbox file that did not exist. Re-run alone in the same tree, that run completed normally — the
  tree was not the cause. **This matters to you if you parallelise**, from two terminals or a CI
  matrix that runs the harness in more than one job at once.

  **Nothing to do, and this is documentation rather than a fix.** The cause is **not derived** — it
  was observed once, on one machine, and the candidate explanations are read from the harness's
  source, not measured. The failure direction is the safe one: the run that failed **aborted loudly**
  naming the missing file rather than reporting a green it had not earned, which is why this is
  written down instead of mechanised. **What it costs is attribution, not correctness** — meeting
  that red with nothing saying the harness is single-instance, the natural response is to re-run,
  which makes it vanish and reads as a flake. The header paragraph exists so the next reader
  attributes it in one step. **It is not what `case_isolation` asserts**: that case proves this
  harness does not disturb the repository it runs in, the opposite direction from one instance
  colliding with another.

- **The Dev → QA handoff now says which lane QA writes in: read and gate on the branch, write on
  the trunk.** Step 3 sends QA to the work branch, and the review evidence it records goes into the
  issue file's Activity log — but the board mover has already edited that same card on the trunk,
  so a reviewer who followed both instructions literally appended to the *branch's* copy and
  `finish-pr.sh` refused the landing with a squash conflict on the card. Both instructions were
  correct in isolation; the issue file is metadata, and metadata commits to the trunk. § The Dev →
  QA handoff step 3 now states the read/write split with its reason, § Landing code names the lane,
  and `.claude/roles/qa.md` carries the same sentence for the reviewer who reads only the role doc.
  `finish-pr.sh`'s conflict message now names this as the likely cause when the conflicted file is
  the issue card, instead of only asking whether the trunk has advanced.
  **No action required:** nothing in your tree must change, and a project that hit this has already
  worked around it. Nothing was ever lost — the gate refuses before any destructive step.
- **`process/doctrine/negative-claims.md` § A.5 now says WHEN it binds — and this supersedes
  0.5.0's *“nothing new to wire”*.** The route law shipped in 0.5.0 stating what a claim owes but
  never when, so read as written it applied to every sentence — which meant it was applied where it
  was convenient and skipped where it mattered. That is measured, not predicted, and it was measured
  on the party that wrote the rule.

  **The amendment splits one obligation into two, and only the expensive half gets a trigger.**
  Naming the route stays **universal**: it costs three words and the route is already known when you
  write the sentence. Taking a **second route** is owed only where a claim is **load-bearing** —
  *someone will act on it, or its being wrong changes a decision* — and the sorting question is one
  line: **if this is wrong, what happens?** If the answer is nothing, the claim is exempt, **and the
  exemption is the point**: a rule demanded of every sentence is obeyed in none. The word
  *load-bearing* was already used in § A.5's second-reader clause and never defined; it is defined
  now, in the clause that needs it.

  **A second reading is still not a second route** — that half is unchanged. What a second route
  looks like is now tabulated by claim shape: a **count** is re-derived a second way, a **guard** is
  shown both firing AND staying quiet (*a guard only ever seen refusing has not been shown to
  permit*), a **diagnosis** is reproduced with the suspected cause removed, a **negative** is retried
  through a different entry point.

  **The rule is still not mechanised**, deliberately and for the reason § A.5 already gives: scope is
  a paragraph property, so a grep over a real corpus returns mostly ordinary usage. The trigger does
  something a restatement cannot — it **narrows the population** the rule is demanded of, which is
  what makes an unmechanised convention cheap enough to actually run. It has not been measured in
  use, and § A.5 says so in its own *What this trigger does not do*.

#### Action required

- **Wire § A.5 into your two role documents, one line each — 0.5.0 told you that you did not have to,
  and that was wrong.** The reasoning then was that your reviewers *inherit* § A.5 by reading the
  sheet their checklist already points at. **That is the exact defect § A.5 itself names in
  *Disclosure elsewhere is not scope*: a rule stated somewhere the reader does not open while acting
  is not wired.** The kit's own `.claude/roles/dev.md` (*Definition of Done*) and
  `.claude/roles/qa.md` (cross-cut checks) now carry that line; if you took those files on day one
  and have edited them since, copy the two bullets across by hand — they are additions, and they
  change no bullet you already have.

- **`process/doctrine/generality.md` § C — the sheet's own stated evidence base was wrong, and is
  corrected.** § C exists so a reader can weigh how well-supported the four questions in § A are, and
  it said the CONTENT half was **n=1**: *"The second consumer did not produce a request before its
  run ended."* **Both halves of that were false.** Both consumers produced exactly one request each,
  and the population is **two**. The two land on **different surfaces** — one a deterministic defect
  in an initializer, the other a contradiction between two steps of a role handoff — which is what
  makes them a genuine cross-consumer population rather than two instances of one complaint.

  **What the correction does NOT claim, and this matters more than the number.** n=2 does **not**
  make the four questions *measured*, and § C still says they are **reasoned**. Two requests on two
  different surfaces are a *population*, not a *reversal*: no question has yet had to separate two
  consumers who disagree, so A.2's flip-flop test remains untested — for that the two consumers must
  meet the **same** surface and resolve it differently, which these two do not. Replacing an
  overclaim with a different overclaim would be the same defect the correction is fixing.

  **To do: nothing** — no rule in § A changed, only the statement of how well-supported they are. If
  you have quoted § C's *n=1* anywhere in your own process notes as a reason to discount the sheet,
  that reason no longer holds; the sheet's evidence base is thin, which it still says, but it is not
  as thin as it said.

### Fixed

- **A run id, class or actor with a leading or trailing underscore is no longer silently shortened
  in a progress record.** The single-token cleaner behind `run=`, `declared-class=` and
  `declared-actor=` collapsed whitespace to `_` and then trimmed a leading or trailing `_` — and
  after the substitution its own separator and one you typed are the same byte, so the trim removed
  both. A value that was already one token came back rewritten.

  **This is reachable from a stock tree through `KIT_PROGRESS_RUN`, which is a seam YOU set.** If
  you exported a run id that starts or ends with `_`, the records did not carry it:

  ```
  KIT_PROGRESS_RUN=_run_   wrote  run=run
  KIT_PROGRESS_RUN=run_    wrote  run=run
  KIT_PROGRESS_RUN=_run    wrote  run=run
  KIT_PROGRESS_RUN=_       wrote  run=<empty>
  ```

  Three distinct ids collapsed onto one another **and** onto any unrelated run genuinely called
  `run`, so a grep for the id you exported collected nothing while a grep for `run=run`
  over-collected. **The failure shape is the reason this is worth a line:** the record is
  well-formed and wrong. It parses, it reads as an answer, and nothing in it shows the id was
  shortened — unlike a split field, which any tokenising reader trips on immediately.

  A value that is already one token is now carried **byte for byte**. Whitespace is still collapsed
  to `_` and a value that is entirely whitespace still reaches the `<empty>` placeholder; only the
  literal underscores you typed survive that they did not before.

  **To do: nothing, and there is nothing you can do about records already written.** Past records
  cannot be recovered — the original id is not in them. Records written from the next release
  onward carry the id you exported. **If you worked around this by avoiding underscores at the
  edges of your run ids, you no longer need to**, and ids you already chose keep working unchanged.

- **`kit-init.sh --project-name` now REFUSES a name it cannot stamp, instead of writing a
  `scripts/config.sh` that no script can source.** The name is written into `config.sh` as the
  default of `PROJECT_NAME="${PROJECT_NAME:-<your name>}"`, and bash still processes quoting inside
  the `word` of a `${VAR:-word}` even when the whole expansion is double-quoted. **An apostrophe
  therefore opened a single-quoted string that ran to end of file**, leaving `config.sh` unparseable
  — so every script that sources it died, and the initializer's own self-check reported only
  `✗ could not mint …` with no cause. A real project hit this on its first command with an ordinary
  name — an apostrophe in a place name is enough, and they are common in the charity and hospitality
  sectors.

  The refused set was **derived by execution** rather than listed from memory — every printable ASCII
  character stamped through the real substitution, then both parsed and sourced back. **Nine
  characters fail**, in three classes that look nothing alike: `'`, `"`, `` ` `` and an embedded
  newline leave the file **unsourceable**, so every script that reads it dies; `$`, `\`, `&` and `}`
  let it source and **silently change the value you asked for** — `$` expands at source time (so the
  same file means different things to different operators), `&` splices the whole config line into
  the value, `}` closes the expansion early and truncates the name, and `\` is eaten by the
  substitution. **`|` is a third case and the nastiest:** it is the substitution's own delimiter, so
  the substitution **aborts**, `config.sh` keeps the shipped placeholder, and the initializer dies at
  that line **after** the seams before it are already stamped — a half-initialized repository, which
  a second run then refuses with no resume path. Every other printable character round-trips byte for
  byte. The refusal names the character **and its position**, fires at argument-parse time
  before anything is written, and exits 2 — and **it does not rewrite your name for you**: a
  sanitiser is a second parser that fails silently on whatever the first one missed, which is exactly
  what the five silent characters above already demonstrate.

  **Independently, the self-check now replays the failing mint's own output.** It used to discard it,
  so the one line naming the cause was thrown away and the only way forward was to re-run the failing
  command by hand.

  **To do: nothing.** The refusal fires only inside `kit-init.sh`, which a project runs once on day
  one; if you are already initialized you are past the line that broke. **If your project name
  contains one of the nine**, spell it without that character when you initialize — a
  hyphen or a space reads fine — and set the prose spelling you actually want in your role docs and
  templates afterwards, where it is not a shell value.

## [0.5.0] — 2026-09-15

### Action required

- **If a board move ever told you a commit was not on the trunk and advised a cherry-pick, check
  your trunk for a duplicate.** The kanban worktree's landing assertion read the sha it held
  *before* the push, and a push retry rebases — so on every won race the operation that SUCCEEDED
  was the same operation that orphaned the sha being asserted on. The result was **the push failure
  recovery text, which must name the commit that actually landed**, naming one that had been
  replaced: a landing that worked reported as a failure, with a remedy that produces a second copy
  of the same work. The assertion now reads the post-push HEAD, and tells a rebase apart from a
  genuine orphan. **What you must do:** if you followed that advice, `git log --oneline` your trunk
  around that date and drop the duplicate.

- **If you deleted `scripts/notify*` as unused, check whether `stall.sh` went with it.** The
  `DELETE-IF-UNUSED` glob was written as `scripts/notify*`, which matched the whole directory —
  including `notify/stall.sh`, which is **not** a notification channel but the liveness control that
  notices when a board has gone quiet. An adopter who ships no notifications was therefore told, by a
  glob, to **delete if unused — see that row below**, and would have taken the watchdog with the
  adapters. The glob now names the channel adapters only, and `stall.sh` has its own
  **Liveness (KIT)** category. **What you must do:** if `scripts/notify/` is gone from your tree,
  restore `stall.sh` from the zip.

- **The board gains a `progress/declined/` column, and your tree does not have it yet.**
  `declined/` is where a card that was **considered and refused** lives, with the reasoning
  that refused it. A refusal previously had nowhere to go: left in `todo/` it misrepresents
  itself as pending work, and deleted it takes its reasoning with it, so the next person to
  propose the same thing starts from zero and the refutation is paid for twice.

  **Do this once, in your own tree:**

  ```sh
  mkdir -p progress/declined
  touch progress/declined/.gitkeep
  git add progress/declined/.gitkeep
  git commit -m "[PM] Add the progress/declined/ board column"
  ```

  **Until you do, `./setup.sh` warns and names that command**, and a
  `./scripts/move-issue.sh <ID> declined` is the only thing that actually fails. Nothing else
  in your board changes, and no existing card moves.

  **What comes with it, once the directory exists:**

  - **`./scripts/move-issue.sh <ID> declined --role PM --note "…"` is a legal move, and the
    `--note` is REQUIRED there** — exactly as it already is for `blocked/`. *A decline with no
    recorded why is a deletion with extra steps.* The note should carry the **reasoning**, not
    the verdict, so the next person proposing the same thing meets the argument.
  - **`declined/` is terminal and is NOT swept.** `archive.sh` does not touch it. The sweep
    exists to keep the *active* board shallow; this column's whole value is being browsable.
  - **`check-board.sh` gains arm `[k]`, a COUNT of the column and only a count.** It has no
    threshold, it never sets `drift`, and accumulating declined cards can never turn a green
    board red — a recorded refusal is not work left undone. Arm `[a]` **does** read the column
    for folder-vs-Activity drift, because "is this card where its own last Activity entry says
    it is" stays answerable about a refusal, and a hand-move is the one event no other check
    sees.
  - **`STATUS_FOLDERS` gains `declined` in both `check-board.sh` and `kit-init.sh`.** If you
    have local code that re-lists the status folders instead of deriving them from those
    constants, it is now short by one — `EXTRACTION.md` § 2.2 is the table of every shipped
    carrier and what each costs when it is missed.
  - **A fresh `kit-init.sh` creates the column for you.** This item is only for a board that
    already exists.
  - **The PM role owns it.** Killing an issue is PM's call, and PM's session-start board
    listing now includes it.

- **Your commit-msg hook has been letting tool co-author trailers through, and one deleted space
  was all it took.** Rule 2 required a non-alphanumeric character immediately before the tool
  marker. That is a *required character*, not a boundary assertion — so with the marker butted
  straight against the colon there was nothing for it to consume, and the trailer passed.
  Measured on the hook as it shipped, with a valid role-tagged subject so rule 1 could not mask
  the result: `Co-Authored-By: Claude <x@y>` was refused, and **`Co-Authored-By:Claude <x@y>` was
  accepted.**

  **Action required — two things, and the first one takes a minute.**

  1. **Check whether anything already landed through the hole.** The guard only ever
     *under*-refused, so nothing legitimate was ever blocked and no history is corrupt — but a
     trailer may be sitting in your log:

     ```sh
     git log --format='%b' | grep -iE '^[[:space:]]*co-authored-by:[^[:space:]]'
     ```

     That looks for the defeating shape specifically: a `Co-Authored-By:` with no space after the
     colon. Judge the hits yourself — a human contributor can legitimately write one.

  2. **If you have edited rule 2's matcher locally, re-apply the fix there.** The pre-marker
     context must be an *optional group*, so the colon itself can serve as the left boundary:

     ```
     ^[[:space:]]*co-authored-by:(.*[^[:alnum:]])?(${TOOL_TRAILER_MARKERS})([^[:alnum:]]|$)
     ```

     **Keep the trailing `([^[:alnum:]]|$)` required.** It is the only thing stopping the rule
     from refusing a human whose name merely *begins* with a marker's stem — `Claudia Ng` is
     accepted, and there is now a test case that keeps it that way.

- **The `using-superpowers` skill directory is now `using-skills`, and this SUPERSEDES what 0.2.0's
  notes told you.** That release said *"The `using-superpowers` skill directory keeps its name for
  now — renaming it breaks every path that cites it."* **That sentence described what 0.2.0 shipped
  and is left standing there unedited** — a released note is a record of what was true at that
  version, so the repair is this entry rather than a rewrite of history. The *"for now"* has
  expired.

  **Why the name changed:** it was the last place the upstream plugin's product name survived where
  nothing depended on it. The skill's own frontmatter says it *"establishes how to find and use
  skills"* — it is not about skills that are external — and every sibling directory is kebab-case,
  so `using-skills` parallels `using-git-worktrees` and keeps the naming uniform. **The upstream is
  still acknowledged**, unchanged, in `.claude/skills/README.md` § Provenance & licensing and in the
  `brainstorming` companion's page header: a skill whose origin nobody can name is a skill nobody
  can safely update.

  **Do this only if something in YOUR tree names the old path.** The shipped tree is already
  consistent — `.claude/roles/dev.md` and `.claude/skills/README.md` were re-pointed in the same
  change. What is yours to re-point is anything you wrote:

  ```sh
  grep -rn 'using-superpowers' . --exclude-dir=.git
  ```

  Any hit is a path you own — a plan document, a role doc you adapted, a script, a note. Rewrite it
  to `using-skills`. **If that grep is silent, there is nothing to do.**

  **One thing that is NOT a stale path and must not be rewritten:** `~/.config/superpowers/worktrees/`
  in `using-git-worktrees` § Directory Selection is an **external tool's real directory**, which the
  skills *adopt* where it already exists rather than create. Renaming it would send a correct
  instruction looking for a directory nothing makes. The grep above will not show it as a
  `using-superpowers` hit, but a wider search for the word will, and that is the one to leave alone.

  **The self-test now gates this.** The case that refuses the upstream product name where nothing
  depends on it carried a literal carve-out for the old directory name; that carve-out is deleted,
  so the old name re-appearing anywhere in the shipped agent surface is now a FAIL rather than an
  allowance.

### Added

- **Adopter-visible: a new doctrine sheet, `process/doctrine/consumer-output.md` — what a tool's
  output owes a reader who cannot re-measure it.** Every other sheet in `process/doctrine/` addresses
  a reader who can go and check: a maintainer with the tree, a reviewer with the diff, a seat that can
  re-run the guard. **Nothing addressed the person your product hands a report to** — someone with no
  access to the evidence and, usually, no way to tell a measurement from an inference. The
  discriminator is **re-measurability**, and every rule in it follows from that one asymmetry.

  What it asks of a consumer-facing output, in short: a label's scope may not exceed its evidence's
  and **the label itself is where that is said**; what was READ and what was DERIVED are marked **per
  item**, because a wrong inference usually makes the result look *better* and is therefore invisible
  in the aggregate; where every candidate value is wrong in a different direction the tool
  synthesises **none** of them and records the absence as a decision with the event that would
  discharge it; a predicate that is not mechanically decidable hands back a **census that says so in
  its own output**; an inference whose error would leave no trace is **demoted from a decision to a
  proposal**; prefer the decomposed figure the reader can trace over the combined one they must
  trust; and **a limit recorded where the affected party does not look has not been disclosed** —
  placement separates detection from remedy.

  **No Action required, and no gate.** A doctrine sheet is addressed on demand rather than read at
  session start, this change wires no mandatory read, and § B says in the sheet why no guard ships:
  none of its rules is mechanically decidable in general, and a low-precision gate gets disabled
  inside a week — after which a disabled gate reads as armed. **What it costs you** is § B, the
  adapter's fill-in: if your project ships an output to someone who cannot re-measure it, list those
  surfaces and say who the consumer is and what they cannot check. If all your outputs are read by
  people who can re-measure them, § B tells you to delete it and stop.

  Its row is in `process/MANUAL.md`'s doctrine table, and `distribution.md` and `staleness.md` § C
  each gained one line pointing at it — `distribution.md` § A.4's downgrade incident (a healthy
  checkout reporting **UPDATE AVAILABLE** and offering a **downgrade**) is the new sheet's
  refuse-to-synthesise clause failing, at distribution scale.

- **Adopter-visible: three new hard invariants about what an instrument owes before its green means
  anything — and a ruling that NONE of them is a gate.** They landed in the two contract sheets that
  own the instruments they bind, not in `process/doctrine/instruments.md`, because that sheet already
  establishes the *practice* (§ A.2, every green owes an ablation) and what was missing is the
  **disposition**: where the ablation lives, what a case must emit, what a check must probe.

  - **An ablation is an ARTIFACT, not a habit** (`process/contracts/self-test-harness.md` § 2). A
    file another reader can run — not a comment, not prose recording that an ablation was once
    performed, which is indistinguishable to every later reader from one that never happened. The
    point is that an ablation must be **re-askable against a tree that has moved**: the guard is
    still green a year on, and the open question is whether it is green *for the same reason*.
    Where a guard has more than one red, the shape to copy is a **declared expected-red set** that
    refuses on a difference in **either** direction — a declared red gone green means the reason is
    stale and the entry must go.
  - **A case that QUANTIFIES emits its count** (same sheet, § 2), and something *other than the case*
    compares it to a declared number — a case asserting its own count restates its premise. The
    suite-level rule beside it governs the total; this governs a single case whose name promises a
    population, which is where a count goes wrong invisibly, because the suite's total is unaffected
    by a case that claimed three inputs and ran two.
  - **A check about deployed behaviour probes the DEPLOYED ARTIFACT** (`process/contracts/verify-gate.md`
    § 2), never the working copy — resolve it out of the tree and execute it there. Measured on two
    different subjects: a readiness probe that answered *"the command is usable"* by testing the file
    while the running loop held hours-old code, and a liveness check that called a server alive by
    asserting a state file existed, immediately after the documented stop step that never unlinked
    it. Both were correct about what they read and wrong about what they claimed.

  **No Action required, and no gate — the ruling is the point.** The obvious mechanisation (refuse a
  run in which any case lacks a companion ablation) was measured on the kit's own tree and rejected:
  it would refuse every run until a large majority of existing cases acquire one, and **a gate whose
  cost is a wall gets disabled, after which a disabled gate reads as armed** — the very failure the
  invariant exists to prevent. § 6 carries the two commands so you can derive the split on *your*
  tree; no number for it is written in the sheet.

  **The general rule this is an instance of, and it is the part worth carrying away:** *a check that
  is mechanically decidable may be a gate; a check that is heuristic must be advisory, and must
  publish its own precision.* Shipping a heuristic as a gate is the same error as an over-promising
  test name — a claim wider than the predicate — committed by the guard instead of the test. The
  output half is `process/doctrine/consumer-output.md` § A.4, and § 6 links to it.

  **And the limit, stated because pretending otherwise is worse:** no assertion about a number can
  see a **comprehension** defect — the measured case was a report with a fully green suite and
  arithmetically perfect output that showed a reader the amount due twice and never the amount paid.
  **No green from your harness may be read as evidence that your product is usable.**

- **`KIT-DISPOSITION:` — a file can now declare what must HAPPEN to it before day one is done, and
  `scripts/check-board.sh` arm (g) reads it.** `KIT-CLASS:` answers *does this file travel?*; the
  disposition axis in [`process/EXTRACTION.md`](EXTRACTION.md) § The second axis: DISPOSITION answers
  *what has to happen to it* — and until now that axis lived only in a table, while arm (g) carried
  its member lists as **filenames typed into the script**. They are now derived from the files' own
  declarations. **You do not have to do anything**, and nothing changes for a project that leaves the
  shipped markers alone.

  **What it enables, and the exact limit, because the limit matters more than the feature:** arm
  (g)'s REPLACE check considers `CLAUDE.md`, `README.md` and `PROJECT.md`, and now asks each of them
  whether it DECLARES the disposition before testing it. **The declaration filters that candidate
  set; it does not widen it.** So re-dispositioning one of those three is followed correctly — but
  **a file of your own with a new name is NOT scanned**, even if you declare it. Widening that scan
  is a separate decision about how much of your tree the arm should read. Declare the disposition in
  the same comment block as the file's `KIT-CLASS:` marker:

  ```
  # KIT-CLASS: MIXED — <why it travels>
  # KIT-DISPOSITION: FILL — <what is not done until it is done>
  ```

  **Two behaviours to know about before you rely on it.** First, **the declaration selects the
  population; it does not supply the test.** For `REPLACE` the test is still the body's
  `BOOTSTRAP-SCAFFOLDING` line, because the marker is stripped by the very replacement it would be
  asking for — so a `REPLACE` file needs both. For `FILL`, arm (g)'s angle-bracket test is a markdown
  test: declaring `FILL` on a shell file is correct and useful, but that arm still will not measure
  it, and says so. Second, **an arm with an empty derived population now prints `(skipped — nothing
  was checked, which is not a pass)` rather than a tick** — so if you delete a shipped declaration,
  you get a visible skip instead of a silent green.

  **Only `FILL` and `REPLACE` members ship marked**, because those are the two rows arm (g) actually
  measures. `KEEP`, `STAMP`, `SEED` and `DELETE-IF-UNUSED` files are unmarked — **an absent marker
  means *not yet declared*, never *nothing to do***; the table in `EXTRACTION.md` is still the full
  list. Derive what carries one with

  ```
  grep -rlE '^(#|<!--|//|--)[[:space:]]*KIT-DISPOSITION:' . \
    | while read -r f; do head -20 "$f" | grep -qE '^(#|<!--|//|--)[[:space:]]*KIT-DISPOSITION:' \
    && printf '%s\n' "$f"; done
  ```

  rather than assuming the set. **The head window is load-bearing and is the same trap
  `KIT-CLASS:` has:** a bare recursive grep also returns the file that DOCUMENTS the convention,
  because its worked example is a line of the same shape further down. A declarant carries the
  marker in its header; a description of the marker does not.

### Changed

- **`--help` now answers on a tree whose `scripts/config.sh` is missing, and so does a bad flag.**
  Six tools — `archive.sh`, `new-bug.sh`, `new-issue.sh`, `new-prd.sh`, `new-refactor.sh`,
  `subtask.sh` — answered a usage request with the seam refusal instead of their usage text, which
  is the one thing [`contracts/issue-creation.md`](contracts/issue-creation.md) § 3 says can never
  be refused, in the state where you most need the text. They now answer it. **Nothing a correct
  tree does changes**: with `config.sh` in place every one of them prints exactly what it printed
  before, and the seam still REFUSES every operation and mints nothing.

  - **Where the help text names your issue or PRD prefix and the seam cannot be read**, it now
    prints the seam's location — `<ISSUE_PREFIX from scripts/config.sh>` — and never the kit's
    shipped default. A prefix that is right about the kit and wrong about your project reads as
    authoritative and you cannot falsify it from where you sit.
  - **An unrecognised option on a seamless tree now exits 2 for the four creators**, the status
    § 3 fixes for it, where all six previously exited 1 carrying the seam refusal. `archive.sh` and
    `subtask.sh` still exit 1 there, and deliberately: their leading token may legally be an option
    or a subcommand, so deciding this above the seam would need a second copy of their option list —
    the defect § 3's own scar records. If you branch on these statuses, that split is the contract.
  - **Still refused on a seamless tree: `--help` in a LATER position** (`new-issue.sh my-slug
    --help`). Ask for it first, or restore the seam. The kit's self-test states this as a known
    hole rather than asserting it away.

- **Nothing you must do; several things you read are now true that were not.** Shipped statements
  that contradicted the code beside them, prose passages carrying a census number the kit's own rule
  bans, and derivations the kit *offers you to run* that returned something other than what their
  sentence claimed. They are fixed. *(No count is written here on purpose: this section is
  `[Unreleased]` and still moving, and a total stated over a population that keeps growing is the
  very defect the third item names.)* The ones worth knowing about:

  - **`PROJECT.md`'s gates table no longer invites you to rename two things the kit hardcodes.**
    The verify gate and the board mover were presented as adopter-fillable `<e.g. …>` blanks, for
    filenames `finish-pr.sh` invokes by literal name — its own refusal says the executable *"is
    never caller-chosen"*. Both rows now state the fixed name and say what genuinely is yours: the
    gates *inside* `verify.sh`, not its path. **If you renamed either on the strength of that
    table, your landing gate is broken** — check `./scripts/finish-pr.sh --help` and restore the
    shipped names.
  - **`setup.sh` no longer accepts a mistyped flag silently.** It inspected only its first
    argument, so `./setup.sh --kit-only --nonsense` dropped the second token and **exited 0**. It
    now reads every argument: an unrecognised option exits 2, a surplus positional exits 1.
  - **Derivations you may have run and believed.** `EXTRACTION.md`'s recipe for finding the
    pure-pattern doctrine sheets returned very nearly the *inverse* of what its sentence
    described; `scripts/lib/usage.sh` said its own command "returns seven files" when it returns
    eight, and the unlisted eighth is a real header renderer; `contracts/README.md` quoted two
    file counts that were wrong on the tree that shipped them. If you acted on any of these, re-run
    them — they are corrected, and where a number was the problem it has been replaced by the
    command rather than by a fresher number.
  - **`update_vendored.sh` now refuses an unfilled `RELEASE_DOCS` entry** instead of reporting the
    miss in the words reserved for a release that genuinely predates a document. If you vendor
    with it and never filled `<path/to/GUIDE.md>`, you will now get a refusal naming that seam —
    fill it, or delete the entry if you do not vendor a guide.
  - **`_claude/templates/PRD.template.md` had the wrong landing shelf.** `status: completed` said
    stories land in `progress/done/`; they reach `progress/qa_complete/`, and `done/` is reached
    only by a later `archive.sh` sweep. Read literally, a fully delivered PRD would have stayed
    `approved` until someone archived it.
  - **Both workflow runners now hold their model and effort defaults in `CFG`**, where their own
    first line always promised everything project-specific would be. If you run a different
    provisioning ladder you can pass `defaultModel`/`defaultEffort` per run instead of editing
    the file.

- **`process/doctrine/negative-claims.md` gained § A.5, the route law — and it is an obligation on
  your REVIEWS, not only on your findings.** The sheet governed how *wide* a claim may be; § A.5
  governs how it was **obtained**: *a claim is true only of the operand, the route and the moment
  that produced it, and the scope goes inside the sentence the reader acts on.* Six forms — a
  negative names its **route**, a diagnosis the **instances** it was derived from, a count its
  **command**, a report the **layer** it observed, a permission the **question** it was asked, and a
  positive claim about a corpus the **site** it happens at. **The half worth your attention is the
  second-reader clause: two readers on one route is one measurement read twice.** A reviewer's *"I
  agree it cannot be caught"* is itself a negative result obtained by one route, so what a
  load-bearing *cannot* is owed is a second **route**, not a second opinion.

  **Nothing to do on adoption**, and nothing new to wire: the two sites that route a claim past this
  sheet — the implementer role doc's *Definition of Done* and the reviewer role doc's cross-cut
  checks — already point at it, so your reviewers inherit § A.5 by reading the sheet they are
  already sent to. **Nothing enforces it**, deliberately: mechanising the general form over a real
  corpus returns a hit list that is almost entirely ordinary usage, because scope is a paragraph
  property. The one greppable member is the corpus-scoped reassurance — *"unreachable from the
  corpus"* and its kin — which is worth a check on its own terms in your tree:

  ```sh
  grep -rniE 'unreachable (from|through|in) (the |our |this )?corpus' . \
    | grep -v 'doctrine/negative-claims.md'
  ```

  **The second filter is not cosmetic and the reason is the rule itself.** § A.5 quotes the pattern
  in order to name it, so the sheet stating the rule is a hit for its own recipe — run it unfiltered
  and the one result you get is the doctrine telling you to run it. Drop the filter once your own
  tree has a real hit to compare against.

  If you keep a doctrine-sheet index of your own, § A.5 also changes this sheet's one-line summary
  in `process/MANUAL.md`.

- **Two new conventions about what a file MEANS and what a handoff owes when you did not choose to
  stop.** Both are authoring-time habits: neither is a gate, neither changes a command or a path,
  and nothing you already run behaves differently.

  - **`process/doctrine/subagent-control.md` gains § A.14 — *a file that means two things has no
    correct writer*.** When a second consumer starts reading an artifact for a fact it was not built
    to carry, **the fix is a second artifact, not a cleverer query against the first.** A fleet meets
    this before a lone author does, because a file written by one worker and read by another has
    nobody holding both ends: each side is looking at a file that is correct for its own purpose, so
    no review catches the overload. The failure does not look like a bug — two rulings that are each
    correct meet inside one overloaded file and produce a report where **both halves are false and
    neither rule is wrong.** The tempting wrong answer is always available and always cheaper: a
    smarter read of the overloaded file works, and leaves the file meaning two things, so the next
    consumer arrives and the query gets smarter again. **If you keep a notes file, a progress log or
    a status record that a second tool has started deriving something from, that is this section's
    subject.** It carries a pointer to `process/doctrine/instruments.md` § A.6, which owns the same
    defect from the reader's end.
  - **`dev/handoffs/README.md` gains the stop you did NOT choose.** Its § *When to write one* said
    to write at a natural boundary you chose in advance; it now also names **asked to halt, context
    spent, a subordinate terminated**. The two do not conflict: **the chosen boundary is where you
    write a good handoff; the unchosen stop is where you owe a short one regardless.** And § *What
    a handoff must contain* now opens with the question it actually answers — **what do you HOLD
    that the repository does not** — because `git status` cannot see a ruling received in
    conversation, a conclusion reached but unwritten, or what a terminated worker reported before
    it stopped. **A clean tree is not an answer to that question.** The existing standing-rulings
    bullet is unchanged and was widened by a sibling naming the three classes it did not cover.
    **If you have adapted this README, both additions are worth porting by hand** — the trigger is
    the half that is easy to miss, since the section heading (*while sharp, not while failing*)
    reads as advice to skip the handoff at exactly the moment things are going wrong.

- **The role documents were combed for what fires only in a SITUATION, and four skill
  descriptions were rewritten to lead with a trigger.** A role doc is loaded **in full** the
  moment its hat is worn, so a paragraph that fires only when a named situation arises is paid by
  every session in that role and used by almost none of them. The rule applied: *does this fire on
  every session in this role, or only in a situation?* — every-session content stays inline;
  situational content moves to the sheet that owns the situation and leaves a one-line pointer
  naming both. **No rule was dropped and no measured finding was deleted** — where a reason was
  already stated on a doctrine sheet, the role doc now points at it instead of restating it; where
  a finding had no other home it stayed put. `orchestrator.md`, `dev.md`, `pm.md`, `qa.md`,
  `refactorer.md` and `architect.md` all changed shape; the § headings and the workflows'
  numbered steps did not move. **The orchestrator's pause law gained something on the way**: the
  ordering rule from `doctrine/orchestration.md` § A.5's amendment — *when the next leg is
  determined, the dispatch call PRECEDES the status* — which the role doc had never carried.
  **If you have adapted any role doc, the diff is worth reading rather than porting wholesale**:
  what changed is placement, so the interesting question is whether your local additions are
  every-session or situational by the same test.

- **Two templates gained a fill-in checklist whose last item deletes the checklist**, and the
  card templates now say that their header comments are GUIDANCE. A template's commentary is
  copied into a live project, where it becomes a **permanent per-session cost**:
  `CLAUDE-adapter.template.md` becomes `CLAUDE.md`, which is loaded on every session forever, and
  a minted issue card is re-read by Dev, QA and the orchestrator every time it moves. Both files
  already said *"delete the HTML comments"* in a HOW-TO-USE comment at the top; neither gave the
  author anything to tick at the end, which is where the pack templates already put the rule
  (*every `>` blockquote line deleted*). So `CLAUDE-adapter.template.md` and
  `DECISIONS.skeleton.md` now end with a **FILL-IN CHECKLIST** block that closes with an item
  deleting itself, and `.claude/templates/`'s five card templates state in their own link-base
  header that the block is guidance addressed to whoever maintains the template — **keep its shape
  in the template, delete it from the minted card.** *Measured while filing this: the mint-time
  re-head (`scripts/lib/card-head.sh`) already strips the `KIT-CLASS:` block and writes a live-card
  head in its place, but it does NOT strip the link-base block — so that comment currently lands in
  every minted card in every adopting project.* Deleting it by hand at mint time is correct today;
  stripping it mechanically is a change to the re-head, which this entry does not make.

- **Four skill descriptions now open with a testable condition instead of a capability.** Only a
  skill's frontmatter `description` is always in context; the body is loaded when the skill is
  invoked. That makes a vague description expensive in a way a long body is not — and it makes an
  instruction to load *always* a defeat of the mechanism. `brainstorming`'s description said
  *"You MUST use this before any creative work"*, which is an order to load rather than a
  condition; it now names the condition (HOW is not yet settled — architectural forks,
  cross-cutting effects, genuine design space) and states that the skill gates implementation
  until a design is approved, which is what its HARD-GATE actually does. `orchestrate`,
  `product-brainstorming` and `write-spec` led with a sentence describing what they do and
  reached their trigger only afterwards; all three now lead with the trigger. **No skill body
  changed and nothing was deleted.** If you have edited these descriptions locally, the rule to
  apply is: the condition first, and short — the description is the part that is always loaded.

- **That description rule now has a home in the shipped tree, with one stated exception.** The rule
  above shipped only as a release note, which records what changed in a release and is not where a
  reader looking at the skills directory would find a standing convention.
  `.claude/skills/README.md` § How skills work gains **What a description costs, and the one rule it
  must meet**, beside the mechanism it depends on. **The exception is `using-skills` and it is
  scoped by argument, not by listing:** its description opens *"Use when starting any conversation"*,
  which names no condition — and that is honest for the one skill whose SUBJECT IS SKILL USE ITSELF,
  because a session cannot test which skills apply before it knows how to find and invoke them. A
  second claimant must show a session could not reach it without having read it first. **Its
  frontmatter was deliberately NOT rewritten**, for a second reason worth porting: the skill is
  vendored, and § Provenance & licensing warns that a re-copy restoring an upstream wording *"has
  not updated the skill, it has re-narrowed it"* — a local rewrite of a vendored description is that
  same drift, paid again at every re-fetch. **And the section states plainly that this rule is a
  convention with a reader, not a gate**, with a recipe that shows why the obvious proxy fails: the
  descriptions in this kit that do NOT open *"Use when"* name a **sharper** condition than the one
  that does, so a form check would flag the precise ones and clear the unconditional one. **If you
  have added skills of your own, the rule to apply is the one above; if one of them claims this
  exception, apply the test rather than the precedent.**

### Fixed

- **`scripts/hygiene/cold_signal.py` silently skipped any file whose name is not pure ASCII, and
  reported it as cold.** The instrument matches `git log --name-only` output against the paths its
  own walk found. Under git's default `core.quotePath=true` a path containing any byte outside
  ASCII comes back C-quoted and double-quoted — `café.md` arrives as `"caf\303\251.md"` — so the
  lookup missed, the file scored zero commits, and it was dropped **before** any threshold was
  applied. Fixed with `-c core.quotePath=false` on the walk. **The direction matters: this was an
  UNDER-count that still printed a confident answer.** The tool did not decline to answer and did
  not warn; a file it never saw is indistinguishable in its output from a file it examined and
  cleared. If you have non-ASCII filenames and have been reading this instrument's output as a
  survey of your tree, re-run it — the set it reports may be larger than it was.

  **The fix now has a test, which it did not when it first shipped.** `scripts/test/run.sh` carries
  a case that seeds a file with an accented name into its sandbox, commits it, and asserts the
  history walk keys it by its real name — and then strips the fix from a *copy* of the instrument
  and requires the same probe to fail, so the case cannot pass by accident. If you have vendored or
  edited this instrument, that case is what tells you whether your copy still handles the names your
  tree actually contains.

- **A dispatched spec-compliance reviewer was told the implementer "finished suspiciously quickly"
  as a statement of fact.** `.claude/skills/subagent-driven-development/spec-reviewer-prompt.md`
  asserted that unconditionally, about work neither the dispatcher nor the reviewer had seen, in a
  prompt sent on every dispatch. It is not a fact the template can know, and it primed the reviewer
  toward manufactured suspicion rather than verification. **The sentence is deleted. Everything
  that makes the prompt work is kept** — the report may still be incomplete, inaccurate or
  optimistic, and the reviewer must still verify everything independently by reading the code.
  If you have copied this template into your own dispatch path, delete the same sentence.

- **`process/doctrine/instruments.md` § A.9 shipped a worked example that does not do what it said.**
  The sheet taught that `"$REF:src/thing.py"` on zsh drops the path silently at exit 0. Measured on
  zsh 5.9: **that exact string is `bad substitution`, exit 1** — the loudest of the three outcomes,
  not the silent one. **The hazard is real and the cure is unchanged — always brace, `"${REF}:path"`
  — but the example was the part you would have copied.** The silent drop happens when `:s` finds
  its delimiter repeated in your path (`"$REF:spath/thing.py"` → the bare ref, exit 0), so *which*
  of the three failures you get depends on your path's characters, not on the shape of your mistake.
  The bullet now shows a string that actually produces each outcome. **Also marked unmeasured:** the
  sheet's claim that zsh being the macOS default login shell makes this "the default environment for
  a large share of adopters" — a population nobody sampled. The hazard does not need the figure.

- **`scripts/archive-progress.sh --repo-root <path>` is documented, and is a SUPPORTED option.** It
  was accepted on the ordinary production path and named nowhere in `--help`. It relocates every
  path the script reads and writes — `progress.md`, `progress/history/<name>.md`, the history
  `INDEX.md` — and the tree that `--tag` tags. **Nothing about its behaviour changed**; it was
  already reachable by anyone who typed it. If you script a rotation against a tree other than the
  script's own parent, this is now a documented flag rather than an undocumented one you were
  relying on. It is explicitly **not** a test seam: the kit's real test seams are environment
  variables that defeat a safety gate, and this defeats nothing — it only says where.

- **The self-test harness could report a passing check as a FAIL, at random.** Under
  `set -o pipefail`, a pipeline ending in `grep -q` returns the *producer's* death rather than the
  reader's answer: `grep -q` exits the moment it matches, the writer upstream takes `SIGPIPE`, and
  `pipefail` promotes that to the pipeline's status. **A check that passed was recorded as
  failing.** The threshold is the 64KB pipe buffer and it is a cliff, not a flake — below it
  nothing fails, above it every run does, which is why the failing set moved between two runs of
  an unchanged tree. Fixed by dropping `-q` and redirecting instead — `| grep -F pat >/dev/null` —
  which drains the input and returns the identical status. **This can only ever have refused a good
  tree, never passed a bad one**, so nothing you previously got a green on is in doubt.

  **Scope, stated exactly, because "every site" would not be true.** The self-test harness was
  converted in full. In the *shipped* scripts the fix was applied where the producer **can grow
  with your project** — the header's own test — which is where the defect can actually reach you:
  `check-board.sh` reading your commit history is the one most likely to have bitten a long-lived
  repository, and the worktree scans in `finish-pr.sh` and `lib/kanban-worktree.sh` are the same
  shape. **Deliberately left:** pipelines whose producer is a single flag value being validated
  (`printf '%s' "$NUM" | grep -qE '^[0-9]+$'` and its kin) — those cannot approach the 64KB buffer,
  so they are correct as they stand. To see which sites remain in the tree you have:

  ```sh
  grep -rn '|[[:space:]]*grep -q' scripts consumers --include='*.sh'
  ```

- **A new doctrine subsection and one new Definition-of-Done item: a protection reachable only by
  memory is not a protection.** [`doctrine/fix-execution.md`](doctrine/fix-execution.md) **§ A.5d**,
  placed inside the § A.5 family after the how-a-cure-fails rule. It binds **one step after** § A.5b
  — you decided a mechanism was owed, you built it, it works, and it turns out to sit on a branch a
  bare invocation does not take. **§ A.5b reads as satisfied by that state and it is not.** The rule:
  *where a correct rule exists and keeps being broken by the people who know it, the defect is in the
  rule's REACHABILITY, not in anyone's care.* Three remedies in **cost order**, which is the order to
  try them in:

  1. **Move the DEFAULT** — change which route a bare invocation takes. Do not document the safe
     route better, do not add a warning. Where a default genuinely cannot be moved, the rule does not
     license a warning instead: it requires the attempts **enumerated**, in
     [`doctrine/negative-claims.md`](doctrine/negative-claims.md) § A.1's vocabulary.
  2. **Confirm the EFFECT, not the report** — *the report is evidence the tool ran, never that it
     worked* — with the confirming read chosen by the effect's class: file → re-read it; commit → ask
     the log; **push → ask the remote, never the local ref**; card → ask the board; guard → watch it
     fail.
  3. **Change WHO IS READING** — hand forward the prose adjacent to your change that you **left
     alone**, as a list rather than a judgement.

  **What you must do about it: one thing, and it is small.** § B of that sheet gained a new fill-in
  item — **your per-effect confirming reads**, one row per class of effect your work actually
  produces. **A wrapper is one implementation of a row, never the rule**: the kit requires only git
  and a POSIX shell, so a row is satisfied by a habit, a checklist line or a script, and a project
  that has built a wrapper names it there as its instance. If your § B is empty, nothing breaks.

  **The DoD item** — [`.claude/roles/dev.md`](../.claude/roles/dev.md) § Definition of Done — is
  remedy 2 only, and it is a reporting duty, not a gate: *every step whose report and whose effect are
  separate things has been confirmed by asking the effect.* Remedy 3 deliberately got **no** DoD item,
  because an untouched-neighbours list as a per-change duty without a declared window is a bill on
  every documentation edit you make; it is stated in doctrine and left to your reviewer's read.

  **Two limits stated in the shipped text rather than left for you to discover.** Remedy 3's
  second-party half is **unmeasured** — the one measured catch had the author produce *and* read its
  own list — so notice whether the author-reads-own-list shape is carrying the weight, and do not
  build a gate for it. And remedy 3 **does not extend to a negative result**: § A.5 of
  [`doctrine/negative-claims.md`](doctrine/negative-claims.md) measured a case where the reviewer WAS
  the second reader and both stopped at the same place, so for a negative what is owed is a second
  **route**, not a second reader.

  **No guard is added anywhere, and the reason ships with the rule.** Remedy 1 comes with a
  reviewer's question instead: *for the thing this change protects, what happens if nobody invokes the
  protection?* If the answer is the damage, the default is the defect.

- **`subtask.sh --help` advertised a PRD prefix it never read, so on any project whose prefix is not
  the shipped placeholder the help named a token that project's own tools will not mint.** Its usage
  line carried `[--prd PRD-NNN]` as typed text while the script read `PRD_PREFIX` nowhere. It now
  renders the prefix from `scripts/config.sh`, the way `new-issue.sh`, `new-bug.sh` and
  `new-refactor.sh` already did — the three tools whose help prints the same token.

  **Nothing about `--prd` itself changes**: it is still carried through as an opaque value, still
  validated against nothing, and every id you have already written is still accepted. This is help
  text becoming truthful, not a new refusal.

  **A usage request still always succeeds**, including on a tree where `scripts/config.sh` is missing:
  the seam read is guarded and the text degrades to naming the seam —
  `[--prd <PRD_PREFIX from scripts/config.sh>-NNN]` — rather than printing the kit's own default,
  which would be authoritative-looking and wrong about your project.

  **Why it hid for so long, and what to do with that.** The shipped placeholder happens to be `PRD`,
  so on a pristine tree the typed literal and the correctly-rendered value are the same string: no
  amount of reading `--help` on an un-stamped tree could reveal it. It took a copy of the tree with
  the prefix deliberately re-stamped to something the kit does not ship. **If you have re-stamped
  your own prefix, that is the control to use on anything else that prints one** — run your help text
  on your real tree, not on a fresh unzip.

- **A line of the launch-pack template's own exemplar was prefixed `>`, so following the template's
  instructions deleted half a sentence out of your pack.** `process/templates/launch-pack.template.md`
  tells you — in its opening comment and again in its first guidance block — to **delete every `>`
  blockquote line** before you launch. One body line inside the § Who you are and what binds you
  **exemplar** (the text you copy, not the guidance you delete) carried that prefix, so it rendered
  as a blockquote splitting one paragraph into three, and an author who obeyed the instruction was
  left with *"...there is no § Rigor section The repo files are the truth"*. The prefix is gone.
  **If you have already minted a pack from this template, check that paragraph** — the damage is
  silent, because what remains is still a grammatical sentence. The rest of the template set was
  swept for the same shape and no other instance was found.

- **`.claude/skills/README.md` justified a rule with a reason that cannot apply to the files it was
  applied to.** The provenance table's *How to read the `Class` column* paragraph said an
  **authored-here** skill's class is recorded in the table *"for the reason the vendored ones
  have"* — that re-fetching a skill from upstream copies the folder over and erases an in-file
  marker. That reason is real, and `process/EXTRACTION.md`'s carve-out is scoped to **vendored**
  directories for exactly it — but **nobody re-fetches a skill authored for your kit**, so it never
  reached them. **The rule is unchanged and only its rationale is replaced:** the table is still
  where an authored-here skill's class is recorded, now because the `Class` column is read
  **set-wide**, so a directory the table does not name is one whose class it silently fails to
  answer. **What this changes for you:** the old wording implied an authored-here skill should
  *not* carry an in-file `KIT-CLASS:` marker, since one would be erased. Nothing erases it, so it
  **may carry one** — and where it does, the column and the marker must agree. The paragraph now
  ships the command that tells you which of your skills carry one rather than a number that goes
  stale: `grep -rl 'KIT-CLASS' .claude/skills/`.

## [0.4.0] — 2026-09-08

- **Every refusal that could not load its configuration or one of its libraries claimed to cover
  something it cannot, and they now say what they actually check.** When a shipped script cannot
  load `scripts/config.sh` or one of the three
  libraries under `scripts/lib/`, it refuses with *"…is missing or could not be sourced."* **Measured:
  the second half never happens.** A file that exists but cannot be sourced — a truncated copy, a
  partial write, an edit that broke the syntax — **aborts the script from inside the load, before the
  check runs**, so you get the shell's own error and never that message. Verified on two different
  guards and three different breakages: a syntax error exits 2, a bad command exits 127, and in
  neither case does the kit's refusal appear at all.

  **So the message now says `is missing.` and adds one line naming its own limit** — that it covers
  absence only, and that a present-but-unsourceable file reaches you as the shell's error instead.
  **No action required, and nothing about what the scripts DO has changed.** *If you match on this
  text, the words "or could not be sourced" are gone and one parenthetical line is added; the file
  paths, the remedies and the exit codes are all unchanged.* **Why it is worth changing at all:** a
  refusal that overstates its own coverage is the kind a reader stops trusting, and two seats
  reasoned from this one in a single day without running it.

- **A self-test check that had gone blind now derives what it searches for, and says so if it
  cannot.** One arm of the suite asserts that the `--help` header renderer has **one** authoring
  site — that `scripts/lib/usage.sh` is the only place the logic lives. It looked for that logic by
  a hand-typed string, the library was later reworded, and **the string then matched nothing**: the
  arm found no second authoring site because it was no longer looking for anything, and reported
  success. It now reads the expression **out of the library itself**, refuses to run if it cannot
  find it there, and only then looks for a second copy elsewhere. A second arm — the one that checks
  no shipped `--help` text hard-codes your role set — gained the same treatment, and is now
  exercised against a known-bad header on every run before it is trusted.
  **No action required, and a healthy tree behaves identically.** *If your self-test now stops with
  a message saying it could not find the renderer's expression in `scripts/lib/usage.sh`, that
  means the library was edited in a way the check could not follow — the check is telling you it has
  gone blind rather than passing quietly, which is the whole change.*

- **`doctrine/instruments.md` § A.2 now points its own rule at queries.** That section already held
  *"the audit returned no violations" is not "the audit can see this violation"* — true of an audit,
  and never said of a `grep` that finds nothing, an `ls` that lists nothing, or a selector returning
  an empty set. **A null result is not a measurement until the query has been shown able to return a
  non-null one**, because an empty answer has two indistinguishable causes: the subject has no
  members, or the query cannot return any. The remedy is the section's own ablation rule applied to
  the instrument instead of the subject — **run the same query against something that must match,
  before believing the empty answer.** It also covers the inverse, which is where it pays: a
  positive control is what makes a *small* count trustworthy rather than merely found.

- **The self-test now stops and tells you when it cannot reach your remote, instead of reporting a
  false failure about your scripts.** Three of the suite's readers check whether something reached
  your trunk by fetching `origin` and then looking at the fetched ref. **The fetch's result was
  discarded**, so if it failed — a moved bare repository, a permissions problem, a lock held by
  another process — the reader answered *"not there"* and the case failed with a message about the
  script under test. **Measured: that answer is produced while the push it is asking about
  succeeded.** The fetch is now checked; if it fails, the run aborts with git's own error and says
  the fixture could not be set up. **No action required, and nothing changes on a run whose remote
  is reachable** — which is every run that was passing before.
  **If your self-test now aborts saying it could not fetch `origin/<trunk>`:** that is your sandbox's
  remote, not your kit. The message carries git's reason; the usual causes are a bare repository that
  moved and a `origin` URL that no longer resolves. Previously that condition produced a confusing
  red about a shipped script instead.

- **`--role` now checks against the role set your hook declares, read at the moment you run it.**
  Both `scripts/move-issue.sh` and `scripts/subtask.sh` validated `--role` against a list written
  into the script and rewritten once, by `kit-init.sh --roles`. Their `--help` already read your hook
  directly, so the two halves had different authorities: **on a tree where the hook changed without
  the initializer — which upgrading file by file produces, because that list lived in a file an
  upgrade replaces — the usage text and the refusal message disagreed with each other**, and the
  check was wrong in the direction that costs you something. It accepted a role you had **removed**,
  which is the case the check exists to prevent: the board move happens, the commit-msg hook then
  refuses the commit, and the work is left uncommitted in the shared `.kanban-wt/` worktree, where
  the next board operation discards it.

  **ACTION REQUIRED — one check, and only if your hook and your tooling can disagree.**

  1. **If anything you automate passes a fixed `--role` value, confirm your hook still declares it.**
     Run `./scripts/move-issue.sh --help` and read the `<R> = ` line — that is your set, read from
     your hook. A role that is **not** on that line is now refused, where before it may have been
     accepted. This is the fix doing its job, but it can turn a silently-wrong script into a loudly
     failing one, which is worth finding on your terms rather than mid-move.
  2. **Nothing to change if your hook and your role set were already in step** — which is every tree
     that has only ever used `kit-init.sh --roles`.

  **And when the hook cannot be read, it now tells you.** The check falls back to a default stamped
  into the script for your project, still refuses a role that default does not contain, and prints
  one line to stderr saying the set it used is a fallback and **not** your project's declared set. It
  will not silently accept anything, and it will not silently present the kit's own list as yours.
  **If you parse stderr**, that `Note:` line is new and appears only on a tree whose
  `scripts/githooks/commit-msg` is unreadable.

- **`scripts/subtask.sh --help` was telling you the wrong roles — and on an unmodified kit it was
  telling you too FEW.** Its `move` usage line named three roles by hand. The `move` arm has always
  validated `--role` against **the whole set your project declares** in
  `scripts/githooks/commit-msg`, so on a stock kit the tool accepted seven and advertised three:
  nothing ever told you `--role Architect` was legal on a subtask, and it always was. If you ran
  `kit-init.sh --roles` to narrow your set, it went wrong the other way — the hand-typed line was
  written in a shape the initializer cannot rewrite, so it kept advertising a role your tree now
  refuses. **It now renders your own declared set**, the same way `move-issue.sh` does, and the two
  tools cannot drift apart from each other again.

  **ACTION REQUIRED — two things, and the first one is worth a minute even if you touch nothing.**

  1. **Re-check what your team believes it can pass to `subtask.sh move --role`.** If anyone learned
     the legal values from that usage line, they learned a wrong list. Run
     `./scripts/subtask.sh --help` and read the `<R> = ` line; that is now your project's set,
     read from your hook at the moment you ask.
  2. **If you parse this help text, the shape changed.** The `move` line now reads
     `[--role <R>]`, and the set moved to its own legend line of the form `<R> = A | B | C`
     — identical in form to `move-issue.sh`'s, which has looked like this since the previous
     release. Nothing else in the header moved, the `move` arm's flags and exit codes are
     unchanged, and `--help` still exits 0.

  **And it stays honest when the seam is gone:** with `scripts/lib/role-set.sh` or
  `scripts/githooks/commit-msg` missing, `--help` still exits 0 and **names the file the set comes
  from** rather than printing the kit's shipped default — a list that is right about the kit and
  wrong about your project is the bug being removed, not a fallback from it.

- **`scripts/subtask.sh` now tells you what happened when `scripts/config.sh` cannot be read.**
  Every other script that reads the configuration seam already refused with a named cause; this one
  sourced it bare, so a missing `config.sh` gave you a shell diagnostic — a path and a line number —
  instead of an explanation. It now names the file, cites
  [`process/contracts/config-seam.md`](contracts/config-seam.md), says that it reads **no prefix**
  from the seam so there is nothing for you to guess at, and gives you both ways back: restore the
  file on a tree that had it, or initialize the kit on a fresh repository. **No action required, and
  no correct tree behaves any differently** — this changes only what a broken one tells you.
  **Worth knowing if you upgrade file by file:** `config.sh` is one of the files an upgrade replaces,
  which is how a tree reaches this state, and `subtask.sh` was the one tool that would not have said
  so.

- **`EXTRACTION.md` gains a register of VALUE-KIND markers, and `KIT-CLASS:` is its first entry and
  its model.** A value-kind marker answers what no amount of reading a value will answer — what
  kind of thing it is, therefore who owns it and what may be derived from it. **The obligation is
  one line: a new marker joins that table in the change that mints it.** The register is the point
  rather than the markers: `KIT-CLASS:` already existed and worked, and nothing generalised from it
  because **there was nowhere for a second marker to be listed beside it.** It also states when NOT
  to mint one — **where a distinction can be derived from a value's shape or its path, derive it**;
  a marker earns its place only where values of different kinds share a path, a table, and adjacent
  lines.

- **Nine error messages that name `./scripts/kit-init.sh` as the fix now say which tree that fix
  applies to.** A refusal naming a remedy is making a claim, and on a repository that has already
  been initialized `kit-init` refuses — so `verify.sh`'s empty-gate-table message, `finish-pr.sh`'s,
  `setup.sh`'s, and the six `--prefix`/`--trunk` messages in the creation scripts were pointing at a
  command that would answer *"this repository has already lived."* **Both halves were individually
  correct**; what was wrong was the sentence joining them. The remedy is still right on a tree that
  has never been initialized, which is the common case they were written for, and the text now says
  so — in the same three words `lib/kanban-worktree.sh` has always used. **No action required and no
  behaviour changed** — the remedies, their order and their exit codes are the same. **If you parse
  these messages**, the text after the alternative has grown by a clause and, at three sites, by one
  line; the phrases most likely to be keyed on (`config.sh`, `--gate-command`, `REFUSING`) are
  unchanged and in the same places. *This change was documented TWICE in this section — a second
  bullet, differently worded, describing the same messages. One entry was written when the change
  was FILED and the other when it LANDED, and nothing removed the first. A reader counting what a
  release contained would have counted it twice. The duplicate is struck; THIS bullet is the entry
  the change declares, and the release preflight's notes-obligation arm keys on its first line.*

- **`check-board.sh`'s graduation report now tells you HOW it matched the scaffolding sentinel, and
  the output strings changed.** The arm looks for a line **equal to** the whole shipped sentinel
  comment, not merely for the token anywhere in the file — so a document that *mentions* the
  sentinel in prose is correctly not a hit, and a stub whose sentinel line has been **edited** is
  correctly cleared. Both of those are right and neither was visible in the report. **Action
  required only if you parse this output:** the clearing line now ends with
  *"(exact whole-line match — a mention of the token in prose is not a hit)"* before its
  `read from:` suffix, and the complaining line gains *"matched as the exact whole shipped line, so
  this is the sentinel itself and not a prose mention"*. The phrases your own tooling is most likely
  to key on — `still scaffolding` on a finding, `read from:` on the clear — are **unchanged and in
  the same branches**. If you do not parse it, this is a report that now says what it measured.

- **The self-test now exercises `consumers/` and `setup.sh`, which it had never run.** Its sandbox
  carried only `scripts/`, so the four shipped programs outside that directory — the three consumer
  helpers and `setup.sh` — were bound by the kit's CLI contract and never executed by anything.
  They pass it, measured; what changes is that nothing kept them passing before and now something
  does. **No action required.** If you have edited any of them, the self-test will now check that a
  usage request succeeds and names the tool, and that an unrecognised option exits 2 and names the
  option — so a local change that broke either will show up as a failure rather than as silence.
  **`scripts/test/run.sh` is still not exercised by itself** and says so in that case's own result
  line: a sandbox containing the harness would let it run inside itself.

- **The self-test now checks its own premise about your root documents, and on an adopted tree it
  says what it is NOT checking.** The case that holds the scaffolding sentinel's authors together
  decides which of `CLAUDE.md` and `README.md` to measure by reading each file's first line: a
  document declaring the kit's class is the kit's stub, and anything else is yours and is left
  alone. That decision was previously unasserted, so a `CLAUDE.md` whose first line had been
  deleted was silently dropped from the check rather than reported. **No action required, and
  nothing changed for a correct tree** — on a project that finished day one both documents are
  yours, neither declares the kit's class, and the case now NAMES them in its result line as not
  measured, with the signal that told it your tree has been adopted. **What is newly reported:** a
  root document that is missing entirely is now a failure on any tree, because the day-one
  checklist requires both to exist and two other checks iterate the same pair. If you deleted one
  deliberately, that is the finding.

- **The skills provenance table now carries the provenance.** Its Origin column read `<fill in>`
  for the Dev and PM sets, in the document whose own opening sentence is *"a skill whose origin
  nobody can name is a skill nobody can safely update"* — and the answers were never unknown, only
  recorded in the kit's change history rather than where a reader looks. The **Dev set** is named as
  adopted from the upstream *superpowers* collection, with its URL; the **PM set** as authored for
  this kit. **The Dev set's LICENSE is recorded as `NOT RECORDED`, not guessed** — the upstream's
  terms were never captured at adoption, and the cell names what would settle it. **The Origin
  column is the kit's own record and not a blank you fill**; a note above the table now says so, and
  the only row you fill is the shape row for a skill of yours that departs from its set.

- **`instruments.md` § A.4's derive-twice rule gains a clause: independent means in a DIFFERENT
  LANGUAGE, not merely by a different hand.** Two derivations written in one idiom inherit that
  idiom's assumptions, so their agreement is evidence about the operand and none about the idiom —
  and the place this bites is where operand sets are usually written: **a pattern language cannot
  be used to test its own semantics.** Measured: one set of path globs, declared with `*` not
  crossing `/`, read correctly by one implementation and as crossing by a shell `case` in another —
  a difference of eleven files, in the direction that certified the surface whose checker actually
  reads the missed ones. Both implementations were competent and internally consistent; a third
  reading in either language would have agreed with its sibling and been wrong. **Where the operand
  is a matcher, one of the two readings must come from outside that matcher**, and where that is
  impossible, say so.

- **A `--help` example that names a role is now governed as program output, not as a comment.**
  `EXTRACTION.md` § 2.4's severity table graded *comment, example and recovery text* together as
  cheapest; that grading is kept for a **comment** and superseded for an example the header
  renders, because on a tree that withdrew the named role the tool prints a **copy-pasteable
  command that fails**, in the output an operator is most invited to run. **The remedy keeps the
  example runnable:** it names a real role and one line states that the role shown is an example
  value while the rendered set above is what this tree accepts — which is the kit's own existing
  rule for examples (*never a bare confident example*), applied where an operator will actually
  read it rather than in a contract sheet they are not standing in.

- **`doctrine/instruments.md` § A.4 gains a third notch: ask who WROTE the operand.** Naming a
  span makes a verdict honest about what it claims; deriving it twice catches what one derivation
  misses; **neither notices that the set was read out of a field the measured party fills in.**
  The rule: **a signal is worth reading only where the party it constrains did not author it** —
  with the test that makes it usable (*if this signal started reporting badly, who would have to
  change what they write to make it stop?*) and the clause that makes it honest: **when only the
  self-authored signal exists, say so and do NOT build the check.** A gate over a self-authored
  operand turns an honest record into a defensive one, and the record was the thing worth having.
  No bad faith is assumed and none is needed — someone recording their own reason records the
  reason they believe, and the instrument reports the belief while appearing to report the fact.

- **The pre-cut sweep's checkers no longer have to read the same tree, and § A.4b now says so.**
  The rule required one fresh-context checker per surface and was silent on contemporaneity — read
  strictly it made any one-file change void an entire sweep record, which is how a gate earns a
  routine bypass. **A surface's verdict is now carried forward while no file that surface claims has
  changed**, each surface records its own tree, and the sweep prints the span. **The clause that
  makes it safe:** a non-zero span owes one additional reader whose subject is cross-references,
  because a carried-forward verdict answers for what a surface says about itself and not for what
  one surface says about another. A zero span owes no such reader. **If you keep a surface list,
  it now needs a path expression per surface** — without one, nothing can compute which verdicts
  survive and the honest fallback is re-reading everything.

- **Action required if you have ever run `kit-init --roles`: your `move-issue.sh --help` has been
  lying to you, and the fix is a re-copy.** The usage header named the role set literally, written
  **space-padded** — `<R> = PM | Dev | QA | …` — while the `--role` arm that enforces it held the
  same list unpadded. `kit-init --roles` finds the places to rewrite by matching the unpadded
  spelling, so it stamped the enforcement and **could not see the header**. On every project that
  narrowed its role set, the board mover advertised roles it then refused:

  ```
  $ ./scripts/move-issue.sh --help
    <R> = PM | Dev | QA | Refactorer | UIDesigner | Orchestrator | Architect
  $ ./scripts/move-issue.sh XYZ-001 qa_complete --role UIDesigner --note x
  Error: --role must be PM|Dev|QA|Architect (got 'UIDesigner')
  ```

  **Nothing in your repository is broken and no board state is wrong** — the enforcement was always
  the correct list, so nothing illegal ever got through. What was wrong is the one place an operator
  looks to find out what is legal. **To fix it, re-copy `scripts/move-issue.sh` and
  `scripts/lib/role-set.sh` together** (the header now expands a token using a new `kit_role_display`
  in that library, so the two travel as a pair). You do **not** re-run `kit-init`, and you should
  not: the header no longer carries a copy to stamp, which is the point of the change. After the
  re-copy, `--help` reads your `ROLE_PREFIXES` at print time and cannot disagree with your hook
  again.

  **If you cannot re-copy right now:** your `--role` arm is authoritative, and
  `grep 'ROLE_PREFIXES=' scripts/githooks/commit-msg` is the honest answer to *which roles are
  legal here*.

- **A usage request that renders one of your configured values now has a stated fallback, and it
  will never guess.** `contracts/issue-creation.md` § 3 gained the rule behind the fix above: help
  text that renders a project value (your role set, your status folders, your trunk) reads it from
  its seam at print time instead of carrying a copy — and when that seam cannot be read it **prints
  the seam's location** rather than a value. It never substitutes the kit's shipped default. **The
  request still succeeds with its full text either way**, which is the older rule and is unchanged.
  *Why you are being told about a fallback:* if you ever see `<R> = as declared in
  scripts/githooks/commit-msg (ROLE_PREFIXES) — unreadable from here`, that is not a bug. It means
  the tool could not read your hook and is refusing to guess at your role set, which is the
  behaviour you want from it.

- **`process/EXTRACTION.md` § 2.4 — the role-set register — now checks itself in both directions,
  and it found a second defect doing so.** Its recipe asked *does the new list appear* after
  stamping and never *does an old one survive*, which is how a file could pass the check and keep a
  stale list. The new half compares every role-shaped list in your tree against your hook,
  ignoring spacing. **Run it after any `kit-init --roles`** — it is four lines of shell in that
  section and it is the only thing that catches a copy in a shape the stamper does not produce.
  Shapes that are now known to exist and are *not* the one it stamps: the set **space-padded**, a
  **partial subset** of it, and **one member alone** in an argument position inside an example. The
  list of shapes is not closed, which is why the recipe compares against your hook rather than
  looking for known spellings. **No action required** if you have never narrowed your role set.

- **The auxiliary-checkout contract now says which tree a reviewer reads.** Two sheets each held
  half of one moment: `kanban-worktree.md` described the standing checkout and never mentioned a
  reviewer; `landing-gate.md` described the review-to-land transition and never mentioned a
  worktree — so a reimplementer working from either learned what the checkout is for and never
  learned who was reading what while it was used. **`kanban-worktree.md` § 1 now owns the split**
  (the reviewer reads the work branch; the board move recording the verdict happens in the
  auxiliary checkout) and `landing-gate.md` cites it rather than restating it. No invariant
  changed and no behaviour changed: this is a gap in the language-agnostic law, not in the tools.

- **The downtime queue now says what sends work to it.** `dev/downtime-queue.md` shipped with its
  purpose, its three binding clauses and its removal discipline, and never said what earns a **row**
  instead of a **card** — so it went unused through a whole adoption beside a backlog its own author
  had noticed was not shrinking. The test: **an item nobody will be wrong because of is a queue
  entry, not a card.** And the half that explains the silence: a process cannot apply that test by
  itself, because it needs someone who knows what *wrong* costs — so the sheet now says whose call
  it is and tells you to go and ask. **No check enforces this and the change file says why**: the
  only countable proxy would be authored by the same person whose judgement it is meant to check.

- **`rigor-tiers.md` now says what it does NOT decide, and names the question it was being asked to
  answer.** The tier ladder places an issue by change SHAPE — and shape is orthogonal to scope, so a
  one-line change and a week-long change at the same tier drew identical ceremony and nothing
  anywhere asked *is this one item or four?* The sheet now carries the scope question, the two
  moments it is decided, and `scripts/subtask.sh` as the thing to reach for. **The new part is the
  mid-flight signal:** an item returned from review **twice** is a splitting signal, not a quality
  signal. Every trigger the kit had was a pre-flight estimate, and nothing re-asked the question
  once the work produced evidence. The threshold is yours to change and the sheet says so.

- **The rule that a ruling is recorded in the register now sits on the PM's own path, and on day
  one's.** The rule itself is unchanged and still lives in `process/MANUAL.md` § Execution
  discipline item 6 — what changed is that `.claude/roles/pm.md` now reaches it (it did not link to
  the manual at all) and `SEED.md` step 4 now says what routes into the register it tells you to
  create. **Also new, in `DECISIONS.skeleton.md`: a conversation-sourced ruling's HOME DOCUMENT is
  named** — it is the dated primary-artifact record that file already required you to point at.
  That is what makes deleting a superseded entry safe, and it is what the register's own projection
  rule always assumed without saying. **No rule was added and none changed**; if your project
  already routes rulings to its register, nothing here asks you to do anything.

- **`requirements/DECISIONS.md` gains a THIRD state: a ruling may be WITHDRAWN pending its
  replacement.** The register offered only *current* or *retired*, so the interval between a revoked
  answer and its successor had no shape — and adopters invent one per project, which is how this was
  found. The `Ruling` field opens `WITHDRAWN <YYYY-MM-DD> — <the condition that discharges it>`, the
  `Why` keeps the original reason **beside** what revoked it (`supersession.md` § A.1 applied to the
  interval), and the discharging condition is a **condition, not a date** — the downtime queue's rule,
  cited rather than restated. **The token is anchored** — uppercase, at the head of the field,
  followed by a date — so an entry that *discusses* a withdrawal is not read as declaring one.
  **This is not an exception to the projection rule and needs no carve-out:** *"there is no current
  ruling on X"* is the current state, not archived history. **Nothing checks it yet**, and the sheet
  says so: the state is declared now so the check has a token to read when it ships.
  ([`process/templates/DECISIONS.skeleton.md`](templates/DECISIONS.skeleton.md) § The THIRD state.)

- **Action required: your `PROJECT.md` liveness row becomes two, and `N/A` is no longer a legal
  answer to one of them.** The liveness ritual was one thing scoped by duration — *any run expected
  to outlast a human's attention* — so a project with no long runs could read that honestly and
  declare the whole thing not applicable. One did. **What then went wrong was not a run hanging; it
  was work stopping, three times, with nobody watching.** So the contract now names two rituals:
  **duration** (is this long run alive?), which you may legitimately mark N/A, and **absence** (has
  work stopped moving?), which no project can. Fill both rows. The absence signal is the **newest
  commit across every head on your remote** — not `HEAD`, which is one branch in one worktree and
  reported *697 minutes since anything moved* in a project where the true answer was one minute. And
  it needs **a reader that is not the party being watched**: `scripts/notify/stall.sh` ships as the
  smallest one, opt-in, with no default threshold — the threshold belongs to your run's declared
  cadence, and an alarm on a borrowed number gets muted, which is worse than none because it reads
  as armed.

- **Action required if you publish without a build: declare what ships.** `scripts/release.sh` has a
  new `SHIP_MANIFEST` seam — a file of `<sha256>  <path>` lines naming what your project intends to
  hand out — and a new preflight gate (g) that checks it before anything is written. **If
  `RELEASE_PUBLISH` is true and you have no `BUILD_COMMAND`, the cut now refuses until the seam is
  set.** That combination used to mean the only thing the ritual could publish was your repository,
  and a repository built by this process contains `progress/` — the board, the review notes, the
  running log, all written to be candid. Start with `./scripts/release.sh --approve-shipped`, which
  drafts a manifest from every tracked file and tells you to delete what must not leave; then set the
  seam. **With no build, the manifest becomes the build**: the publish step tars exactly those paths
  out of the tag. If you have a `BUILD_COMMAND`, your artifact glob is already an allowlist and
  nothing changes — but declare the seam and gate (g) will check it. The version bump is normalised
  out of the hashes using the bump's own expression, so bumping a file you ship does not wedge the
  cut; `--approve-shipped` re-records after you have read the diffs it prints.

- **`doctrine/instruments.md` gained the rule the rest of this release was built to earn.** Naming
  what your instrument measured — which § A.4 already required — makes its verdict honest about what
  it *claims*, and says nothing about whether the claim is right. So the operand set must now be
  **derived from the subject, derived a second time by a looser independent reading, and the two
  compared**; every member must be measured, excluded for a stated reason, or named as **not
  reached**, with the three asserted to sum. A new § A.12 adds the clause behind it: **a check you
  can satisfy by editing the answer is not a check** — floors become comparisons rather than numbers
  somebody maintains, and an expected-failure list is compared in both directions so that fixing a
  thing also requires deleting its excuse. § A.2 gains two probe controls: break the member *least*
  likely to be covered, and prove your plant actually took. **Every entry in this release's notes is
  an instance of the defect that rule describes**, which is why it is written last.

- **Action required (maintainers of the kit itself, not adopters): a release cut now takes about
  twice as long — roughly 7 minutes instead of 3.5.** `scripts/release-kit.sh` gained a second
  acceptance arm that takes the built zip through day one with the kit's own tools and then runs the
  self-test on the result, comparing it case-for-case against the run on the unadopted tree. This is
  why the two entries above exist: until now every green the kit recorded was measured on a tree in
  a state the kit tells you not to remain in, so a defect that only appears after day one could not
  be seen from here. **Nothing changes for a project running the kit** — `release-kit.sh` does not
  ship, and your own `scripts/release.sh` is untouched.

- **`check-board.sh` can now report `graduation COMPLETE`. Until this release it could not.** Its
  FILL check counted every `<angle-bracket>` in `PROJECT.md` — including the one inside that file's
  own first-line comment, which reads *"Fill every `<angle-bracket>`"*. So a project that filled
  every real blank exactly as SEED instructs still read one blank short of done, for ever, and the
  only way to clear it was to delete the kit's own marker comment — which nothing tells you to do and
  which the file's disposition forbids. **If you have been seeing `day one is not finished` on a tree
  you believe is finished, this was why.** HTML comments are now stripped before counting, and the
  arm says so in its own span line. It did not get weaker: a real unfilled blank still reports.

- **The self-test's second day-one failure is gone too.** `scripts/config.sh --help printed nothing`
  was reported because the check's population was *any file containing the characters `--help`* —
  and the initializer's own stamp receipt in `config.sh` contains them. A sourced seam with no
  command-line interface was being asked for a usage handler. The population is now *the tools the
  CLI contract binds*, which `process/contracts/issue-creation.md` § 3 states directly. **Together
  with the previous entries, a tree that completed day one now runs the self-test clean.** If yours
  does not, that is worth sending back through `process/KIT-FEEDBACK.md`.

- **The self-test no longer judges your own scripts against the kit's CLI contract.** Its CLI-shape
  check walked `scripts/*.sh` — your directory — and reported the gate runner SEED told you to write
  as violating a contract the kit publishes for its own tools. It now derives what to check from
  `process/KIT-MANIFEST`. **And what the contract does NOT bind is now written down in the contract
  itself**, `process/contracts/issue-creation.md` § 3: protocol-invoked programs (git hooks, agent
  hooks, the stdin notify hook), sourced seams and libraries, and vendored upstream skill helpers —
  each with the test that admits it, so you can tell whether one of your own programs is bound.
  `scripts/notify/telegram.sh`'s `--help` now names itself rather than the script that calls it.

- **The self-test no longer accuses you of a kit violation for adding your own gate runner.** Its
  interpreter-floor check used to walk `scripts/*.sh` — which on your tree includes the gate runner
  SEED told you to write. If yours calls `perl`, `python3`, `node` or `ruby`, the check reported it
  as the KIT breaking its own dependency floor. It now derives what to walk from
  `process/KIT-MANIFEST`, so your files are yours. The check also got **wider**, not narrower: it
  now covers hooks, the notify backends, `consumers/` and `setup.sh`, none of which the old glob
  could see. If you have added files to the kit's own directories and want them checked, the rule is
  a property rather than a list — a shipped shell program may call an off-floor interpreter only if
  the same file guards it with `command -v`.

- **Action required — `scripts/test/run.sh` and `process/KIT-MANIFEST` are now one unit.** The
  self-test REFUSES to start (exit 2) in a tree that has no `process/KIT-MANIFEST`, instead of
  running with a skip. If you re-copy `run.sh` from a new zip, copy the manifest across too; if you
  adopted before the manifest existed and take the new `run.sh` on its own, you will get a refusal
  that names all three ways this happens and what to do about each. The reason is not bookkeeping:
  the checks that ask about *the shipped population* derive that population from the manifest, so
  without it they would assert nothing and print a green while doing it.

- **The zip now carries `process/KIT-MANIFEST` — a list of which files are the kit's.** One row per
  shipped file: `<sha256>  <path>  <KIT-CLASS, or - if the file declares none>`. **It is generated
  by the build and is not tracked anywhere** — editing it means nothing, and it is regenerated whole
  on every build, so do not treat it as a file you maintain. Nothing you run depends on it yet.
  It exists because the kit's own guards could not previously tell a kit file from a file *you* were
  told to add: the self-test's interpreter-floor check reports "25 shipped scripts" on an unadopted
  kit and "26" once you have added the gate runner SEED asks for — counting yours as ours. Reading
  the path column needs no tools; the hash column is for a verifier and the kit requires none.

- **The self-test no longer fails on a `PROJECT.md` you filled correctly.** One of the two failures
  you have most likely seen on your own tree was `PROJECT.md's read/write separation blank is exactly
  one blank the graduation FILL arm can count` — a case asserting a property of the **shipped** sheet,
  which is legitimately gone once you have done SEED step 3. It now reports **N/A on a lived tree**
  when that line holds no blank *and* `scripts/config.sh` carries the initializer's stamp receipt.
  It was **not** widened to accept an empty-or-filled line: that would have made it pass on a tree
  where the blank had been capitalised into invisibility, which is the defect it exists to catch.

- **The self-test gained a fourth outcome and a new refusal.** Some cases assert the shape of a file
  *as the kit ships it* — and after day one that shape is legitimately gone, because you did what
  SEED told you to. Those cases now report **N/A on a lived tree** rather than PASS or SKIP, each
  naming the file whose shipped shape is absent, and the run prints the list. The summary line gains
  a fourth field: `summary: N PASS, N FAIL, N SKIP, N N/A-on-lived-tree` — **the first three keep
  their positions**, so anything reading the line by prefix is unaffected; anything matching it whole
  is not. The new refusal (exit 2) fires when a case records no outcome at all or more than one:
  a case recording none is invisible in every count the harness prints. Nothing you do changes.

- **The self-test would not START on a project that had finished day one. It does now.** SEED step 5
  tells you to REPLACE the `CLAUDE.md` bootstrap stub, and § *Day one is done when* requires that
  neither root document still carry the `BOOTSTRAP-SCAFFOLDING` line — while `scripts/test/run.sh`
  read that line out of your `CLAUDE.md` to build its own fixture, with no fallback. Doing day one
  correctly was therefore the thing that killed the harness: it exited before running a single case,
  with `FIXTURE: could not read the scaffolding sentinel out of CLAUDE.md.` The constant is now
  declared in the harness and derived from nothing in your tree. **Action required: re-copy
  `scripts/test/run.sh` — and `scripts/check-board.sh` with it, for the reason the next entry gives —
  then run it.** You have almost certainly never seen it run on your own tree,
  and it may be red there — the kit's own baseline was measured on an unadopted blank, which is a
  state you were told not to remain in. What it reports on your tree is worth sending back through
  `process/KIT-FEEDBACK.md`.
- **The graduation arm now matches the sentinel's WHOLE line, not the token inside it.**
  `check-board.sh`'s `[g] REPLACE` check asked whether `CLAUDE.md` or `README.md` *contained* the
  string `BOOTSTRAP-SCAFFOLDING`. A document that merely **described** the sentinel satisfied that —
  a backticked mention in your adapter, or a template that grew one — and the arm then reported
  *still scaffolding* against a correctly replaced file, with nothing you could delete to clear it
  except the sentence. It now requires a line equal to the whole shipped comment. Two consequences,
  both intended: writing about the sentinel no longer trips the arm, and a stub whose sentinel line
  was **edited** rather than replaced now clears — editing a REPLACE-class file was never legal, and
  the arm was punishing the wrong readers for it. **Action required: re-copy `scripts/check-board.sh`
  and `scripts/test/run.sh` TOGETHER.** The two are coupled by this change and the harness proves it:
  one of its cases asserts that `check-board.sh` probes for exactly the line the harness declares, so
  a tree that took the new harness and kept the old drift report goes red there — correctly, and
  bewilderingly if you did not know the two moved as one.

- **New: `process/KIT-FEEDBACK.md`, the one document that flows back to whoever gave you this kit.**
  Copy `process/templates/KIT-FEEDBACK.skeleton.md` to `process/KIT-FEEDBACK.md` and leave it empty —
  it is now part of "day one is done when". **Action required for existing adopters:** create it now.
  You have already had the findings worth sending; write down the ones you can still reconstruct, and
  catch the rest as they happen. What the kit most needs is what you can only learn by RUNNING it — a
  script that died, a rule that could not be obeyed on your stack, a tool that reported clean over
  something it could not see. Those are invisible to the kit's own audits, which read rather than run.
  When you send a snapshot, **record the channel by name** in the divider; the rule says why.

- **`scripts/check-board.sh` gains a new arm `[j]`: downtime-queue claim drift.** If you keep a
  `dev/downtime-queue.md`, mark a row `open (claimed by <PREFIX>-NNN)` when you mint the issue —
  the arm then tells you when such a row is still open after its issue has landed. **Informational;
  it never changes the verdict or the exit status.** Without the claim marker there is no join and a
  stale row is indistinguishable from a live one. **Action required only if you want the check:**
  re-copy `check-board.sh` and start writing the claim marker. No queue file means the arm skips and
  says so.

- **`.claude/skills/safety-net-check/` told you to commit characterization tests straight to the
  trunk.** Where your adapter declares the test tree as a code path — the normal case — that
  contradicts the code-vs-metadata rule and asks a Refactorer to bypass your landing gate. The step
  now says to LAND them before the refactor branch exists, by whatever route your code paths require.
  **Action required if you followed it:** nothing to undo, but check whether any characterization
  test reached your trunk without passing your gate.
- **The refactor baseline tag now carries a UTC instant, not a date.** `refactor-baseline-<YYYY-MM-DD>`
  collides on the second refactor of the same day: `git tag` refuses and the run continues **with no
  revert point** — so the case with no safety net was exactly the case where two refactors were in
  flight. **Action required if you have a `refactor-baseline-<date>` tag:** it is fine, but a second
  refactor today would not have created one. Re-copy the skill, the Refactorer role doc and
  `REFACTOR.template.md`, which all named the old form.
- **`.claude/skills/refactor-audit/` now makes you prove a tool saw your code before believing it.**
  Every deterministic tool it recommends has an exclusion list and a default glob, and **a scan that
  reached none of your code reports clean.** Measured at an adopter: 28 Python modules invisible to
  a scanner because `src/` sat in its exclusion list. The skill now requires the tool's file COUNT
  (not its finding count) checked against `git ls-files`. **Re-run any audit whose tools you did not
  verify this way** — a clean tool result in a past audit may have been a tool that saw nothing.
- **`refactor-audit` also now asks whether each candidate defect can actually fire today.** Live
  versus latent, per candidate, before scoring — because "likelihood of future pain" measures how
  often an area is *touched*, and a defect can sit in a hot file and be unreachable. In an adopter's
  controlled comparison this changed three of four priorities.

- **`.claude/skills/writing-plans/` — an earlier [Unreleased] build named the wrong execution skill.**
  Its "Inline Execution" option was changed to `subagent-driven-development`, which made it identical
  to option 1. Reverted: option 2 is `executing-plans`, as the same file states six lines below.
  **Action required if you took the earlier build:** re-copy the skill.

  **And the confusion behind it is fixed at its source.** The two skills' `description:` lines
  described DIFFERENT AXES and so read as contradicting each other: `executing-plans` said "in a
  separate session", meaning the plan was authored elsewhere — the tasks run INLINE, here; and
  `subagent-driven-development` said "in the current session", meaning you orchestrate from here
  while each task goes to a fresh subagent. Both now say which they mean and name the other as the
  alternative. **Re-copy both skills and `.claude/skills/README.md`**, which carried the same
  ambiguity. No behaviour changed — the routing was always right; only the summaries were unclear.
- **`scripts/check-board.sh --help` no longer enumerates the drift classes.** It named five; nine
  arms run. The arms print their own letters as the tool runs. No behaviour change.
- **`.claude/roles/dev.md` overstated what `move-issue.sh` leaves alone.** It said "your current
  checkout and branch are never touched". Your *branch* never is; your *checkout* is fast-forwarded
  when it is already clean and on the trunk. No behaviour changed — the sentence did.

- **`.claude/workflows/wave-runner.js` would have thrown on every run.** The per-issue key guard added
  in this same [Unreleased] section was copied from `tranche-runner.js` and omitted the three
  wave-only fields — `worktreeMode`, `phase`, `restartNote` — that this runner reads and that its own
  description advertises. **Action required if you took the earlier [Unreleased] build:** re-copy
  `.claude/workflows/wave-runner.js`. Any wave dispatch passing those fields refused before starting.
- **Four pack and report templates displayed link labels that resolve nowhere.** `launch-pack`,
  `round-pack`, `round-report` and `run-report` showed `../doctrine/…` labels against hrefs that had
  been corrected for the landing directory. The links always worked; the visible text was dead. All
  labels now show the repo-root path. No action required unless you copy labels by hand.

- **`.claude/skills/systematic-debugging/` — two more copies of the broken `find-polluter` example.**
  An earlier entry in THIS same [Unreleased] section fixed the header comment; `root-cause-tracing.md`
  and the script's own **usage
  message** carried the same pattern, which matches zero files and then reports success. All three
  now carry the required leading `./`. **If you ran the tool from either of those and it found no
  polluter, run it again.**
- **`.claude/workflows/` briefs no longer carry maintainer narration.** Three prompt literals had
  explanatory changelog text inside them, which agents received as instruction text to read and
  discard. No behaviour change; the briefs are shorter and say only what the agent must do.

- **Both workflow runners now refuse an unrecognised per-issue key.** `depends_on` was already
  defaulted, but a caller who wrote `depends_ons` would have got a **silent solo run** — a broken
  dependency chain being exactly what the field prevents. **Action required if you script these
  runners:** a misspelled per-issue key now throws by name before any agent starts. That is
  deliberate; correct the key rather than removing it. The arg contract also now marks per-issue
  keys with `?`, so you can see which are optional — previously only the top-level keys were marked.
- **`process/doctrine/instruments.md` § A: brace the ref in every `<ref>:<path>` recipe.** On zsh —
  the default login shell on macOS — an unbraced `"$REF:path"` is parsed as a history modifier and
  **the path is silently dropped, exit 0**. `git cat-file -e "$REF:absent"` then exits 0 for a path
  in no ref, and `git show "$REF:path" | grep` counts matches in the *commit message*. **Action
  required if you copied either recipe:** rewrite as `"${REF}:path"`. Any landing or tag check you
  built on the unbraced form could not fail, in either direction.
- **`dev/downtime-queue.md` gains a claim marker.** The Status vocabulary now reads
  `open / open (claimed by <PREFIX>-NNN) / STRUCK — …`. Write the claim when the item is minted onto
  the board, not at landing — it is the only link between the queue and the board. **Action required
  if you keep a downtime queue:** your existing `open` rows carry no claim, so nothing can tell a
  stale row from a live one; one pass measuring each row's subject against the trunk is the only way
  to reconcile them once. The file now also states what the marker cannot see, and warns that
  counting with `grep -c "| open |"` under-reported one adopter's queue by 8 rows of 37.
- **`process/doctrine/staleness.md` gains § E — three claim classes a document audit does not look
  at.** A quotation is a promise about bytes (run a misquote census and report three numbers); a
  correction pass must census the defect **string** tree-wide, not the document it was found in,
  because the same prose ships in docstrings and script headers; and a scope word (*"the bullet
  above"*, *"forty lines below"*) is a claim about the document's layout that only rendering checks.
  No action required — but if you run document audits, § E.1's census is a numbered deliverable and
  is meant to replace *"I checked the quotes"*.

- **`.claude/skills/using-git-worktrees/` — the ignore check tested the wrong directory.** It ran
  `git check-ignore -q .worktrees || git check-ignore -q worktrees`: two hard-coded names, ORed. Where
  `.worktrees/` is ignored and the directory actually chosen is `worktrees/`, it short-circuits on the
  first and reports the second safe. **Action required if you vendored this skill:** re-copy it. The
  check now tests the directory § Directory Selection chose. If you have been running with a
  `worktrees/` directory, confirm it is in your `.gitignore`.
- **`.claude/workflows/wave-runner.js` told a Refactorer to commit as `[Dev]`.** On the docs path the
  brief hard-coded a `[Dev]`-prefixed subject while the role was derived and used everywhere else in
  the same brief. **Action required if you run wave-runner with `issue.role: "Refactorer"`:** re-copy
  the file; commits from those runs carry the wrong attribution and your commit-msg hook accepted them.
- **`.claude/workflows/tranche-runner.js`'s park brief named a verdict its schema rejects.** The park-QA
  fail bullet was labelled bare `FAIL`; the enum is `PASS` / `PASS_AC_CORRECTED` / `FAIL_AC` /
  `FAIL_REGRESSION`. Same defect as the QA-prompt bullet in the same file, in the other
  prompt. **Re-copy the file if you run park legs.**
- **`process/templates/CORPUS.skeleton.md` and `DECISIONS.skeleton.md` rendered their instructions as
  body text.** Both embedded a literal `<!-- KIT-CLASS: … -->` inside an HTML comment; comments do not
  nest, so the inner `-->` closed the block early and roughly eighteen lines appeared above the heading.
  **Action required if you copied either skeleton:** open your `requirements/CORPUS.md` and
  `requirements/DECISIONS.md` and delete any stray instruction text above the `#` heading.
- **`.claude/templates/SUBTASK.template.md` declared the wrong landing directory.** It said its links
  are relative to `progress/todo/`; subtask cards land in `progress/subtasks/<PREFIX>-NNN/<status>/`.
  The links themselves were always right — only the declaration was wrong — so nothing you generated is
  broken. Re-copy the template if you have vendored it.
- **`scripts/notify.sh --help` showed `test` as taking a required message.** It does not.
  `notify.sh test` sends a fixed probe and takes no message argument; the usage line now says so on
  both of its sites. No behaviour changed.
- **`.claude/skills/systematic-debugging/find-polluter.sh`'s usage example matched nothing.** The
  example pattern `'src/**/*.test.ts'` cannot match, because `find .` emits paths beginning `./` and
  `-path` matches the whole string — so the script reported success over zero test files. The example
  now carries the leading `./`. **If you ran it and it found no polluter, run it again.**
- **`process/EXTRACTION.md` § 2.8 is now COPY, not CONFIGURE.** `.claude/settings.json.example` has
  nothing inside it for you to fill in — the values that table listed left with the deleted `autoMode`
  block. The decision it asks of you is only whether to activate the hooks at all. No action required
  beyond ignoring the old instruction to substitute a trunk name and a role-prefix list into it.

- **`archive-progress.sh`'s dry run no longer writes anything.** Its DEFAULT mode (no `--apply`)
  created `progress/history/INDEX.md` when that file was absent, then closed by printing
  *"(dry run — no changes made. Re-run with `--apply` to rewrite the files.)"*. **Action required if you have ever run it without `--apply`
  on a board with no rotation index:** you may have an empty `INDEX.md` you did not ask for. It is
  harmless — the header is what `--apply` would have written — but if you would rather it were not
  there, delete it. The dry run now names the file it would create instead of creating it.
- **`.claude/settings.json.example` no longer carries a `_PLACEHOLDERS` map.** The map glossed seven
  `<angle-bracket>` tokens (`<trunk>`, `<PREFIX>`, `<code-path-globs>`, `<metadata-path-globs>`,
  `<adapter>`, `<project-facts>`, `<role-prefix-list>`) and told you to replace "every token below".
  All seven had already left with the deleted `autoMode` block. **There is nothing in this file to
  fill in; copy it as it stands.** Those values are real and are declared where they are used — the
  adapter, `scripts/config.sh`, and the commit-msg hook.
- **`.claude/workflows/tranche-runner.js` told the QA agent to return a verdict its own schema
  rejects.** The fail branch said `return verdict=FAIL`; the enum is `PASS` / `PASS_AC_CORRECTED` /
  `FAIL_AC` / `FAIL_REGRESSION`. **Action required if you run this workflow:** a QA leg that failed
  an issue could error at the structured-output call rather than reporting the failure. Re-copy the
  file. The instruction is now derived from the enum, so the two cannot part again.
- **Three documentation pointers were wrong in ways that change what you would do.**
  `.claude/roles/dev.md` cited `finishing-a-development-branch` **Option 2** for preserving a
  `dev_complete/` worktree — Option 2 is the *no-handoff* path; **Option 1** is the handoff.
  `using-git-worktrees`' quick-reference table consulted your instruction-file preference **last**,
  where § Directory Selection makes it **first** and says explicit preference beats filesystem
  state. The `finishing-a-development-branch` trunk snippet's `|| git config --get
  init.defaultBranch` fallback was **unreachable** — `||` binds to the pipeline, and a pipeline
  ending in `sed` exits 0 even when it produced nothing, so an unset `origin/HEAD` yielded an empty
  trunk name rather than the fallback.

- **`PROJECT.md` gains a `Build order` section — and shipped role docs have been pointing at it all
  along.** `pm.md` prioritises *"against the build order in PROJECT.md"*, and `dev.md` and
  `orchestrator.md` name it as project context; the sheet had no such section. The opening line *"not the
  roadmap"* is true of that **paragraph** and was read as true of the **file**. **Action required:
  write one or two lines in the new section** — what is in scope now, and what is deliberately not
  yet. *If your project genuinely has no ordering yet, write that sentence rather than leaving it
  blank: a blank reads as unanswered, a sentence reads as answered.* Nothing breaks if you skip it,
  but the PM hat's prioritisation step has nothing to read.


- **An option you forgot to give a value to now refuses, instead of silently doing nothing.**
  `--note`, `--role`, `--trunk`, `--prefix` and every other value-taking option: given
  as the last word with no value, these used to **exit 1 with no output at all** — the script died
  on `shift 2` under `set -e` before it could say anything. They now exit **2** and name the option.
  **`notify.sh` was the sharp one:** `notify.sh attention --message` took `--message` as the message
  **body**, sent a notification reading `--message`, and reported success. It now refuses a
  positional beginning with `-`. **`consumers/update_vendored.sh` had no unknown-option arm at all**
  and now has one. **Action required if a wrapper, alias or CI step calls these scripts:** an
  invocation that used to fail quietly (or, for `notify.sh`, appear to succeed) now exits 2 and says
  why. If anything of yours depended on the old silence, it will start failing loudly — which is the
  point, but check it. Nothing changes for a correct invocation.



## [0.3.0] — 2026-09-03

- **`check-board.sh`'s history arms no longer narrow themselves against a shallow clone — and they
  say so.** Both arms scope themselves to the commit that added your `commit-msg` hook. In a shallow
  clone that commit is not the real one: a grafted root has no parents, so every file in it reads as
  *added* there and the epoch resolves to the **clone boundary**. Measured at `--depth 3`, the arms
  narrowed to two commits out of a twenty-commit window and printed a clean result. **This is the
  default CI checkout on most forges**, so it is where the report was least trustworthy and most
  likely to be read by a machine. On a shallow clone the arms now exclude **nothing** and say the
  history is shallow. **No action required** — you get more reported, not less. Run against a full
  clone if you want the narrowing back.

- **`ui-designer-worker.md` was missing the provisioning rider its six siblings carry**, and the
  self-test now checks for it. The sentence — *never spawn above the project's sanctioned ceiling;
  the seat is human-partnered, not a provisionable worker, and its class is not a ceiling* — was
  absent from that one definition. **Action required if you have written your own leaf workers or
  role docs:** the new case reads every file at the TOP LEVEL of `.claude/agents/` and
  `.claude/roles/` — not `roles/archive/`, which it does not descend into — and names
  any that lacks the rider. It checks **presence, per file** — deliberately, because the failure
  mode is the sentence not being copied into a new definition. **It does not read for meaning:** a
  rider that is present and wrong will not be caught.

- **New runner arg `driftRule`, for a project whose pinned output is DERIVED rather than stored.**
  The zero-drift pin was `goldenPaths` — a path shape, which assumes golden FILES. If your pinned
  output is computed (a derived count, a generated manifest, a build-time checksum) you had nothing
  to put there, so you passed an empty `goldenPaths` and **the drift step reported NOT RUN on every
  run, forever** — correct, and useless. **No action required** and nothing changed for golden-file
  projects: `goldenPaths` is still checked first and still wins. If the NOT-RUN line has been
  following you around, `driftRule` is where to say, in words, what your pin is and how to check it;
  the brief injects it verbatim and asks the agent to report what it observed.

- **A new rule on the fix-round budget: a second failure in the cure's own blind spot ends the item.**
  `fix-execution.md` § A.5c, echoed at both runners' fix-round call sites and in `orchestrator.md`'s
  pause law. When the new defect sits where the *first fix's* assumptions do not look — the guard
  that now passes for the wrong reason, the case the narrowed scope excludes — **another round is the
  wrong response**; change the approach or change who is doing it. **No behaviour changed** — the
  runners already stopped after one round — and **explicitly not a provisioning escalation**: do not
  answer it with a bigger model or more effort. The stop should name the blind spot, or the next
  reader gets the same budget and the same angle.

- **`instruments.md` gains § A.11: how to guard *every* number a document publishes.** The sheet
  already held the single-instrument rules; this is the population version, as one rule plus a
  labelled five-step procedure. **No action required** — it is a technique, not a new obligation on
  anything you already have. Worth reading once for two things: **an open exempt set is not a set,
  it is a habit**, and the reviewer's half, which the author of a guard cannot do for themselves —
  **re-census with a strictly wider operand vocabulary than the guard's own**, because a guard will
  re-derive its own set and report agreement.

- **`kit-init --prd-prefix` is validated, and a half-read prefix seam now admits it.** `--prefix` was
  checked and `--prd-prefix` was not, so a value like `REQ-2` was accepted and stamped — after which
  the hygiene instrument could not parse that key, **silently stopped matching your PRD ids, and went
  on reporting `id_prefixes_derived_from_seam: true`**. `kit-init` now refuses such a value, and the
  instrument reports `false` whenever it could read only some of the keys (still using the ones it
  could). **Action required if you adopted with a `--prd-prefix` containing anything outside
  letters and digits:** your staleness instrument has been half-blind since adoption. Change the
  value in `scripts/config.sh` — remembering that existing ids keep the prefix they were born with.

- **The self-test now checks that every travelling script has a contract sheet.** `contracts/README.md`
  always stated the rule in both directions and said outright that this one was unguarded. It is
  guarded now, and the exempt classes are named at the rule so a sweep finds a decision rather than a
  violation: `scripts/hygiene/` (optional, never a gate, deletable), `consumers/` (the consumer-side
  integration surface, a different audience entirely) and `scripts/lib/` (shared
  internals, whose behaviour their callers' sheets already specify). **Action required if you have
  added your own travelling scripts** — anything carrying `# KIT-CLASS: KIT` or `MIXED`: the new case
  will name it unless a sheet cites it or it sits under one of those prefixes. The test to apply is
  *could someone build a conforming kit from the sheets without this file?* A sheet may cite its
  implementation in placeholder form (`scripts/notify/<channel>.sh`) and that counts.

- **A failed release commit no longer leaves your version files bumped.** `release.sh` restored
  only when a *bump* failed; if the **commit** failed — most likely your commit-msg hook rejecting
  `[Architect]`, which is what happens after `kit-init --roles` narrows your role set — the version
  files were left rewritten on disk **and staged**, with nothing said about it. It now restores them
  and tells you, naming `RELEASE_ROLE` as the fix. **Action required if you narrowed your role set:**
  set `RELEASE_ROLE` to a role your hook accepts, or widen the set — the cut will now refuse cleanly
  instead of half-happening, but it still refuses. **If you have a tree with a mystery staged version
  bump in it, this is where it came from**; unstage and restore it.

- **New shipped file: `scripts/lib/card-head.sh`.** The five creation scripts each carried their
  own copy of the block that strips a template's `KIT-CLASS:` marker and writes the live-card head;
  it is one library now, and each script sources it. **Action required if you have adapted or
  written your own creation script:** source `scripts/lib/card-head.sh` and call
  `kit_rehead_card "<the card file>"` instead of carrying the block. If you take kit updates by
  copying `scripts/`, make sure the new file comes with them — a script that calls the function
  without sourcing the library fails **after** the card is already written. The function also now
  refuses if the card came out empty or still carries a marker, which no copy checked.

- **`--help` no longer opens with the file's own `KIT-CLASS:` line.** Header-derived help started
  at a literal line 3, which assumed the marker was exactly one line. Where it wraps — three shipped
  files — help opened with marker text. The start is now derived from where the marker **ends**
  (every marker's last line cites the extraction manifest). **Action required only if you wrote your
  own header-derived `--help`** using the shipped `sed -n '3,…p'` idiom, or if your adapted scripts
  carry a multi-line `KIT-CLASS:` marker: copy the derivation from `scripts/lib/usage.sh`. Every
  shipped renderer is fixed, including all three consumer templates.

- **Bug cards can now declare what they block.** `BUG.template.md` gains `blocks:` and
  `blocked_by:`. A bug found in QA that must be fixed before the feature above it can land is an
  everyday situation, and the board had no way to express it — while the orchestrator **gates
  dispatch** on those exact fields, so the dependency was invisible to the check that acts on it.
  **No action required**; existing bug cards without the fields behave as they always did. **And
  `SUBTASK.template.md` deliberately does NOT get them** — a slice is ordered by its `sM` index and
  its `parent:`, and a dependency on outside work belongs on the parent, which is what the board
  dispatches. The template says so, and says what to do instead.

- **The QA schema gains an optional third axis: `premise_refuted`.** An issue can be implemented
  exactly as written, pass review, land — and have **its own premise** turn out to be false, proven
  by the work itself. That had nowhere to go but a commit subject. It is now a field beside
  `verdict` and `landing`, ratified in `MANUAL.md` § The Dev → QA handoff step 6. **No action
  required — it is optional and absent by default**, and absent means the premise stood. If you
  populate it, carry three things: what the issue assumed, what was measured instead, and where
  that measurement is recorded. **Leave it out rather than empty:** an empty string asserts
  something was refuted and then names nothing.

- **If you run `wave-runner.js`, its parallel legs were being told something false.** The brief said
  a peer works with *zero file overlap with yours* — which reads as *therefore you cannot collide*.
  **The objects that actually contend cannot be assigned to an issue at all:** HEAD, the shared
  checkout's current branch, the git index, a gitignored build tree, and the next free id. A peer
  can move any of them with zero file overlap the whole time. The brief now names them and says
  what to do: your own worktree, never `checkout`/`switch` in the shared root, never `git add` a
  path you do not own, re-read anything derived from HEAD after a pause, and a minted id is taken
  only once it is committed. **No action required** — but if you wrote your own leg briefs from
  this one, they carry the same false reassurance.

- **`architect.md`'s shared-checkout rule changed from a procedure to a structure.** It used to say:
  before any seat commit, confirm the current branch is the trunk and, if an active run holds the
  checkout, wait. It now says: **while any leg is dispatched, commit from a worktree of your own.**
  **Action required if your seat follows the old bullet:** stop relying on checking the branch
  first — there is no ordering of checks that makes a shared root's branch yours while something
  else can move it. Use the kanban-worktree pattern. The reason is recorded at the site and is
  worth reading once: the old instruction was violated repeatedly *by the seat that wrote it*.

- **If you run `wave-runner.js` on docs-path issues, its QA brief was skipping the gate.** The gate
  instruction was attached to *check out the branch and run the gate* — and a docs-path issue has
  no branch, so it took the other half of that sentence and got no gate instruction at all, while
  the verdict block still told the reviewer what to do if the gate failed. The gate is now its own
  unconditional step, matching `tranche-runner.js`. **Action required if you have adapted
  `wave-runner.js`:** its QA steps are renumbered (the gate is the new step 3, everything below
  shifts by one). If your `extraQA` text refers to a step by number, check it.

- **`MANUAL.md` gains a section: the RUN-OUTCOME vocabulary, ratified.** If you use the
  orchestrated runners, the six tokens they report (`LANDED`, `LAND_READY`, `PARKED_OK`,
  `PARK_UNVERIFIED`, `FAILED_AFTER_FIX_ROUND`, `BLOCKED_DEV`) now have an authoring site next to the
  verdict table, with what each is **composed from** — a verdict plus a landing. **No action
  required**, and nothing a runner reports has changed. What changed is that the runners now
  *project* a ratified list instead of being held only against each other: two hand-copies agreeing
  was never evidence either was right. **If you have edited a runner's `OUTCOME` block**, the
  self-test will now tell you when it no longer matches the table.

- **The coupled-operands rule (`commit-hygiene.md` § A.5) now names a second shape, and it is the
  one people miss.** The rule was already right; its examples showed only *a document describing
  code*. The case that goes unrecognised is **a cross-cutting guard whose enrolment list lives in a
  file your code globs call metadata** — the list is not documentation, it is executable, and it is
  the thing doing the guarding. **The tell is now written down: if you are about to add a comment
  explaining why your situation is really covered by § A.5, you are in it.** No action required —
  the handling has not changed, the set is still the unit, ALL-OLD or ALL-NEW. You just no longer
  have to argue your way in.

- **If a tool had to GUESS your trunk, it now tells you — and the case where it stayed quiet was
  the common one.** The trunk is resolved as `<remote>/HEAD` → `git config init.defaultBranch` → the
  kit's last-resort constant. `release.sh` used to warn only at the last link, which needs *both* of
  the first two to be unset; on a normal developer machine `init.defaultBranch` **is** set, so a cut
  against it — a value that is your preference for new repositories, and has nothing to do with what
  your remote calls its trunk — went out with no line about it at all. It now warns, and names the
  one command that settles it: `git remote set-head <remote> <your-trunk>`. `check-board.sh` used to
  resolve through both fallbacks in silence; it now prints the trunk's provenance on its source
  line, because every trunk arm in that report is a statement *about* that branch name. **No action
  required if `<remote>/HEAD` is set** — you will see no new output at all. **If you start seeing a
  guess warning, that is the finding:** run `git remote set-head <remote> <your-trunk>` once.
  **Not `--auto`** — it asks the remote for its own HEAD, and in exactly the state that produces
  this warning the remote has no usable one: measured against a bare repo created by the kit's own
  recipe, `--auto` exits 1 with *"Cannot determine remote HEAD"* while the explicit form succeeds.
  Where you control the bare side, `git -C <repo>.git symbolic-ref HEAD refs/heads/<your-trunk>` is
  better still, and `process/GIT-HOSTING.md` § 3 says why.

- **There is now a rule about how a configured default is WRITTEN, not just what it is worth — and
  it can bite you on an edit that looks like formatting.** Several scripts read a default back out
  of `scripts/config.sh` and `scripts/lib/kanban-worktree.sh` by matching the declaration line
  textually. The shape they match is now contracted: `NAME="${NAME:-value}"`, at column 1, whole,
  on one line. **Dropping the outer quotes is identical to the shell and invisible to every one of
  those matches** — your value would keep working perfectly while everything that derives it
  silently read nothing. **Action required only if you have reformatted, indented or line-wrapped
  one of those declarations:** put it back on one line at column 1, quoted. You will now be told —
  `kit-init.sh` refuses and names the file it could not parse, and `check-board.sh` prints
  `<unresolved trunk>` instead of quietly assuming `main`. Changing a default's **value** is
  unaffected and always was.

- **The kit now states which clock a date comes from, and one row that mixed two has been fixed.**
  A calendar **day** written into a board record — a retirement day, a creation day, an activity
  line, a rotation day — is the day *you* would name, which is your local one. A timestamp meant to
  be ordered or compared across machines is UTC and carries an explicit `Z`. That rule was followed
  everywhere except one place, and it was written down nowhere: `UTC` did not appear in a single
  file of the kit. **The fix is one character.** `archive-progress.sh`'s
  `progress/history/INDEX.md` row put a UTC **Rotated** day next to **Covers** dates that were
  grepped out of your own locally stamped log — for anyone not on UTC, one row disagreeing with
  itself by up to a day, looking perfectly normal. **No action required, and nothing you have
  already written is touched:** a stamp keeps the clock it was born with. Rows added from this
  version on carry your local rotation day; older rows may read a day earlier or later. Do not
  "correct" them — pattern-matching old stamps against a new rule is how you reintroduce the same
  drift in the other direction. **What did NOT change:** the two UTC timestamps in the chunk
  header, which are instants and are right as they are; and every date your board scripts write,
  which was already local.

- **`archive.sh` now reads every argument you give it, and refuses a self-contradictory pair.** It
  used to inspect the first argument only — no loop, no `shift` — so everything after it was
  discarded in silence. Measured: `./scripts/archive.sh --apply --dry-run` swept the board,
  committed and **pushed to the trunk**, with `--dry-run` thrown away; the same two flags in the
  other order previewed and threw `--apply` away. Opposite outcomes from the same request, decided
  by typing order. Both now exit 2, naming both flags and saying nothing was changed. **Action
  required if any wrapper, alias or CI step calls `archive.sh` with more than one argument:** a
  stray second word that used to be swallowed is now a refusal. Check what you pass it. `--apply`
  alone and a bare invocation are unchanged. **`archive-progress.sh` now accepts `--dry-run`**,
  which it used to reject as an unknown option even though preview is what it does by default; it
  carries the same contradiction guard. **`finish-pr.sh` and `release.sh` still mutate by default**
  — nothing there moved — but their refusal of `--apply` now tells you that, and points at
  `--dry-run`, instead of only saying no. The split is deliberate and is now written down: a bulk
  sweep over a set you did not enumerate previews first; a tool acting on one operand you typed,
  behind gates, does not.

- **"Redact secrets, never contents" now says which identifiers count as secrets — because read
  literally, it argued for keeping them.** An account name, a user, a tenant, a host or the
  authenticating identity's own address is *contents* under the old wording, so a capture could
  faithfully preserve every one of them while obeying the rule. The boundary is now explicit:
  **redact credentials and the identifiers of principals; never redact the contents** — the field
  names, link types, codes and bodies are the measured truth the capture exists to hold. **Action
  required if you have committed captures:** re-read them once for identifiers. **What has NOT
  changed, and is worth saying because it is the tempting shortcut:** redaction is not a reason to
  delete or `.gitignore` a capture — raw capture trees are retired never. If redacting would destroy
  the measurement, say so in *What this does NOT establish*. Also: a probe that is not part of a spike
  now has a stated home for its captures.

- **The `PREFLIGHT_GATES` worked example now shows a wrapper script, not a bare command — and it has
  to.** Gate (c) runs your declared command with a deliberate word-split and no `eval`, so an inline
  `sh -c '…'` is torn apart before it runs, and a record cannot contain `|` at all. **Action required
  if you copied the old example:** your gate has no skip state. A gate has three outcomes — passed,
  failed, and **could not run** — and a bare command gives you only the first two, so a check that
  cannot reach its dependency reads as a pass. Put the credential check in the wrapper, print a loud
  `SKIP:` line, and exit 0; the example now shows the whole script.

- **If your provider binds privilege to the ACCOUNT rather than to the token, the kit now has a place
  for you to say so.** Every credential rule assumed read and write access can be separated — that a
  narrower token is something you request. On many providers it is not: a read-only token issued by a
  write-capable identity is write-capable, and separating them costs a **second account**, which is a
  provisioning decision rather than a configuration one. The project doc's *"Read vs write
  separation"* blank previously had no honest answer for you, and the graduation check refuses until
  that blank is filled — so the pressure was to write something plausible. **Action required if this
  is your situation:** say in that blank that they cannot be separated and where you recorded the
  decision, rather than describing a separation you do not have. The operating rule meanwhile is
  literal: **treat every credential as write-capable.** And when you do claim least privilege, say
  which tenant you proved it on.

- **Three card templates told you something about the board checker that was never true.** Each said
  that leaving one of the example Activity shapes as a bullet would make a freshly minted card report
  false drift on your first board check. Measured: the seed entry sits *below* the shapes block, so
  it is the last bullet either way, and the shape lines are written in a form the checker skips. The
  advice is unchanged — **copy a shape out of the block, do not leave one in place** — but the reason
  is now the true one: the block is examples, not entries, and indenting it is what stops an author
  reading one as a logged event. **No action required.**

- **Two prompts your card templates were missing.** A **refactor** card never asked for its notes
  deliverable — even though the issue template names a test-only refactor as the case that owes an
  *explicit dismissal*, so the author most likely to need the prompt was the one who never got it. And
  a **bug** card's Status note never said the card is moved with `./scripts/move-issue.sh` and never
  by hand, where every sibling says so and cites the contract — **a QA author filing a bug was not
  told.** **No action required**; both are prompts in the templates, so copy
  `.claude/templates/BUG.template.md` and `REFACTOR.template.md` if you want them. Existing cards are
  untouched.

- **Your card templates' header comment has been telling you something meaningless since day one.**
  It explained the two placeholders `kit-init.sh` stamps — and it named them literally, so the
  initializer rewrote its own explanation. Every initialized tree's five templates read *"the
  initializer stamps BOTH `<your trunk>` and `<your prefix>` in this directory today"*: a sentence
  with no referent. The header now **describes** the tokens instead of spelling them, and says why,
  so nobody helpfully puts them back. **No action required** — the templates' bodies were always
  stamped correctly and nothing about how you use them changes. If you want the corrected header,
  copy the five files in `.claude/templates/`; your own edits below the comment are untouched. One
  thing to expect: `kit-init.sh` now reports the trunk token stamped into **fewer** templates, because
  two of them only ever carried it inside that comment.

- **"Never spawn the seat's own model class" is retired in favour of your project's declared
  ceiling.** That rule capped every worker by an accident — whatever tier the seat happened to be
  running — so a seat at the top of the ladder capped its workers two tiers below anything you had
  sanctioned. The riders now point at `doctrine/model-provisioning.md` § B.2's
  *"Needs sign-off to exceed"* instead. **Action required, one line, and skipping it costs you the
  guard:** fill in that ceiling. **Until you do, the ceiling is the tier the seat is running** — the
  old rule, kept as the default so nothing is ungoverned while the blank is empty. Unchanged and
  restated at every one of those sites: **the seat is human-partnered, not a provisionable worker.**
  That rule was riding on the retired sentence at more than half of them, and an adopter who
  performed this retirement themselves lost it — which is why it is now stated separately, in one
  vocabulary, with a test.

- **The pre-cut sweep now re-runs after every fix round, verifies by running things where it can, and
  counts your `--help` text as a surface.** The sweep already existed — one fresh-context checker per
  consumer-facing surface, owned by the PM, required before a cut. Three changes: it **repeats until
  a round finds nothing**, because fixing a finding is itself a landing and a single pass certifies
  the tree as it was *before* its own fixes; it **executes** what can be executed, since a claim about
  what a command prints is cheapest to check by running it; and the checkers stand as **naive
  consumers**, asking whether a document tells someone who has never seen your repository something
  false. **Action required if your surface list is already written:** add your commands' usage and
  refusal text to it — those are consumer-facing claims and a documentation-shaped list omits them.

- **A coordinator writing the trunk while a worker holds a branch is expected — the manual now says
  so, and says what your drift report cannot see.** Board moves, rulings, PRDs and `dev/` evidence
  are metadata, so they commit direct to the trunk *while* a dispatched leg works on its branch. Two
  projects reported that as a defect because nothing said otherwise. **No action required, one habit
  worth adopting:** the coordinator's own by-hand commits do not go through `.kanban-wt/`, so while a
  leg is dispatched make them from a worktree of your own rather than switching branches in the
  shared root, and keep `progress.md` append-only. **And know the limit:** a commit displaced by
  somebody's rebase is reachable from no ref, which is outside the span `check-board.sh` measures —
  it prints that limit on every run. The drift report will not surface a displaced commit; the reflog
  is the only witness.

- **The kit's leaf-worker definitions pin a model, those pins are a vendor's product names, and the
  kit now says so.** They were shipping undeclared inside `.claude/agents/` — the one class of fact
  the extraction manifest otherwise keeps out of the kit. They are **kept, not emptied**, because a
  plain spawn of a worker being correctly provisioned with no action is the promise the orchestrator's
  provisioning contract makes. **No action required now**, but know the debt: **these pins go stale
  when your provider renames or retires a tier, and nothing in the kit will tell you.** Re-provision
  them against your own ladder and record what you chose. The declaration lists the shape rather than
  the values, and gives you the one-liner to read the current pins out of the files.

- **Two shipped documents told you `move-issue.sh` would destroy an uncommitted edit in your own
  checkout. It does not, and never did.** The Dev role doc and the branch-finishing skill both said
  a loose edit "is destroyed" when the mover runs — since v0.1.0, in both. The mover's contract is
  that your checkout is never switched; it has no dirty-tree refusal because your checkout's state
  is irrelevant to it; and the only hard reset in the worktree machinery is scoped to `.kanban-wt/`.
  **No action required, and the advice is unchanged** — still do not switch branches before the
  move — but the reason is now the true one: your edit is left **stranded** at a path the trunk has
  since renamed, so your next pull collides on the rename. Nothing is lost.

- **`release.sh`'s notes gates now check the section, not just its heading — and a heading with no
  date is refused rather than skipped.** Gate (e) asserted a `## [X.Y.Z]` line existed and said nothing
  about what was under it, so a heading over a placeholder or a `TODO` cut a release whose notes said
  nothing, and the preflight reported the section *present* — which reads as the notes being in order.
  Gate (f) refuses a header date earlier than a date inside the section, but **nothing in the kit ever
  writes that date** — you type it or you do not — and a heading with no date is not "earlier than"
  anything, so the check was skipped and the section cleared. **Action required if your notes headings
  are undated:** the cut now refuses until you add `— YYYY-MM-DD` to the version heading, and the
  refusal says plainly that no tool will write it for you. Placeholders in `<angle brackets>`, bare
  bullets, `TODO`/`TBD`/`N/A`/`NONE`/`WIP` do not count as content.

- **A new shipped file — `scripts/lib/usage.sh` — and you must copy it.** Six shipped scripts
  rendered `--help` from their own header comment block, each with its own copy of the five-line
  renderer. There is now one, and they source it. **Action required: copy `scripts/lib/usage.sh`
  when you take the updated `archive.sh`, `archive-progress.sh`, `finish-pr.sh`, `move-issue.sh`,
  `subtask.sh` or `verify.sh`.** Without it those scripts fail to start — except `verify.sh`, which
  falls back to a one-line synopsis and tells you the library is missing. **No `--help` output
  changes**: every one was compared before and after and is byte-identical. `release.sh` keeps its
  own renderer on purpose (it prints a synopsis ending at its last usage example, not the whole
  header), and so does `consumers/update_vendored.sh`, which is copied out into repositories that
  have no `scripts/lib/`.

- **Every command-line tool under `scripts/` now refuses an unrecognised option with exit status 2, and
  answers `--help` with usage rather than doing work.** The contract always required one status
  across the set but never said which; it now says **2**, matching what `finish-pr.sh`'s exit table
  already published. **Action required if you script against these tools:** `archive.sh`,
  `archive-progress.sh`, `move-issue.sh`, `kit-init.sh`, `setup.sh` and the two consumer scripts
  refused a bad flag with **1** and now use **2**. A surplus *positional* argument still exits 1 —
  that is a different class and the distinction is deliberate. **Two changes can bite you even if
  you do not script against them:** `notify.sh` used to print *"ignoring unknown arg"*, **deliver the
  notification, and exit 0** — a typo'd flag now refuses instead; and `next-id.sh --help` used to
  print a **mintable issue id** and exit 0, so a usage request handed you an identifier you might
  then have used. A failed *delivery* from `notify.sh` still exits 0 on purpose, and
  `check-board.sh` still always exits 0 with its verdict on a line — neither of those changed.

- **One name now sets the remote for everything, releases included: `KWT_REMOTE`.** It already
  controlled the board mover, the archive sweep, the subtask mover, the PR landing, the drift report
  and the initializer — but `release.sh` read only its own `RELEASE_REMOTE`, so a fork that set
  `KWT_REMOTE=upstream` published its board to the fork and its **releases to `origin`**, silently.
  **Action required if you are on a fork:** your release push and tag now follow `KWT_REMOTE`. If you
  genuinely want releases somewhere else, set `RELEASE_REMOTE` — it still overrides, for the release
  push only, and it is the one place a URL is accepted. `KWT_REMOTE` must be a remote **name**: the
  worktree machinery resolves your trunk through `refs/remotes/<remote>/HEAD`, and a URL there fails
  that quietly. Both are now documented in `.env.example`, which listed neither.

- **`subtask.sh new` no longer corrupts a `--title` (or any other value) containing `&`, `|` or a
  backslash.** Three creation scripts escaped these; `subtask.sh` — the one that takes the most free
  text and the only one that **publishes to your trunk** — did not. A `&` was silently corrupted
  into the card while the heading stayed correct, so the two disagreed. A `|` aborted the run
  **after** the card file had been created, leaving a zero-byte file inside `.kanban-wt/` that
  `reset --hard` does not remove and that **blocked that subtask id** until deleted by hand. A
  backslash was interpreted rather than kept, splitting the heading across two lines. **No action
  required** — nothing you already have changes, and no interface moved. The escaping helper now
  lives once in `scripts/config.sh` instead of being copied into three scripts; if you have edited
  one of those copies, your edit is in a function that no longer exists there. Not covered: a value
  containing an actual newline.

- **`new-prd.sh` and `subtask.sh` now refuse a short name that is not `lower-case-with-hyphens`, and
  `subtask.sh` also checks the subtask suffix.** Three creators already enforced this; these two did
  not. For `subtask.sh` it was not cosmetic: its `new` arm writes `branch: feature/<id>-<slug>` into
  a card it **publishes to your trunk**, and the role docs tell Dev and QA to `git switch` that
  value — so a name with a space produced a published card naming a branch git itself refuses to
  create, and burned the id. **Action required only if you use capitals, spaces or underscores in
  short names:** those invocations now exit 2 and write nothing. Existing files are untouched —
  nothing is renamed. The suffix must be `s` followed by digits, because the `move` arm recovers the
  parent id from it and any other shape silently resolves to the wrong parent.

- **`.kanban-wt/` is for board files, and the kit now says so — plus the remedy it printed for a
  dirty worktree no longer tells you to `git add -A`.** That directory is the only checkout sitting
  on your trunk while your own is on a work branch, which makes it read as a spare clean tree. It is
  not one: its HEAD **is** the trunk and its push target **is** the trunk, so anything in it is one
  ordinary commit from `main` with no branch and no gate between. **Action required — check your
  trunk once.** In one project a commit made in that directory replaced the project README with a
  generated distribution page and added four release artifacts, a 44 KB wheel among them; that is
  how this was found. Look for a commit touching files you would not expect on the trunk. Two routes
  put them there: the blanket `add -A` the tool used to print (now scoped to `progress/`), and
  `git checkout <ref> -- .`, which **stages** its payload so a plain `git commit -m` carries it —
  **no guard can catch the second one**, which is why the rule is now written down instead. The
  dirty-worktree guard also now lists untracked files it finds there, labelled separately: they are
  not what it refuses on, and a reset does not remove them, so they accumulate.

- **`check-board.sh` gained arm `[i]`: it checks that `blocks:` and `blocked_by:` agree across your
  board.** A dependency is written on two cards and neither can see the other, so `blocks: [B]` on A
  with no answering `blocked_by: [A]` on B looks correct on each card alone — and the seat that
  sequences work reads the board, not both files, so the pair that lost half its declaration gets
  dispatched onto work that has not landed. The arm reads **both** keys, so it catches the pair
  whichever end survived, and every finding names **both** cards because either may be the stray
  one. A reference to a card that is not on the board is reported separately, as a dangling id
  rather than a missing answer. **No action required: this arm is ADVISORY** — it carries the
  `reports only` marker, never changes the `board-drift:` verdict, and cannot block a release. That
  is deliberate: nothing in the kit writes or clears these fields, so a refusal here would have no
  operation to name as its remedy. Both the inline (`[A, B]`) and the block (`- A`) YAML shapes are
  read, and the trailing `#` comments the templates ship with are ignored.

- **`check-board.sh` gained arm `[h]`: it reads recent trunk history for generated co-author
  trailers, and it can block a release.** Your commit-msg hook refuses these at write time, but a
  write-time wall says nothing about history already written, and `contracts/commit-attribution.md`
  states the count in a recent window as zero — which nothing measured until now. The arm scans the
  same recent window as the `[Role]`-prefix arm and **shares its epoch**, so commits that predate
  your adoption of the kit are not reported. **Action required if recent trunk commits carry tool
  trailers:** the arm sets the board-drift verdict, so `release.sh` gate (d) will refuse a cut until
  those commits roll out of the window — it clears itself as history moves, and rewriting published
  history to clear it is not recommended. A `Co-Authored-By` naming a **human** is untouched and
  always legitimate; the markers are read from your own hook, not from a list the kit keeps.

- **A new shipped file — `scripts/lib/lived-probe.sh` — and you must copy it.** `kit-init.sh` and
  `check-board.sh`'s graduation arm both ask whether your repository has already STARTED, and each
  used to answer with its own copy of the same four probes. **Action required: copy
  `scripts/lib/lived-probe.sh` when you take the updated `kit-init.sh` and `check-board.sh`.**
  Without it the initializer refuses and the graduation arm reports that it did not run — loudly in
  both cases, naming the file, but you will have to go and get it. **One behaviour changed, on
  purpose:** the two copies had already drifted apart on how they recognise the initializer's stamp
  in `scripts/config.sh` — one required it at the start of a line, the other matched it anywhere —
  so a tree could be "not started" to the initializer and "already started" to the report. The
  shared probe now requires the mark at the **start of a line**, matched literally. If your
  `config.sh` carries an indented or mid-line stamp receipt, the graduation arm will no longer treat
  it as a receipt; a board with issue files, a `progress.md` § Log with entries, or an `ARCHIVE.md`
  index all still enable the arm exactly as before.

- **Three scripts that commit under a fixed role tag now check it against your declared role set,
  and refuse before they touch anything.** `archive.sh`'s sweep, `subtask.sh`'s `create` arm and
  `finish-pr.sh`'s squash each hardcoded a seat — `[Orchestrator]`, `[Orchestrator]`, `[QA]`. If you
  ran `kit-init --roles` and dropped one of those roles, the tool would move the card **and then**
  have its commit rejected by your own hook, leaving uncommitted changes in the shared kanban
  worktree that the next board operation discards — and the operation after that would fail with an
  error naming neither the role nor the sweep. They now refuse up front, naming the knob.
  **Action required only if you have narrowed your role set:** export the seat you want each to act
  as — `ARCHIVE_ROLE`, `SUBTASK_ROLE`, `FINISH_PR_ROLE` — each documented in its script's header and
  each defaulting to what was previously hardcoded, so **projects that kept the shipped role set
  need do nothing.** Related, in the same change: `finish-pr.sh`'s recovery text used to tell you to
  re-run with the very `--role` that had just been rejected; it now names the knob.

- **`release.sh` now refuses to cut a tag from a checkout that is not the published trunk's tip.**
  Gate (a) read only your own machine: on the trunk, tree clean. A checkout that passes both can
  still be **behind**, and the tag then names a tree missing what already landed. The branch push
  would have rejected it — but the script's own printed recovery then walks you into publishing an
  annotated tag on a pre-rebase commit that is on no branch. Gate (a) now fetches and compares.
  **Action required, both directions.** *Behind:* `git pull --ff-only`, then cut. *Ahead:* push
  first — this was already refused by gate (d) via the board report's unpublished-trunk arm, and is
  now caught earlier with a clearer message, so **the pre-cut ritual now includes pushing your
  release-notes commit before you cut.** If the fetch itself fails, the cut **refuses** rather than
  warning, because a tag is the one act the ritual never rolls back; the message says plainly that
  this is about reaching the remote and not about your tree. For a genuinely offline cut, declare
  it: `./scripts/release.sh X.Y.Z --no-fetch`, which is recorded loudly in the run's output. A
  local bare repository as `origin` — the kit's own day-one topology — fetches fine and needs no
  flag.

- **`check-board.sh`'s `[Role]`-prefix arm no longer reports commits that predate your adoption
  of the kit.** A rule cannot be violated before it exists, and this one reported every
  pre-adoption commit as drift — findings you could not fix without rewriting published history.
  It fired on the **first report you ever saw**, because the kit requires a commit before
  `kit-init.sh` may run and wires the commit-msg hook after it, so a correctly-executed day one
  guaranteed a false finding. The arm now scopes itself to the commit that **added**
  `scripts/githooks/commit-msg`, and reports only commits **strictly after** it — strictly,
  because the kit's own day-one recipe commits the hook file under the subject `init`, making the
  epoch commit itself one of the unprefixed ones. **Action required — re-read your drift report
  once.** Findings you had learned to ignore will disappear, and anything that remains is a real
  finding you may have stopped seeing. If your report was never clean and you had stopped reading
  it, this is the release to start again. Two things are stated in the arm's own output rather
  than only here: how many commits it excluded and why, and the one case it still gets wrong — a
  clone that has the hook **file** but never ran `git config core.hooksPath scripts/githooks` is
  not enforcing the rule, yet the arm treats it as binding. That errs toward reporting drift
  rather than hiding it, and those findings flip the `board-drift` verdict that `release.sh`
  gate (d) refuses on.

- **`kit-init.sh` now repairs the commit-msg hook's executable bit, and does it before the commit
  that creates your trunk — so the repair reaches every future clone.** git skips a hook file that
  is not executable *silently*: it prints a hint to stderr and lets the commit through. A trunk
  committed with that bit off gives every clone of your repository a role-prefix guard that never
  fires. Relatedly, when the bit is missing `kit-init.sh`'s self-check used to report
  *"core.hooksPath is not in effect"* — the wrong cause, which sent you to re-run wiring that had
  worked. It now names the mode and gives you the `chmod`. **Action required, once, if you adopted
  the kit before this release:** run `ls -l scripts/githooks/` on your trunk. If `commit-msg` is
  not executable, `chmod +x scripts/githooks/*` and **commit the change** — the bit is repository
  content, so fixing only your own checkout leaves every teammate and every future clone
  unguarded. Also documented: `core.hooksPath` has **two owners and one lifecycle** —
  `kit-init.sh` wires it once at adoption and commits the bit, `setup.sh` re-wires and repairs it
  on every fresh clone (`process/contracts/initializer.md` § 2). Four shipped files previously
  named one owner each, and named three different ones.

- **The hygiene instruments' prefix-exclusion set now lives in one place.** `cold_signal.py` and
  `duplication_scan.py` each defined it, under different names, with byte-identical values and **two
  separate "EDIT THESE for your tree" instructions** — so tuning the corpus in one left the other
  reporting on a different one. It is now `DEFAULT_EXCLUDED_PREFIXES` in `citation_index.py`, which
  every instrument in that directory already imports. **Action required if you tuned either copy:**
  re-apply your edit once, in `citation_index.py`, and delete nothing else — your other copy is gone.

- **`NOTIFY_ON_SETUP_FAILURE` is declarative — nothing in the kit branches on it — and both places
  that named its legal values now agree.** `.env.example` said `continue|abort` while the warning said
  `stop`, and no code read either. The knob records what your project wants done when
  `notify.sh test` fails; `test`'s non-zero exit is the fact, and your own session-start wiring is
  what acts on it. **Action required if you set it to `stop`:** that spelling was never read by
  anything, but it is now wrong on its face — use `abort`.

- **If `finish-pr.sh` refuses because you have no gate runner at all, it now tells you how to GET
  one.** That advice — *write `scripts/verify.sh`, or generate it with `kit-init.sh --gate-command`* —
  sat in a branch no input could reach, so the refusal an adopter actually met talked about checking
  out branches and using `--worktree`: the remedy for a gate at the wrong revision, not for having no
  gate. The two cases are now told apart and each gets its own remedy. **No action required** — the
  refusal conditions are unchanged; only what they tell you.

- **`EXTRACTION.md` § 2.2's `setup.sh` row was wrong in both of its cells.** It said `setup.sh`
  CREATES the board directories; `setup.sh` contains no `mkdir` and only checks they exist. And it
  said a missed column means *"a fresh clone is missing the directory"* — that is `kit-init.sh`'s
  row. What a missed column actually costs `setup.sh` is that it **stops noticing**: a tree lacking
  the new column passes its check silently. **If you have added a board column, re-check that
  `setup.sh`'s `BOARD_FOLDERS` lists it** — nothing failed to tell you it did not.

- **The run-outcome vocabulary now has a named declaration in each runner and a self-test case holding
  the two together.** `LANDED`, `LAND_READY`, `PARKED_OK`, `PARK_UNVERIFIED`, `FAILED_AFTER_FIX_ROUND`
  and `BLOCKED_DEV` were bare string literals at twelve sites across the pair, with nothing holding
  them in step — so the two runners could report different outcome sets for the same situation. The
  case also refuses a declared token the runner never returns. **No action required** — no token was
  added, removed or renamed, and the values a run reports are unchanged.

- **`EXTRACTION.md` § 2.2 now registers the `.claude/` tree as a status-folder carrier, and its
  derivation recipe can finally reach it.** The recipe scoped to `scripts/` and `setup.sh`, so the
  runners, item templates, role docs, worker definitions and two skills — all of which name board
  columns — were invisible to the instrument the section offers for finding carriers. **If you have
  renamed or added a board column, re-run the widened recipe:** the narrow one returned fewer than
  half the files that name a column, so a previous lifecycle change may have missed the agent-facing
  half and left briefs instructing a move to a column that does not exist.

- **The two workflow runners' result schemas now agree field-for-field, and a self-test case keeps
  them that way.** Five field descriptions had drifted apart between `tranche-runner` and
  `wave-runner`, and one field had lost its description entirely — so the same result field was
  explained differently, or not at all, depending on which runner briefed the agent. The runners
  cannot share a module (the workflow runtime gives them no imports), so the copies are permanent and
  a guard now holds their agreement instead. **No action required** — no field, type or enum changed,
  only the descriptions agents are given.

- **`wave-runner` now honours a per-issue `role`.** Its description has always promised the same
  per-issue fields as `tranche-runner`, and `role` was accepted and silently ignored — so a
  Refactorer-hat issue placed in a wave was briefed as Dev, pointed at `dev.md`, **and stamped its
  board moves `[Dev]`**, which is what the commit-msg hook enforces and what the board's attribution
  arm reads. **Action required if you have run Refactorer issues through a wave:** their board moves
  and progress entries carry `[Dev]`, so attribution for that work is wrong on the trunk and in
  `check-board.sh`'s report. Nothing needs re-running; the record is what is affected.

- **`tranche-runner` now tells Dev to cut work branches from `<remote>/<trunk>`, not the local trunk**,
  matching what `wave-runner` already said. Neither runner instructs a pull first, so *"from a fresh
  main"* meant whatever the checkout happened to hold — and in a tranche that lands issues as it runs,
  the second issue could branch off a trunk missing the first. A new optional `remote` arg defaults to
  `origin`. **No action required** unless your remote is not called `origin`, in which case pass
  `remote` in args as you already do for `wave-runner`.

- **The QA brief's procedure no longer skips a number.** The zero-drift check is conditional, and while
  it was a numbered step the list jumped from 5 to 7 whenever it was absent — which reads to a reviewer
  like a step that went missing on the way to them. It is now an unnumbered continuation of the
  binding-gates step, which is also what it is: a gate for that issue, not a separate phase. **No action
  required** — the checks are unchanged, only their presentation.

- **`tranche-runner` no longer documents a per-issue `slug` field.** It was listed in the args
  comment and echoed in the parse-failure message while nothing in either runner read it, so a caller
  was asked for a value that could not affect the run. There is nowhere it could be used: every board
  move the runners emit goes through `./scripts/move-issue.sh <id>`, which resolves the card path from
  the id alone. **No action required** — passing `slug` was always inert and still is; it is simply no
  longer asked for.

- **Both workflow runners now refuse an omitted or empty issue list by name.** Driving
  `tranche-runner` with no `issues` previously died on JavaScript's own `TypeError: undefined is not
  iterable`, which names neither the runner nor the field; driving `wave-runner` with no waves was
  **worse — it reported a clean success over zero issues**, because an empty result list satisfies
  every wave gate vacuously. Both now fail at 0 agents with a message naming the field and the shape
  expected. One wave is still legitimate; neither is not. **No action required** — a correct call is
  unaffected.

### Added

- **Day one has a documented variant for making your first *published* commit your project's own.**
  The initializer requires a commit before it runs and then makes and pushes its own, plus more
  while self-checking, so the earliest history on a hosted remote necessarily began with kit
  scaffolding — and `--skip-self-check` does not change that. `README.md` § Day one now names the
  way through: point `origin` at a local bare repository first, run day one against it **with the
  self-check intact**, author your content, then squash and re-point at the host. **The kit does not
  perform the squash and has no flag for it** — that is deliberate, because rewriting history is
  safe there only while nothing has been published, and a tool could not know that. Nothing changes
  for a project already initialized.

### Changed

- **A minted card no longer opens by calling itself a template.** `new-issue.sh`, `new-bug.sh`,
  `new-prd.sh`, `new-refactor.sh` and `subtask.sh` copied their template wholesale, so every live
  card carried the template's `KIT-CLASS:` marker — false the moment the card exists, since a card's
  class becomes PROJECT at mint. Each script now **replaces** that block rather than deleting it,
  because the block also carried the *never leave an angle bracket* instruction, which is still in
  force while you fill the card and is stated nowhere else. The card's new head says it is a live
  card, states that its lack of a travel marker is deliberate, and keeps the fill instruction.
  **No action required.** Cards already on your board keep the old header; strip it if you like —
  nothing reads it. **If you grep your board for `KIT-CLASS` to audit classification, newly minted
  cards will now correctly not appear.**
- **`EXTRACTION.md` no longer tells you both to mark and to strip the same file at the same
  moment.** § The one file classification convention said that once you fill `PROJECT.md` and
  `CLAUDE.md` they are `PROJECT`-class *"by nature"* and to **mark them so**, while § The marker and
  graduation said to **strip** the marker at exactly that point — and named `PROJECT.md` as its own
  worked example. The graduation rule is the correct one and stands; the *mark them so* instruction
  is struck, with a pointer to it. **A new carve-out covers the file born in your own tree that will
  never travel:** it carries no marker, and it carries **one visible line saying that absence is
  deliberate**, because a bare absence cannot be told apart from an oversight. The test is whether
  the file's **shape** travels — `requirements/CORPUS.md` keeps its marker however project-specific
  its entries get; a log you invent for yourself never had one. **Action required only if you
  re-marked a graduated file `PROJECT`:** strip it instead, and if you have unmarked files of your
  own, give each the one-line note.
- **`EXTRACTION.md` § 4.6's post-initializer check now reads `.claude/roles/` too, and rules that
  `<trunk>` there is notation rather than an unfilled blank.** The check previously named `<trunk>`
  but scanned only `.claude/agents` and `.claude/workflows`, so it never read the directory that
  actually carries those symbols — and widening it naively would have reported every one as a defect.
  Every role doc **defines** `<trunk>` in its own preamble, and the initializer rewrites the
  **literal** trunk name rather than the symbol, which is also why its census line reads
  `trunk '<default>': N → N` on a project whose trunk is the shipped default: it counts the literal,
  and there was nothing to change. **No action required** — nothing an adopter runs changes; if you
  previously widened § 4.6's grep yourself and got hits in `.claude/roles/`, those hits were the
  definitions.
- **`SEED.md` step 2 now says that `--gate-command` is for that run only, and names the fallback
  where you are standing when you need it.** The flag cannot be supplied on a re-run — the
  initializer refuses and there is no resume path — so a project that has not settled its gate
  command by the time it stamps could not come back for it, and the alternative (declaring gates by
  hand in `scripts/verify.sh`'s `GATES` table) was documented only in `--help` and `README.md`. It
  is now stated in the order-of-operations document too, as a **supported route rather than a
  fallback**: what the landing gate requires is an executable, committed gate runner, never that the
  initializer wrote it. Skipping both is still refused at both ends.
- **The day-one recipe now says `git init -b main`, and the `git switch -c` line is gone.** A bare
  `git init` puts HEAD on whatever `init.defaultBranch` says — still `master` on any machine whose
  git predates the default change or whose user never set it — so the first commit landed on
  `master` and the later `git switch -c` created `main` from it, leaving two branches at one commit.
  The deleted line's condition (*"if your trunk does not exist yet"*) was false at the moment it was
  read, which invited a careful reader to skip it and then be refused by the initializer's trunk
  check for a reason that did not name the cause. `process/SEED.md` step 1 is reconciled to match.
  **No action required** — if you already initialized, a stray `master` at the same commit is
  harmless and yours to delete.
- **A malformed `args` payload to either runner now fails with a message that names the runner, the
  problem and the expected shape.** Passing non-JSON previously produced a bare
  `SyntaxError: JSON Parse error` whose only location was the harness file, not the runner — so the
  message pointed away from the thing that was wrong, at the entry point you drive first. The parse
  is now wrapped: the error names the runner, echoes the value it received (truncated), names the
  required top-level keys, points at where the full shape is declared in that file, and appends the
  underlying parse error. **The fail-fast is unchanged** — the run still dies at 0 agents.
- **`goldenPaths: ''` now actually skips the zero-drift step in both runners.** The runners
  documented *"empty string = skip the zero-drift diff entirely"* and then used `||`, so `''`
  silently restored the default `tests/fixtures tests/golden*` — a project with no pinned-output
  corpus ran a diff against paths that do not exist on every issue, and had to rely on the prompt's
  *"If it matched NOTHING, say so loudly and treat the zero-drift step as NOT RUN"* warning each time. Both runners now use `??`.
  **If you pass `''` today you will now get a skip where you previously got the default**, which is
  what the comment always promised; if you actually want those paths, name them.

### Action required

- **`.claude/workflows/wave-runner.js` did not parse in v0.2.0 — the wave path was unusable.** A
  paragraph of maintainer narration inside the park-QA brief put backticks around a field name, which
  terminated the template literal and made the whole file unloadable; driving the wave path produced a
  syntax error at 0 agents. It was broken in the released zip, not only in the source. The narration
  has moved into a comment and the brief now matches its sibling's wording. **Action required if you
  adopted v0.2.0 and use the wave path:** take this file from a later kit, or delete the parenthetical
  beginning *"(This line used to say"* from `parkPrompt`'s returned string. `tranche-runner.js` was
  never affected.

- **Three role docs said the model-and-effort table was ratified while the kit shipped it blank.**
  `.claude/roles/dev.md` and `qa.md` said *"ratified by PM"*; `orchestrator.md` said *"the
  adapter's PM ratifies it"* in a present tense that reads as a standing fact. All three now say
  the table ships blank, that filling and ratifying it comes before relying on it, and that until
  then the seat states its chosen model and effort on the card with a reason. **Action required:**
  if you read one of those docs and never filled the ladder, fill and ratify it now — the doctrine
  sheet's own sentence is that an unratified ladder is a habit with a table, and it was coming true
  silently. `pm.md` and `refactorer.md` always said this correctly and are unchanged.
- **A `.gitignore` line whose comment trails the pattern matches nothing, and the kit's own FILL
  block taught that shape.** `#` only begins a comment at the START of a line in gitignore syntax,
  so `dist/  # produced by my build` makes the comment part of the pattern: the rule matches
  nothing, git goes on reporting the artifact, and nothing says why. All four worked examples in
  `.gitignore`'s `<your build artifacts>` block now put the comment on the line above, with the
  reason and `git check-ignore -q` beside them. **Action required if you filled that block by
  following the examples:** move each comment to its own line and verify every entry with
  `git check-ignore -q <path>` — reading them cannot tell you which are dead.

## [0.2.0] — 2026-08-31

### Changed

- **The project-facts sheet is now the only blank, and its template is gone.**
  `process/templates/PROJECT.template.md` is removed: `PROJECT.md` ships as its own blank and you
  fill it **in place**. The template's `§ Retained evidence` has moved into `PROJECT.md`, and two of
  its gate rows — the acceptance tier and retention completeness — were the correct ones and are now
  the shipped ones. *Why:* a template nothing stamps drifts from the instance it claims to be; every
  edit reached the live sheet and none reached the copy. **Action required only if you linked the
  template path** — re-point at `PROJECT.md`. A sheet you have already filled is untouched.
- **`.claude/workflows/wave-runner.js` no longer halts a wave on a verified pass whose landing was
  deferred.** A `LAND_READY` outcome now continues, matching the runner's own stated rule and its
  sibling tranche runner. If you relied on the wave stopping there, it will now proceed to wave 2.
- **The debugging helper `find-polluter.sh` parses again under the default macOS bash.** It was
  unparseable under bash 3.2 — the shell that ships on macOS — so the skill's script could not run
  at all there. Its `TEST_CMD` knob is unchanged and still required; the usage line now says so.
- **Three unused skill files were removed** — two reviewer-prompt templates whose dispatch no longer
  exists and an upstream authoring log citing paths the kit does not have. Nothing references them.
- **`.claude/templates/SUBTASK.template.md`'s parent link was one level short** and resolved to the
  wrong directory; a subtask created from the template now links its parent correctly.
- **`dev/rounds/` now ships** (empty), because the round templates write into it by name.
- **The tranche runner no longer logs `LANDED` for an issue whose landing was deferred.** It logged
  `LAND-READY (verified; landing deferred)` and then `LANDED` on the next line for the same issue.
  Each outcome now logs once, in its own branch. If you parse the runner's log, the duplicate is
  gone.
- **`process/GIT-HOSTING.md` now recommends setting the bare repository's HEAD at creation, and says
  the two forms are not interchangeable.** `git remote set-head <remote> <trunk>` against a bare
  repo whose HEAD points at a branch your first push never created **exits 0 and changes nothing on
  the remote** — the mismatch surfaces later as `HEAD branch: (unknown)`. Prefer `git -C <repo>.git
  symbolic-ref HEAD refs/heads/<trunk>` where you control the bare side. The guide also now states
  the absolute-path constraint the initializer already enforces.
- **`AGENTS.md` no longer says your precedence rule is already written.** It said precedence was
  *stated once* in `requirements/CORPUS.md § Precedence`; that section ships as a blank for you to
  fill. One precedence rule is the kit's and binds before you fill anything — where a contract sheet
  and any prose disagree, the sheet wins — and that is now said where it is authored.
- **Several shipped documents now match the tools they describe.** The archive threshold is
  documented as a constant declared at the top of the report script, not a value your adapter sets;
  the settings example no longer claims the initializer stamps any of its placeholders; the
  initializer's seeded running log teaches the dated `###` entry form its two readers key on; and
  the publishing helpers' messages describe what the code actually does.
- **A creation script no longer leaves a half-written card behind.** An option value containing `|`,
  `&` or `\` is written to the card exactly as given; previously it could abort the substitution and
  leave a partly-filled card and a `.bak` on the board under an id that was now burned. Cards are
  built aside and published whole.
- **A value-taking option with no value now refuses and names itself**, instead of failing with a
  shell error about a positional parameter.
- **`move-issue.sh --help` now succeeds and prints to stdout**, like every other tool in the kit.
- **The rotation tag and cutoff field are meaningful in `--keep-last` mode.** Previously the tag was
  built from the absent `--before` date, so a second keep-last rotation silently skipped tagging.
- **`check-board.sh` now refuses an unrecognised option instead of ignoring it.** It previously
  parsed no arguments at all, so a mistyped flag was silently dropped and the run reported a clean
  board — a caller scripting options against it got silence that read as success. It now exits
  non-zero naming the option, and answers a usage request. **Its drift verdict is unchanged: it
  still exits 0 whatever the board looks like.**
- **The environment template lists the whole notification path**, and the gitignore's own section
  names a producer for each entry — two entries that had none were removed, and the directory the
  brainstorming skill writes into your repository is now ignored.
- **The drift report's "what green means" no longer tells you to count lines.** A check with more
  than one reading prints each reading, and a reading whose subject is absent still prints, naming
  what was absent — so the number of lines is not the number of invariants and never was. Walk the
  invariant list instead.
- **The initializer's preflight is documented as what it is: a hand-listed minimum presence check,
  not a manifest check.** Behaviour is unchanged; the contract and the manifest previously promised
  coverage the tool never had. A file that travels but is not in the minimum is not caught.
- **The commit-attribution contract now states its two exemptions** — tool-generated subjects
  (merge, revert, autosquash) and the documented environment escape. Behaviour is unchanged; an
  implementation built from the old wording rejected every merge commit.
- **The rotation contract's "never create an index" is narrowed to the case that made it true:**
  refuse when the store already holds retired material (listing it as proof); creating an empty
  index is allowed when nothing has been retired yet.
- **The publishing operation's ahead/behind report is documented as conditional** on the trunk being
  checked out in the main checkout — as it has always behaved.
- **The CLI shape (usage always succeeds; unknown option refuses non-zero, naming it; one exit
  status across the tool set) is stated as binding every shipped command-line tool**, not only the
  creators.
- **The post-stamp placeholder census is described as failing, not refusing** — it runs after the
  initializing commit, so it reports a bad result rather than preventing one.
- **`dev/RETIRED.md` is documented as a path your project creates**, not a file the kit ships.
- **The short name a creation tool takes now has a declared shape** — lower-case letters, digits and
  single hyphens between them, starting and ending with a letter or digit. Anything else is refused
  at the door, naming the position and the character, and is never silently rewritten. *The shape is
  the intersection of what a branch name and a file name both accept, because the short name travels
  into both; the failure it prevents is an ACCEPTED name that produces an illegal branch discovered
  later by someone who did not type it.*
- **Specification identifiers: the creation contract now states its one declared exception** — the
  specification creator derives its own id; every other creator still refuses without one.
  `id-minting.md` gains § Spaces and streams, which separates WHAT an id names from WHO puts the
  number there, says what makes the exception safe (one author on that stream, so no concurrency
  hazard), and says when it lapses.
- **The rigor-tier sheet fixes the SHAPE of the effort riders, not their names** — a default per
  tier, an escalation above it that needs sign-off, a floor nobody dispatches at. The named settings
  are your project's, recorded in `model-provisioning.md` § B.2.
- **The placeholder census's span is documented as a floor** — it covers the stamped role docs and
  templates, the directories the initializer itself writes. A value that travelled into a file
  outside them is your own search to run.
- **`process/**` travels unedited, and its declared blanks are now named** — each doctrine sheet's
  instance section, the manifest's debt list, the hygiene checklist's evidence column, and everything
  under `process/templates/`. Read the old row literally and you leave all of them empty.
- **The adapter template's House rules gain an attribution example**, carrying the instruction to
  name the mechanism that enforces it in the same line.

- **The graduation check now runs on projects that never ran `kit-init`.** It enables on any sign
  the repository has started — work items on the board, history in the running log, entries in the
  archive, or the initializer's receipt — and on a tree with none of those it reports that **the
  check did not run**, rather than implying the tree is clean.
- **`doctrine/fix-execution.md` § A.5b decides when a fix must be a MECHANISM and when a SENTENCE
  will do.** The rule: *a mechanism is owed where the act is IRREVERSIBLE, or where the failure is
  SILENT AND COMPOUNDING; everywhere else, prefer the sentence.* Two tests discharge it — *can
  this act be undone?* and *if this goes wrong, does anything say so, loudly and soon?* — and
  **the burden of proof sits on the mechanism**, because a sentence is cheaper forever and a
  mechanism nobody can remove is a cost every future reader pays. `doctrine/subagent-control.md`,
  `doctrine/live-resources.md` and `doctrine/orchestration.md` previously stated their own
  versions of this trade and now point at the one sheet instead. **No Action required** — nothing
  you run changes; this is a rule you read when deciding how to fix something.
- **The no-census rule now says where it does NOT reach.** An enumeration is a census when it is a
  **claim** about a set — a guard's list, a sentence's list. **A builder's list is not**: a
  fixture that creates six directories is not asserting six is all there are. When the role is
  unclear, ask which way a divergence fails — loudly and near the cause, or silently. **No action
  required.**
- **Six shipped scripts carry one consistent phrase for the prefix-authority rule, and the block
  no longer states its own size.** `new-prd.sh`'s header used a plural form of the phrase the
  others share, so the `grep` those scripts tell you is the list did not return it — and the
  closing line said "change all five" beside a command that returned five. Both are fixed
  together: the phrase is identical in all six, and the closing line now says the grep is the list
  rather than counting it. **Nothing to do.** If you have scripted against the old plural phrase,
  it is gone; the singular one is the rule's name everywhere.
- **`doctrine/staleness.md` § C now covers enumerations, not only digits.** *"Three outcomes: A, B
  and C"* is a census in prose and rots the same way *"18 contracts"* does. State the axes the
  members vary along, or point at the instrument whose output is the list. **No action required.**
- **`verify.sh`'s guard floor is now reconciled in both directions.** A new `GUARD_ENUM` seam
  beside `GUARD_SET` names how your project enumerates its guards **as that command sees them**;
  the scoped run reports declared-but-vanished (as before) **and guards that exist and were never
  enrolled** (new), refusing on either. `GUARD_ENUM` is **executed**, and its output is compared
  to `GUARD_SET` as literal strings — emit the same path shape the list uses.
- **The self-test suite no longer fails on a project that declared its own role set.** If you ran
  `kit-init.sh --roles` to name your project's roles, the suite's sandboxes inherited that set and
  then judged the suite's own fixtures against it — so `move-issue.sh`, `archive.sh` and
  `release.sh` cases failed for reasons that had nothing to do with those tools, in the one
  instrument whose job is to be believed. The sandbox now resets the role set to the one the kit
  ships, across the same three files `--roles` stamps, so the suite tests the kit's frame and your
  declared set is left entirely alone outside it. **Nothing to do** — re-run the harness. If you
  have edited the suite's own cases and used a role name your project does not declare, that name
  is now judged against the kit's shipped set rather than yours.
- **The self-test harness no longer reports a false failure on a project whose trunk has grown.**
  Its helpers for reading the trunk piped `git log` into `grep -q`; under `pipefail` the
  early-exiting reader made the producer die of SIGPIPE and that became the answer, so an
  assertion could report a commit subject missing when it was present. The effect scaled with
  history — invisible on a young board, near-certain past about twenty-five commits — and it could
  only ever produce a false red, never a false pass, so nothing was wrongly certified. **No action
  required.**
- **`scripts/hygiene/cold_signal.py` tells you why it cannot run, instead of raising.** It reads
  your working copy's own git history, so on a tree that is not a repository — an unpacked
  release, an export, a clone you have not `git init`-ed — it used to end in a Python traceback.
  It now says **could NOT RUN**, names the command it tried, quotes git's own message, gives the
  remedy, and exits 2. **The distinction it is protecting: this is not "no cold files"** — the
  instrument never ran, and an unrunnable check is an unknown rather than a clean result. With
  `--json` it prints an object saying it did not run, with **no** rows/files/bytes keys, so a
  consumer that ignores the exit status fails loudly rather than reading a zero. **Nothing to
  do**: on a normal repository the report is byte-for-byte what it was.
- **The kit's tooling floor is stated more precisely, and two extras are named deletable.** The
  floor read *git and a POSIX shell, and nothing else* — an absolute the tree already
  contradicted, because `scripts/hygiene/` is Python and `brainstorming` has an optional Node
  companion. What the kit **requires** is unchanged: git and a POSIX shell, for everything that
  gates. What is now said out loud is that the hygiene instruments are **Python 3, standard
  library only, advisory, and never a gate** — *delete the directory if your project forbids
  Python and you lose the measurements, not a gate*; `process/hygiene-checklist.md` states every
  shape in prose, so each is re-implementable in whatever you already run. Say so in your adapter
  if you do forbid it, the way the skill set already handles its one optional Node dependency.
  **Nothing to do**: no gate, command or refusal changed, and if you have been running the
  instruments they still run.
- **Some shipped files carry no `KIT-CLASS:` marker, and the convention now says so.** It used
  to read *"every script, role doc and process file carries a one-line marker"* and *"classify a
  file by opening it"* — with no exceptions stated, while three kinds of file had them. Now the
  rule names them and says where each one's class actually lives: **vendored skill directories**
  in the new `Class` column of `.claude/skills/README.md`'s provenance table, because updating a
  skill from upstream is a folder copy that would erase an in-file marker; **`process/KIT-VERSION`**
  nowhere, because its entire content is the value the release ritual reads; and
  **`.claude/settings.json.example`** in a `_KIT_CLASS` key, because JSON has no comment syntax.
  Nothing in your tree changes and nothing is reclassified — **the rule caught up with the tree**.
- **The pre-cut sweep is now a required step of the release ritual, not an advisory habit.**
  `contracts/release-ritual.md` § 2 requires it where a slate was minted from findings, with a
  named owner, before the version is written; § 3 refuses without it and § 4 item 6 makes it
  observable. **Required does not mean automated** — the sheet says why mechanizing it is held
  back. `MANUAL.md` and `EXTRACTION.md` no longer describe the hygiene checklist as *"advisory,
  never a gate"*: the **cadence** is advisory, the **sweep** is not.
- **`--json` on the hygiene instruments now carries the walk's blind spots**, the same ones the
  human output prints. `citation_index.py`'s payload changes shape to carry them: it was a bare
  array of rows and is now `{"blind_spots": […], "rows": […]}`. The other four instruments
  already emitted an object and simply gain a `blind_spots` key. **Nothing in the kit reads this
  output**, and the instruments are advisory — so this is a one-line notice rather than an
  action. **If you have written a consumer of `citation_index.py --json`, it reads
  `payload["rows"]` now.** That shape is stable from here: the wrapper was added while the
  consumer set was empty precisely so it would not have to be added later.
- **Every hygiene instrument now reports what its walk did not look at.** Until now **none of
  them did** — the five share one file walker, that walker narrows twice, and no report
  mentioned either narrowing. Both are now stated, on the human path and in `--json`, derived
  from the walker itself so a new narrowing reaches every report the day it is added: **symlinks
  are skipped** (a symlinked file is absent from the walk entirely, with the count of how many
  were skipped in that run) and **the directory names in `SKIP_DIRS` are pruned wherever they
  appear**, plus any `*.egg-info`. **No instrument's results change** — the walk is what it
  always was; what changes is that a clean report now tells you what it did not read. If you
  have edited `SKIP_DIRS`, the count in the line follows your set. **Whether the scanner should
  FOLLOW symlinks instead of skipping them stays open** — naming the skip is what makes leaving
  that open honest rather than silent.
- **`.gitignore` now ignores the hygiene instruments' Python bytecode.** `scripts/hygiene/` is
  Python, and a bare `python -c` import or a REPL session writes `scripts/hygiene/__pycache__/`
  beside it — residue that reddens a guard walking `scripts/` for `KIT-CLASS` markers while
  `git status` stays clean (`citation_index.py`'s own header). `__pycache__/` and `*.pyc` are in the
  kit's own section of `.gitignore`, not the FILL ME build-artifact section, because a cache written
  by a file the kit ships is not your build artifact. Nothing to do; if you have already edited your
  copy, add the two lines whenever you next touch it.
- **The self-test suite covers the day-one path the documentation prints.** `GIT-HOSTING.md` § 3
  step 2's first commit has no role prefix and runs with the hooks unwired — the state that made a
  correct install fail its own self-check. The suite now runs `kit-init` that way and asserts it
  succeeds, that the board check is not what fails, and separately that a **real** board finding
  still does fail it, so "tolerate more" can never quietly become "check nothing". **No action
  required.**
- **`finish-pr.sh` names the trunk on its green line.** The human-readable post-merge verify line
  now reads `PASS on <trunk>` as its FAIL sibling always did; the machine-readable
  `POST_MERGE_GATE: PASS|FAIL` pair is unchanged, so anything keyed on it keeps working. **No action
  required.**
- **Shipped scripts and workflow runners no longer cite the kit repository's change files.** Six
  comments and one prompt string handed to your agent at runtime referred to `change NNN` — a record
  that exists in no repository you have. Each now states the reason it stood for. The self-test
  harness carried the last of them, removed with the guard that now refuses the whole class at
  build time. **No action required.**
- **The `dev/` index discipline names its granularity.** Every file and subdirectory under `dev/` is
  reachable from exactly one row — the file's own for a loose file, **the directory's** for a split-out
  directory, whose README then indexes its members. `dev/handoffs/` no longer asks for a row per
  handoff: its dated filenames are its member index. **Action required: none** — if you already had
  per-handoff rows they remain correct as an index of your own; the rule no longer requires them.
- **The drift report's advisory arms now carry a machine-readable token.** An arm that reports
  without deciding the verdict writes the literal `reports only` in its own header line, and
  consumers may key on it — `contracts/drift-report.md` § 4 item 5. `kit-init`'s self-check also
  stopped discarding findings an arm prints on its own header line, so an over-threshold column
  fails the self-check again as it did before the advisory arms existed.
- **`kit-init`'s self-check no longer fails on the first-commit subject the kit's own git-hosting
  recipe prints.** It decides on the drift report's verdict line, tolerates only role-prefix
  findings on commits that predate the run, and shows the rest of the report as context. Before
  this, following `GIT-HOSTING.md` § 3 to the letter — an unprefixed `init` commit, hooks wired
  after — made the initializer refuse a correctly initialized tree, naming the graduation arm as
  the cause. Nothing to do: the fix only makes an install succeed that previously refused, and
  `kit-init` refuses a second run on an initialized tree anyway.
- **The self-test suite gains nine cases, and three of them read your tree rather than a sandbox.**
  Most of the suite builds a throwaway repository and tests the kit's machinery inside it. Three of
  the new cases instead read what you actually ship: that no skill states a forge command as an
  instruction rather than as a named example, that the upstream product name survives only where
  renaming it would falsify a true statement, and that `dev/README.md` names every subdirectory
  carrying its own README. **These can go red on content that is yours to edit, and that is the
  intent** — each names the file and the line it means. If you have taken the optional forge flavor
  and written your forge's command into your own copy of a skill, mark it as your project's declared
  example or drop that case; the case's own message says which line it means. **No action required
  otherwise.**
- `scripts/test/run.sh` is classified **MIXED**, not KIT: the sandbox frame is the kit's, and any
  case family that pins your project's own facts is yours to edit or drop. The contract sheet and
  the extraction manifest already said so; the file's own marker now agrees with them.
- **A change whose operands straddle the two commit lanes is now a named case with a rule.**
  `process/doctrine/commit-hygiene.md` gains **§ A.5**: where a guard and the record it reads — or
  a declaration and the ceiling it is held against, or a procedure naming two artifacts — sit in
  different commit lanes and are only jointly satisfiable, **the unit the gate is being asked
  about is the SET, not the file**, and the invariant is **ALL-OLD or ALL-NEW, never MIXED**. The
  branch run is the only proof of ALL-NEW; the trunk is *expected* to be ALL-OLD until the merge,
  and a report calling that window a breach teaches its readers to ignore the report; the
  post-merge run is a **detector, never a gate**. It also states the thing a project would
  otherwise go hunting for: **a straddling guard cannot be made true on the trunk, and no
  mechanism removes that** — what is law is the compensator set, and two of those already ship
  here (the landing script's post-merge check, a detector by construction; the drift report's
  rule that every check names the source it read), so they are cited rather than restated.
  Nothing you already do becomes wrong, and no command, flag, path or refusal changes. What
  changes is that a straddling set now has a name and a rule where the kit previously gave you no
  way to say what was wrong. **No action required.**
- **`process/doctrine/fix-execution.md` § A.2 now asks whether a ruling has ever been executed.**
  A rule nothing has yet had to obey is **untested**, and its record says so — because the
  instances that accumulate under an unexecuted rule are retrospective, and retrospective
  instances look exactly like compliance. One bullet. **No action required.**
- **`lookup-tables.md` § A.5 and `instruments.md` § A.6 now point at each other.** Two readers
  took them for a contradiction — one tolerates a hand-kept index guarded in a single direction,
  the other says a reconciliation must print the difference **both** ways. They are two axes, not
  a disagreement: § A.5 decides **whether you owe** the reconciliation, § A.6 decides **what it
  must print** once you build one. Each now says so where the other reader lands.
- **`EXTRACTION.md` § 2.2 and § 2.4 are now tables, and the tables are the counts.** The status-folder
  carriers and the role-set carriers are each listed with what they hold; § 2.2 distinguishes the
  files that carry the lifecycle as a set from the ones that hold only the fixed endpoints of their
  own transition, and carries a divergence column because `subtask.sh` omits `done` and `setup.sh`
  adds `history/`. § 1.1's day-one table gains `.env.example` and `.gitignore`. The adapter template's
  parked-role paragraph now says what adding a role actually touches — every carrier § 2.4 lists —
  and that parking touches none of the scripts by design.
- **The self-test harness now runs green in an initialized project.** It previously reported one FAIL
  and exited 1 for every adopter who completed § Day one and then ran `./scripts/test/run.sh` as the
  kit instructs: the sandbox inherited your stamped issue prefix in `.claude/templates/` while its
  config was reset to the shipped one, so the initializer had nothing to substitute inside the
  sandbox. Nothing to do — re-run the harness. **One limit, stated because it is measured:** a project
  that also ran `kit-init.sh --roles` to declare its own role set is still red, for a different and
  unrelated reason the harness names in each failure (`--role must be …`); that is tracked separately
  and is not fixed here. **One new refusal:** if `.claude/templates/ISSUE.template.md` carries neither
  the shipped `<PREFIX>` placeholder nor your stamped prefix, the run now aborts with a FIXTURE FAILURE
  naming the file, instead of a case failure that reads like a defect in `kit-init.sh`.
  `process/contracts/self-test-harness.md` § 2 now carries the invariant behind all of this, so a
  project with its own harness is held to it too.
- **The shipped skills stop naming the upstream product where nothing depends on the name** —
  `executing-plans`, `using-superpowers` § Instruction Priority and `finishing-a-development-branch`
  § Step 6 now read in the kit's own terms, and a worked example's `~/.config/…/hooks/` path is a
  blank instead of that tool's real one. **Two dependencies are kept on purpose, and each says so
  where you will read it:** `~/.config/superpowers/worktrees/` stays exactly as written, with a
  sentence in `using-git-worktrees` § Directory Selection explaining that it is an external tool's
  directory these skills *adopt* where it already exists rather than create (a worktree is made
  inside it; the directory itself never is) — renaming it would send the check looking for a
  directory nothing creates; and the upstream repository link in the companion's page header stays
  as provenance, because a skill whose origin nobody can name is a skill nobody can safely update.
  The `using-superpowers` skill directory keeps its name for now — renaming it breaks every path that
  cites it. Also: `references/gemini-tools.md` drops two sentences that contradicted the file's own
  corrected statement, keeping the live instruction inside them.
- **`contracts/initializer.md` § 2 gains a hard invariant** — a substitution names the space it
  rewrites, and a convention's key is not in it; any census of surviving placeholder residue exempts
  those keys in the same change. **`contracts/config-seam.md` § 4 item 3** names the same exemption
  beside the provenance-citation one. If you implement your own initializer, these are new obligations
  you already needed and could not read anywhere. No action required — the code half shipped earlier.
- **`release.sh` prints where the release actually is, before it pushes.** Between the annotated tag
  and the two pushes it now states — as ordinary output, on a healthy run — that the bump, the
  release commit and the tag exist in your clone and **nowhere else**, the two `git push` commands
  that finish the cut, that each of those is safe to re-run while **re-running `release.sh` is not**
  (the tag exists now, so preflight 1 refuses), and the two commands that abandon the cut instead. A
  completed run is unchanged apart from the extra block; a run **killed** in that window used to
  leave a transcript asserting a release commit and an annotated tag with nothing saying neither had
  been pushed. `process/contracts/release-ritual.md` § 2 now carries this as an invariant, so a
  project with its own release implementation is held to it too. No action required.
- **`move-issue.sh` no longer creates the kanban worktree just to tell you a card id is wrong.** The
  existence check now runs first, against the trunk ref itself, so a mistyped id refuses and leaves
  nothing behind — and the refusal says which tree it read. It can only refuse: an unreadable
  tracking ref, a trunk carrying no `progress/` board, or a glob passed where an id belongs all fall
  through to the old path unchanged, and a miss is re-read after a fetch, so a card another operator
  has just pushed is never reported as missing. `contracts/board-mover.md` § 2 states the rule behind
  it: a refusal decided from the invocation alone leaves nothing behind, and one that depends on
  board contents must at least try to. Nothing to do.
- **`receiving-code-review`'s thread-reply section is no longer GitHub-only.** It was headed *GitHub
  Thread Replies* and stated the rule as a `gh api …/replies` invocation — the one place the kit's
  own skill set told you to run a forge CLI, in a kit whose landing path is deliberately pure git. It
  is now headed **Replying in a Review Thread** and states the rule that travels: reply **in the
  thread you are answering**, never as a new top-level comment; the mechanism is your forge's, and
  GitHub's CLI is named as one example. It also covers the path this kit gives you out of the box,
  where the review record is a file in the repository and there is **no forge object at all** —
  answer at the finding, not in a new section at the bottom. **Nothing to do**, unless something of
  yours cites the old heading. If you re-copy this skill from upstream, `skills/README.md` now says
  why the local wording differs and which way the merge goes.
- **`process/doctrine/lookup-tables.md` § A.1 now names the read-time exemption's shipped dependent,
  and scopes "triggers nothing however large it grows" to the size axis.** Two things a reader of
  that paragraph could not see. First: at least one shipped doctrine sheet already sits above the
  byte trigger and owes no index **solely** through the exemption, and nothing in § A.1 said so — an
  editor narrowing the rule was one edit away from landing an index obligation on a real sheet.
  § A.1 now says it, names `wc -c process/doctrine/*.md | sort -n` read against the trigger as the
  way to find *which* sheet (derived, not stored), and requires **a sheet that crosses the trigger
  to carry one line in its own header naming the exemption**; `process/doctrine/instruments.md`
  carries that line. Second: *"triggers nothing **on the size axis**, however large it grows"* was
  grammatically absolute while its qualifier scoped it to size, so a hurried reader could take it as
  beating the role trigger above it. It does not: **a role doc that makes a sheet a mandatory read
  removes the exemption's premise**, so the role trigger applies to it like any other file. **The
  policy is unchanged in both cases.** No Action required — unless one of your own doctrine sheets is
  over the trigger, in which case it owes that one header line.
- **`CLAUDE.md` now ships as a bootstrap stub, not as a pre-filled adapter.** A fresh unpack's
  `CLAUDE.md` says the project is not set up yet and sends day one to `process/SEED.md`; you build
  your adapter from `process/templates/CLAUDE-adapter.template.md` and **overwrite** the stub.
  `README.md` and `CLAUDE.md` both carry a `BOOTSTRAP-SCAFFOLDING` line that goes when the file is
  replaced. `AGENTS.md` now says which of the two states you are in. See § Action required if your
  adapter predates this release.
- **`MANUAL.md`'s session-close ritual now names one more state, and § The kanban worktree stops
  over-promising.** At session close, the **local trunk ref must not be ahead of
  `<remote>/<trunk>`** — everything the process commits direct to the trunk (rulings, specs, board
  edits) lands there, so an `ahead` is work nobody else can see. The ritual cites `check-board.sh`
  arm `[f1]`, which already makes exactly that reading and prints the push command, so there is
  nothing new to run: the bullet writes down what your drift report already enforces. It deliberately
  asks nothing about `HEAD` — a dispatched leg legitimately holds the checkout on a work branch, so a
  HEAD-vs-trunk comparison would redden on every orchestrated run — and `behind` is a stale view
  rather than a finding. Separately, § The kanban worktree's claim that `check-board.sh` *"surfaces
  the divergence"* now carries the span the arm itself prints: it counts commits reachable from a
  ref, so a commit reachable from **no** ref at all — an orphaned sibling, left behind when `HEAD`
  moved — is outside that measurement and would need the reflog. The check has not changed; the
  manual has stopped implying it covers a case it never did.
- **A second file axis: disposition.** Alongside `KIT-CLASS:` (does this travel?),
  `process/EXTRACTION.md` now names what state each file must reach before day one is done — KEEP,
  STAMP, FILL, REPLACE, SEED, DELETE-IF-UNUSED. The one that changes behaviour is **REPLACE**:
  `CLAUDE.md` and `README.md` are scaffolding to be thrown away and rewritten, not edited into shape.
  The marker-strip rule is stated with it: strip `KIT-CLASS:` where a file's class has become
  `PROJECT`; keep and re-mark it where the file stays `KIT` or `MIXED`.
- **`doctrine/fix-execution.md` § A.9's never-edit rule gains its missing half.** A supplied document
  that arrived corrupted in transit (mojibake, stripped bytes) may be repaired **mechanically**, with
  the raw bytes preserved beside the repair so the transformation is a diff anyone can run rather
  than a claim anyone must trust. Before this, the rule was an absolute that told you to preserve a
  corrupted document forever — which nobody would do, so it would have been broken silently instead
  of amended openly. Nothing to do unless you hold a corrupted supplied document; if you do, repair
  it this way.
- **`archive-progress.sh` gains an ordinal knife, an index, and a new exit code 3.** Its trigger is
  measured in **bytes** and its only selector cut in **days** — so under load the threshold is crossed
  two or three times a day while the date knife can fire once, and the second run answers *"Nothing to
  archive"* because the first already took everything before the boundary. **The tool's success was
  what made it inert.** Now: `--keep-last <N>` cuts by count and can be re-run the same day; and when
  nothing matches your selector **while a rotation is still due**, it says so, names the measurement
  against the threshold, and **exits 3** instead of reporting success. *"Nothing to archive"* is now
  reserved for when it is true — under threshold, exit 0, unchanged wording.
- **Rotation now maintains `progress/history/INDEX.md`** — one row per chunk with the span it covers,
  newest first, no row ever rewritten. This was already required (*"the same **preserve-and-index**
  rules"*), and the script's own header had recorded the deviation as a design choice: *"chunks are
  discoverable via `ls`."* They were not: `ls` gives filenames with no spans, so finding a date meant
  opening chunks until one matched.
- **`process/doctrine/fix-execution.md` § A.9 now requires supplied documents to be COPIED IN before
  anything cites them.** *A citation into a document you do not control is not a citation, it is a
  hope.* If a findings round is fed by another team's feedback file, an attachment, or a report
  pasted into a conversation, **that document is an operand** — copy it into your repository verbatim,
  date it by the day it was supplied, and never edit it (later feedback is a **new dated file**). A
  supplied document that cannot be recovered is **named as missing**, beside the ones that were,
  because a missing input nobody names reads exactly like an input nobody needed. Filed under
  § A.5b's second half: nothing breaks at mint time, every citation looks fine in review, and the gap
  surfaces only when an implementer opens a path that is not there.
- **`verify.sh` now has a FOURTH result state — UNRUNNABLE — and prints what it ran.** A gate whose
  command could not start (`127`/`126`) used to be reported as **FAIL**, which is red in the right
  direction and destroys the one distinction that matters: *"could not start"* versus *"your tree is
  broken."* The two are now separate words, and the unrunnable branch prints the interpreter path and
  the root it resolved against, so the diagnosis is where the confusion is. **The summary now carries
  counts** — declared, ran, passed, failed, could not run, skipped — and `ran` deliberately **excludes**
  the unrunnable, because a command that never executed did not run. *(That last point was caught by
  the change's own reddening control, which first printed `ran: 3` when one of three never ran.)*
- **A gate command with a relative interpreter path is no longer silently location-dependent.** It
  used to resolve against whichever root the runner stood in — so it worked in the main checkout and
  was unrunnable from a linked worktree, **which is exactly where a trunk gate has to run.** A runner
  that cannot answer from there does not have one canonical entrypoint; it has one per location.
- **`check-board.sh` now reads `<remote>/<trunk>` by name, and every verdict says what it read.**
  Previously most arms read *whatever checkout was current*, so a colleague or an agent holding the
  repository on a feature branch silently changed the board report's answer. Each arm now names its
  source (`read from: origin/main @ <sha>`), and where no trunk ref exists — day one, a local-only
  clone — it falls back to the working tree **loudly**, printing `⚠ NOT A TRUNK REPORT`. It does
  **not** fetch: it reads the remote-tracking ref as it stands, labels it with its sha, and prints
  the refresh command, because a hang at session start is worse than a dated answer.
- **A check that cannot run now says SKIPPED and why, instead of printing green.** An absent column,
  an unresolvable revision or an empty history previously fell through to a pass over zero inputs.
  **Expect to see new SKIPPED lines where you used to see ticks** — the ticks were the bug.
- **The divergence check now covers EVERY home your process publishes from, each named separately.**
  It used to watch only the board mover's auxiliary worktree, so an unpushed commit in your **main
  checkout** — which is where rulings, PRDs and board edits are written — was invisible. It now
  reports each home with its own reading, and states its span: it measures commits reachable from a
  ref, and says so, because a commit reachable from no ref at all is outside what it can see.
- **`process/doctrine/lookup-tables.md` § A.1 states the real basis for the doctrine-sheet
  exemption.** It said a doctrine sheet crossing the byte threshold triggers nothing *because
  "condition 1 is unmet"* — but condition 1 names `process/MANUAL.md`, and **MANUAL's doctrine table
  names every sheet by path, so condition 1 is met.** The exemption is correct and its stated reason
  was not: a doctrine sheet is exempt **by how it is read** — addressed on demand, never loaded at
  session start — not by failing a condition. **The policy is unchanged**; only its reasoning is,
  and the wrong reasoning was one edit away from someone removing the exemption instead of re-basing
  it.
- **`kit-init.sh --gate-command` now FILLS the shipped gate runner's empty table** instead of
  refusing because `scripts/verify.sh` already exists. The seed ships `verify.sh` as a frame whose
  `GATES` table is empty and which refuses to run until you declare a gate — so the day-one command
  in the README refused on every fresh copy, while the frame's own header told you to run the flag
  that refused. Now: no `verify.sh` at all ⇒ a minimal single-gate runner is written; the shipped
  empty frame ⇒ your command is written into its table as the first record (`"gate|core|<cmd>"`);
  a table that already declares a gate, or a runner that is not the frame ⇒ refusal, because that
  file is yours. A gate command containing `|` or `"` is refused: the record format cannot carry
  either — put it in a script and name the script.
- **The kit's own version and release notes moved out of the repository root** into
  [`KIT-VERSION`](KIT-VERSION) and this file. A root `VERSION` file describing the *kit* is a trap
  in a project that has its own product version — `release.sh`'s `VERSION_FILES` seam would
  happily bump it.
- **[`doctrine/live-resources.md`](doctrine/live-resources.md) § A.6 is stronger:** reclaim by
  **enumerating the container**, never by replaying a registry of what was created — an enumeration
  cannot miss what the creating leg forgot to register, and a registry always can. Two corollaries
  come with it: anything created outside the enumerated container is invisible to the sweep and
  handled by name, and anything you cannot delete is **named, not quietly left**. Sharpened from a
  dogfooding round, where the creating party is a participant rather than the harness.
- **[`doctrine/calibration.md`](doctrine/calibration.md) and
  [`doctrine/negative-claims.md`](doctrine/negative-claims.md)** gained the cross-references that
  place the two new sheets in the family: calibration names the round as its third ritual and says
  what each of the three does *not* answer; negative-claims names instruments as its upstream
  neighbour — that sheet asks whether a claim is grounded, this one whether the check behind it can
  see anything at all.
- **[`contracts/retention-completeness.md`](contracts/retention-completeness.md) is now marked
  deliberately non-travelling.** Its § 6 named `scripts/githooks/pre-commit` as its reference
  implementation and the kit ships no such hook — `githooks/` carries `applypatch-msg` and
  `commit-msg` only. **That sheet is a spec you implement, not a gate you inherit**;
  `contracts/README.md`'s row and [`doctrine/retention.md`](doctrine/retention.md) § A.5 now say so,
  and the adoption checklist that asks you to name your guards now states that **both are yours to
  write and the kit ships neither** — an unnamed guard you never wrote is indistinguishable from one
  you have. **If you went looking for that hook in your copy and could not find it, this is why** —
  nothing is missing from your tree.
- **The shipped Dev skills no longer reference a foreign plugin namespace.** Those references named
  skills this kit does not ship, so they could never resolve — and `writing-plans` instructed every
  plan to carry the namespaced header, so the bad references grew with every plan written. **One
  skill's option set changed as a result: if you have anything reading its old option numbers, re-read
  it.** A harness case now finds a planted namespace reference, so the class cannot come back quietly.
- **[`templates/CLAUDE-adapter.template.md`](templates/CLAUDE-adapter.template.md) gains the three
  tables the rest of the kit binds on** — roles, role-attribution commit prefixes, and the
  code-vs-metadata glob declaration with its carve-out. **Which shape is law is per disposition**: for
  REPLACE-class files (`CLAUDE.md`, `README.md`) the template is law and the shipped root file is
  scaffolding; for FILL and SEED files the in-place instance stays law. The defect this closes was not
  really omission but a **broken citation**: `AGENTS.md` anchors into `CLAUDE.md` § "Role-attribution
  commit prefixes" by section name while the `commit-msg` hook enforces that set, so an adapter written
  without it carries a dangling anchor **plus** an enforced-but-unspecified seam — and that bites on
  the first commit, not later. **See Action required if you wrote your adapter from the older
  template.**
- **The `autoMode` block and the `plansDirectory` value are gone from `.claude/settings.json.example`.**
  Nothing in the kit read either, and `autoMode`'s `allow` / `soft_deny` / `environment` arrays held
  **English sentences rather than tool patterns**, so no permission engine could have enforced them
  under any key name. It enforced nothing and guided nobody while reading exactly like active
  authorization policy, which is the worse of the two failures. **If you copied the example verbatim
  and believed `autoMode` was authorizing direct-to-trunk work, it never was** — the trunk policy has
  one home, your adapter's § The trunk, the branches, and what counts as code here. The file now
  carries a short note recording that both keys were removed, so their absence is not read as an
  omission.
- **The rotation tool's header no longer calls `##` the modern log-entry form.** The **dated `###`
  session heading is the form the kit documents.** `archive-progress.sh` still matches `##` so a
  project that already wrote it is not stranded — accepting a form you no longer document is the
  forgiving direction — but **do not migrate toward it**: `check-board.sh`'s § Log size arm and
  `kit-init.sh`'s already-lived probe both scan to the next `##` and stop, so a `##` dated entry
  **terminates the § Log section it is supposed to sit inside**. Measured: the size arm then reports
  healthy forever, and the lived probe counts zero lines and reads a working repository as new,
  defeating the initializer refusal that is supposed to be made by a rule rather than by the operator's
  memory. The old wording is kept in the header beside the correction, with what it cost.

### Added

- **New doctrine sheet — [`doctrine/subagent-control.md`](doctrine/subagent-control.md).**
  Commissioning work you cannot watch, and believing the result: the adversarial brief, the
  contradictory-demand pair that returns nothing rather than a compromise, a report that carries its
  own evidence, resume-safety, deferred decisions named inside the item that touches them, and
  handing off while sharp. Increments land in
  [`doctrine/model-provisioning.md`](doctrine/model-provisioning.md) (an unset provisioning knob is
  an *inheritance*, not a default), [`doctrine/live-resources.md`](doctrine/live-resources.md) § A.5
  (the two shapes a self-report fails in), [`../dev/handoffs/README.md`](../dev/handoffs/README.md)
  (when to write one) and
  [`templates/launch-pack.template.md`](templates/launch-pack.template.md) (an ordering clause names
  its consequence, not just its sequence).
- **Dogfooding doctrine — a third measurement ritual.** [`doctrine/dogfooding.md`](doctrine/dogfooding.md)
  covers running a **round**: putting agents or people in front of what you shipped, as consumers,
  and grading what happens. It asks *does a competent stranger, holding only what ships, get where
  they were going?* — a question no gate can answer, and whose findings are mostly about **words**
  (documentation, error text, naming, defaults). It ships with its own document pair,
  [`templates/round-pack.template.md`](templates/round-pack.template.md) (a **pre-registration**:
  the question, the scenario matrix, the instruments and their blind spots, the budget — all
  committed *before* the round runs, because a budget written afterwards cannot fail and so is not
  a limit) and [`templates/round-report.template.md`](templates/round-report.template.md) (findings,
  positives, and the round's own defects).
  **A run delivers work; a round measures how the delivered thing is met** — keep the two words
  apart. The round is staffed from the existing cast: PM owns the question and every remedy, the
  Orchestrator delivers and dispatches in isolation, QA re-verifies and grades cold, and a second
  leg attacks the consolidation. **No new role, no new prefix, no gate.**
- **Instrument doctrine.** [`doctrine/instruments.md`](doctrine/instruments.md) — *an instrument is
  believed only when it has been watched failing.* Measure it against the shape it will actually
  meet rather than the fixture its author wrote; **every green owes an ablation**, because absence
  of the wrong thing never establishes presence of the right one; sometimes a capability probe is
  itself the defect (it turns a deleted check into a SKIP instead of a FAIL) and that choice is
  recorded; and every instrument's blind spot is named **in its own output**. This one binds every
  guard author, not only whoever runs a round — its § C worked example is the kit's own self-test
  harness. *(An earlier version of this note said § C cited three places the kit was breaking its own
  new rule. It did — and all three were fixed within a phase, which is why § C now cites the
  harness's DESIGN rather than its bugs. Corrected 2026-08-27.)*
- **[`MANUAL.md` § The measurement rituals](MANUAL.md)** now names all three — regeneration spike,
  seed acceptance test, dogfooding round — as one family: **available, never obligations**, reached
  for on a condition rather than a schedule, all producing findings rather than code, and all
  handing those findings to a real PM session rather than minting work items themselves.
- **`kit-init.sh` refuses a relative filesystem remote URL**, printing the one-line fix. The kanban
  worktree runs git from `.kanban-wt/`, one directory down, where a relative `origin` resolves
  somewhere else — previously that surfaced two steps later, mid-self-check, disguised as an
  access-rights error.
- **New doctrine sheet — `process/doctrine/fix-execution.md`.** The phase between *"we have
  findings"* and *"we cut a release"*, which the kit modelled at neither end: scrutinize the slate
  before implementing it (one fresh-context reviewer per item, four questions, **read-only**, and
  holding an item is a success); record a ruling **before** executing it, verbatim, with what was
  explicitly *not* ruled beside what was; carry the round's own traps as **acceptance criteria**
  rather than advice; sort candidate fixes by *"is there a decision here"*, never by size; budget a
  gate on a **property** (CPU time, work units, counts) and never on wall-clock; treat every claim
  about remote state as a **dated reading**; and give every vocabulary the process uses about itself
  **one authoring site** with everything else derived from it. Increments land in
  `process/templates/DECISIONS.skeleton.md` (a ruling about to be executed owes three more things
  *inside* its existing three fields, plus a tree stamp on its citations), `doctrine/staleness.md`
  (§ C — finding the statement you just outran is a one-hop search, owed in the same change) and
  `doctrine/live-resources.md` § A.4 (a consent id authorizes one item's spend, so a full-suite run
  is its own budgeted decision). **Nothing to do to adopt it:** no command, flag or file changed,
  and the template additions are guidance inside templates you already own.
- **`process/doctrine/instruments.md` is now in two parts, with a visible seam.** The sheet used to
  treat every guard failure as one thing. It is two, and the difference decides the fix: **Part One
  (build time)** is *the instrument is misaimed, or cannot fail* — it binds whoever **builds** the
  instrument, and the remedy is to change the instrument. **Part Two (read time)** is *the instrument
  is right and the reading is wrong* — it binds whoever **consumes** the result, and the remedy is to
  change the reading. **Applying Part One's remedy to a Part Two failure sends you to re-aim an
  instrument that is already correct.** A ruled seam between the two says in terms that a guard author
  who stops there was right to. New in Part One: assert the fact rather than the sentence that states
  it; the operand set at four scales; building a prose guard (normalised text or an AST, never raw
  lines — then the region, then honesty about the remainder); and **§ A.8, a green that could not have
  gone red**, which now owns the two shapes of verification theatre and the rule that *a checker
  rejecting a valid input for a reason unrelated to correctness is worse than no checker, because it
  trains you to ignore it.*
- **`process/doctrine/negative-claims.md` § A.4 — a detection recipe offered inside a ruling is a
  negative claim, and owes both halves.** Run it against the tree that still holds the known
  instances and record the count; state its blind spot or say it has none. Prefer the property to the
  string. The worked instance is a ruling whose own grep returned several hits, **not one of them
  either survivor.**
- **[`MANUAL.md` § The fix-execution phase](MANUAL.md)** carries the two steps the lifecycle did not
  otherwise have — scrutiny before implementation, and the pre-cut sweep before the cut — marked
  **mandatory when the slate came from a round**, which is why its heading states its own obligation
  status rather than sitting silently beside the optional rituals above it.

### Fixed

- `EXTRACTION.md` § 1.1 listed a `githooks/pre-commit` the kit does not ship and omitted
  `githooks/commit-msg`, which it does — in a section whose own rule is that counting its list is
  the census.
- `.claude/skills/README.md` no longer states skill counts as digits; the directory listing is the
  count, per the kit's own *derive, date, or do not state* rule.
- **`kit-init.sh`'s prefix stamping no longer rewrites the `KIT-CLASS:` marker key.** With a
  non-default `--prefix`, the substitution matched the marker's own **key**, so every shipped file it
  touched came out reading `<!-- <PREFIX>-CLASS: KIT — … -->`: the key rewritten, the value left, a
  line that refutes itself, and a `grep KIT-CLASS` over the initialized tree finding nothing. The
  `KIT` in `KIT-CLASS:` is **the convention's own word**, not your issue prefix — it only looked like
  the prefix because the shipped placeholder prefix is also `KIT`, and that collision was the whole
  bug. The key is now a constant behind a substitution sentinel, the placeholder census excludes it,
  and the initializer's self-check asserts the shipped markers survived stamping. **See Action
  required: this stops future defacement and does not repair a tree already stamped.**

### Action required

- **If your commit subjects begin with the word "Squash" without a role prefix, they will now be
  refused.** The exemption is narrowed to git's own `Squashed commit of the following:`; prefix such
  subjects, or use the documented override for an imported commit.
- **Creation now refuses a short name outside the declared shape.** If your automation passes slugs
  containing spaces, upper case, underscores, dots or slashes — or a leading, trailing or doubled
  hyphen — those calls now refuse, naming the position and the character, and create nothing.
  Previously a space was accepted and produced a branch name that is not a legal git reference,
  discovered later by someone who did not type it. **The name is never rewritten for you.** *This is
  the script-side behaviour line; the rule itself, and its wording, are covered by the contract's
  own release line.*
- **If you ran the initializer with `--roles` before this release, check your subtask tool.** It was
  outside the set of files the role set was stamped into, so its `--role` whitelist may still name
  the shipped roles and refuse yours. Re-running `--roles` stamps it.
- **Action required:** if you adopted via `SEED.md` step 2 **branch B** (you implemented the
  contracts in your own toolchain and never ran `kit-init`), the graduation report now runs
  against your published trunk and will list any shipped scaffolding you still carry. **Its
  findings are advisory** — they do not change the drift verdict and cannot fail a build. On a tree
  with no sign of having started, it says so: **the check did not run**, rather than implying the
  tree is clean.
- **The hygiene instruments now refuse instead of reporting, when their own blind-spot derivation
  comes back empty.** Every instrument exits **2** and prints `could NOT RUN … NOTHING was
  measured`; on `--json` it emits `{"unrunnable": {…}}` with **no data keys** — no `rows`, no
  `blind_spots`. **Action required:** if anything of yours consumes these payloads, key on the
  **exit code** or on the presence of `unrunnable`, not on the shape of the output — a consumer
  that reads `blind_spots` off the JSON will now raise a lookup error on a refusal instead of
  silently reading a clean bill. That is deliberate: these instruments are advisory, and the one
  thing an advisory tool must never do is report *nothing found* when it found nothing out.
  **Changed with this release:** the same refusal now reaches `reachability_walk.py --self-test`,
  which previously reported `SELF-TEST PASS` regardless of whether the walker could derive
  anything. If you run that arm in CI, it can now exit **2** — and when it does, the instrument is
  broken, not your tree.
- **Action required:** if your `GUARD_SET` is non-empty, **set `GUARD_ENUM`**. Until you do, the
  scoped run prints a note saying the second direction was not checked — it does not fail. **When
  you set it, expect the FIRST run to refuse — and to name why.** The likeliest cause is a
  **path-shape mismatch**: your enumerator emits `./tests/x` where the list says `tests/x`, and
  every declared guard then reads as unseen. The one the seam exists for is a **guard the
  enumeration lists that nobody enrolled**. Others are possible and the run names whichever fired,
  one at a time, with the next only after that one is fixed — **read the message rather than
  working from a list of causes, including this one.** Every narrowed run before now ran a floor
  only as complete as the list, with nothing detecting the shortfall — an earlier release had
  already made the banner say so; what was missing was the detection. Enrol each such guard in
  `GUARD_SET`, or narrow `GUARD_ENUM` if it is deliberately not a floor guard — either way, say
  which in the file.
- **Action required only if you audit classifications by grep.** If you have a check that greps
  `KIT-CLASS:` across `.claude/skills/` and expects a hit per directory, it was reporting the
  vendored skills as unclassified and it will keep doing so. Point it at the provenance table's
  `Class` column instead, or scope it to the paths that do carry markers. **If you have no such
  check, there is nothing to do.**
- **If you implement the release ritual yourself, the pre-cut sweep is a required step of it and
  owes a named owner.** You do not owe a script arm that checks it.
- **Your process artifacts move out of `docs/`.** The kit used to send engineering design specs
  to `docs/specs/`, plans to `docs/plans/`, refactor passes to `docs/refactor/`, design passes to
  `docs/design/` and run records to `docs/runs/`. **They now go to `dev/` under the same names**,
  inheriting `dev/`'s dated-snapshot convention and its index. **`git mv` those five directories
  into `dev/`** and update the citations that point at them — a plan or spec cited from an issue
  file carries the old path. The kit ships the five directories, so they will exist in your tree
  whether or not you have anything to put in them yet.
- **`docs/` does not go away, and it is not empty.** It is now a stated home for **material your
  project did not write** — a vendor's API guide, a third-party spec, an artifact produced to
  leave the project — with `docs/README.md` carrying the test that tells it apart from `dev/`.
  **Anything left in your `docs/` after the move is either that, or it is a working record that
  belongs in `dev/`.** Sorting it is a one-time read.
- **If you carry your own copy of `reachability_walk.py`**, add `specs`, `design` and `runs` to
  its `DEV_PROSE_TREES`. Without them the walker still runs and still reports — it just collapses
  those three directories to one node each, so their members stop being individually visible.
  Nothing goes red; the report just gets quieter about the newest part of your tree.
- **If you implement the drift report yourself, an advisory arm must carry the `reports only`
  token in its header** (`contracts/drift-report.md` § 4 item 5). A consumer that re-reads your
  rendered findings has no other way to tell an advisory line from a deciding one, and an advisory
  arm that appears on every run will otherwise fail that consumer the first time any unrelated
  finding flips the verdict.
- **The scoped run stops overstating its floor.** `scripts/verify.sh`'s guard-floor header said
  a rename that forgot the list *fails loudly instead of quietly shrinking the floor* — true
  of a **listed** path that vanishes, and false of the direction that actually costs you: a
  guard that lands and is never enrolled is invisible to that check, because the list is the
  only thing it reads. The header now says both, and names the unguarded direction as the price
  of keeping membership readable without running anything. The run's own output says
  `DECLARED guard(s)` instead of `always-on guard(s)` and states that the floor is only as
  complete as the declaration, and the Dev role doc no longer calls a scoped run *safe* without
  saying what it is not. **Nothing about what runs has changed** — this is the same floor,
  described honestly. **If you have filled `GUARD_SET`, take the corrected header block into
  your own copy and keep your contents**; the sentence you are replacing is the one that would
  have told you the omission could not happen quietly.
  **Superseded 2026-08-29 by the guard-floor reconciliation (`verify.sh`'s `GUARD_ENUM` seam, above):** the unguarded direction is no longer the price — the enumerator supplies the space the list is reconciled against, and the scoped run reports both directions where it saw something. The readability reason above stands and is why the list remained hand-kept.
- **If you carry a hand-kept index or list guarded in only ONE direction, check what its in-file
  note actually says.** `lookup-tables.md` § A.5 rank 4 has always tolerated that shape *"only
  with a named reason in-file"*; it now requires the reason to **name the direction left
  unguarded** — not merely to explain why the list is hand-kept. A note saying *"this list is
  maintained by hand because the members are decided by a human"* does not meet it; *"nothing
  detects a member that exists in the tree and is missing from this list"* does. **One sentence
  per such list**, and the point of it is that the next reader learns the blind spot from the
  file rather than from an incident.
- **Two checks, if either applies to you.** If you derive your `MIXED` file set with
  `grep -rl 'KIT-CLASS: MIXED'`, it over-counts — a script that generates a classified file carries
  that file's marker; use the first-marker-per-file form now shown in `EXTRACTION.md` § 1.1. And if
  you added a role by following the adapter's old "editing three places" sentence, check
  `scripts/move-issue.sh` and `scripts/subtask.sh`: a role registered only in the hook and the adapter
  commits fine and cannot move a card — § 2.4's table is every carrier.
- **If you use the `brainstorming` skill's visual companion with `--project-dir`: its persistence
  directory is now `.brainstorm/`, not `.superpowers/brainstorm/`.** Add `.brainstorm/` to your
  `.gitignore`. If you had ignored only `.superpowers/`, the next session's mockups would be
  **tracked** — that is the single failure this rename can cause. Mockups already saved under
  `.superpowers/brainstorm/` are **not** moved and nothing reads them: keep the directory if you still
  want them, delete it when you do not. An old session still stops cleanly, because `stop-server.sh`
  takes the session directory as its argument.
- **The drift report gains a day-one completeness check.** `check-board.sh` now reports, at every
  session close, while `CLAUDE.md` or `README.md` still carry the shipped `BOOTSTRAP-SCAFFOLDING` line
  or `PROJECT.md` still holds `<angle-bracket>` blanks. It reads your published trunk, names what it
  read on both the reporting and the clearing branch, and **does not affect the `board-drift:`
  verdict line** — so it cannot block a release or fail `kit-init`'s self-check. **Action required:** a
  project already past day one will see the new `[g]` line report findings if it kept the kit's
  shipped `README.md`, or left `<angle-bracket>` blanks in `PROJECT.md`. That is the check working.
  Replace the files, or fill the blanks, and the arm goes quiet on its own. A reimplementation of the
  drift report in another stack now owes invariant 7. ~~One known limit, stated because it is
  measured: the arm is gated on the initializer's stamp receipt, so a project that implemented the
  contracts in its own toolchain and never ran `kit-init.sh` does not see the prompt — an open
  question, recorded.~~ **SUPERSEDED — the limit was closed; see the Changed entry above for the
  release that closed it.** The arm now enables on **any sign the repository has started**, the
  initializer's receipt being only one of them, so a project that never ran the initializer does see
  the prompt. *The struck text is kept because the limit was real and measured when written, and
  because it is the reason the enabling condition is what it is: what closed it was widening the
  signal, not removing the gate.*
- **The commit-message hook now refuses generated co-author trailers — if your tooling adds one, your
  next commit is rejected.** `scripts/githooks/commit-msg` used to judge only the subject's role tag;
  it now also reads the **whole message** and refuses a `Co-Authored-By:` line naming a **tool**, or
  a *"Generated with …"* line (`doctrine/commit-hygiene.md` § A.1 — a rule the kit has always stated
  and never enforced, which is why the sheet predicted that "the default the tool ships with" would
  win). `scripts/githooks/applypatch-msg` delegates to it, so `git am` and `git cherry-pick` are
  covered by the same rule. **What to do: turn the trailer off where it is generated** — your
  agent's or editor's setting — rather than working around the hook; that is the point of the rule.
  **A trailer naming a human is still accepted**: only tool markers are refused, and the markers are
  one named line in the hook (`TOOL_TRAILER_MARKERS`) that you extend in one place when you meet a
  new tool. **If you must import a third party's commit verbatim** — a cherry-pick or `git am` whose
  message already carries a tool trailer — the documented escape is `MSG_OK=1 git commit …` /
  `MSG_OK=1 git am …`; it exists for somebody else's message, not for your own. Two things
  deliberately unchanged: a **merge or revert subject** is exempt from the *prefix* rule and is
  **not** exempt from this one, because the body is where the trailer lives; and **`git commit -v`
  still works** — the diff below the scissors line is cut before the scan. If you initialized with
  `kit-init.sh`, `core.hooksPath` is already set and the refusal is live as soon as you take the new
  hook; if you copied the hook by hand, copy it again.
- **If you built your adapter from a template older than this release, it is missing two sections:
  § The binding gates here and § Where the rest of the process lives.** The latter is your adapter's
  only route into `process/MANUAL.md`, `contracts/`, `doctrine/`, `hygiene-checklist.md`,
  `GIT-HOSTING.md`, `EXTRACTION.md` and `SEED.md`. Adding them to the template does not add them to
  your copy. **Diff your `CLAUDE.md` against `process/templates/CLAUDE-adapter.template.md` and port
  anything missing.**
- **Only if `progress/history/` ALREADY holds rotated chunks: create `progress/history/INDEX.md`
  before your next rotation.** The rotation will not write one for you while chunks exist, because a
  row-less index would deny them — and the date spans are inside those chunks, so only you have them.
  Create the file with the header row **and its markdown separator**, then one row per existing
  chunk — **both lines, exactly:**

  ```
  | Chunk | Covers | Entries | Rotated | Cut |
  |---|---|---|---|---|
  ```

  **The separator is not cosmetic — and the rotation now refuses without it.** The insert goes directly
  below the header row and reprints the line after it, so an index whose header is not followed by a
  separator would have **your first chunk row consumed in the separator's place**: the new row lands
  *second* and your newest entry is no longer first. That is why the separator is load-bearing.
  Rather than mis-write the file, `archive-progress.sh` now validates that line and **exits 1**,
  printing the two lines your index must open with; it will not insert the separator for you, because
  that file is your record. So a malformed index costs you an **aborted rotation** rather than a
  silently mis-ordered one — and note the posture: **the chunk and the rewritten log are already on
  disk when it refuses.** Fix the two lines and append the printed row by hand; do not re-run.
  *(An earlier version of this item said the rotation "assumes" the next line is the separator. It
  did, and it mis-wrote. The reason above is unchanged; only the consequence is. Corrected
  2026-08-28.)*

  **If you have never rotated, there is nothing to do:** the file is created on first use, because an
  empty index is then simply true.
- **If you parse `verify.sh`'s output, update it for the fourth state and the count line.** Anything
  matching on exactly `PASS`/`FAIL`/`SKIP` will not recognise `UNRUNNABLE`, and a summary parser
  expecting the old shape will need the new one. **If you have been treating a red gate as "the tree
  is broken", check whether it was actually failing to start** — that is the distinction this buys.
- **Run `check-board.sh` once and read what it now reports about your MAIN checkout.** The new
  divergence reading covers the primary checkout as well as the board mover's worktree, and **if you
  have been writing rulings, PRDs or board edits directly on the trunk, it may report unpublished
  work that has been sitting there unnoticed** — that is the defect it was added to find, not a false
  positive. Push what it names. After that it goes quiet.
- **Expect new SKIPPED lines in the board report, and treat them as information rather than
  breakage.** Checks that used to print green over absent input now say SKIPPED with a reason. If a
  check you relied on now skips, its input is missing — the previous green was not evidence of
  anything.
- **The pause law's "never end a turn on a stated intention" is now an ORDERING, not a prohibition**
  ([`doctrine/orchestration.md`](doctrine/orchestration.md) § A.5). Reorder your coordinators' belt
  from belt → status → dispatch to **belt → dispatch → status**, so a turn ends on a tool call by
  construction rather than by remembering to. The original wording and its reason are preserved above
  the amendment; nothing you have written becomes wrong, but **a coordinator that follows only the
  prohibition will keep paying the failure it names** — it asks the actor to notice at exactly the
  moment the failure describes.

- **`finish-pr.sh` REFUSES a posture that used to land, and has a new exit code.** It now requires the
  gate it runs to be the **committed** one, **at the revision being landed**, and unmodified — naming
  which of five it was (missing / not executable / not at that revision / not tracked there / locally
  modified). **If you have been landing from a trunk checkout, that now refuses**: check the branch out,
  or pass `--worktree` a worktree that has it. This was already what `contracts/landing-gate.md` § 2
  required; the script did not enforce it, so a **red** branch could land green.
  **And `exit 3` is new**: it means **LANDED BUT NOT FINISHED — do not re-run**, run the printed
  recovery. Previously a failed board-advance after a successful merge exited `1`, the same code as
  *nothing landed*, so an automation reading `$?` would retry a merge that had already happened. **Any
  wrapper treating every non-zero as "did not land" must learn 3.**
- **If you copied `QA_SCHEMA` or `PARK_SCHEMA` into your own runner, the field shape changed.**
  `landed: boolean` → **`landing: enum { landed, deferred, not_applicable }`**, because a boolean
  could not represent a green review whose landing was correctly deferred — it read one as a failure
  and halted a run that had succeeded. `not_applicable` exists because a docs-path issue has no
  landing script, and a boolean forces that case to lie.
- **The board mover's Activity entry format changed — update anything that parses it.** A move now
  writes `- <date> [<role>] → <target>: <note>`; the **arrow is the status declaration**. There is also
  a new **note-only** form, `- <date> [<role>] NOTE: <note>`, which deliberately emits **no** arrow and
  changes no container. If your own tooling reads those bullets, it needs the arrow — and must not read
  a `NOTE:` line as a status.
- **`check-board.sh` gains an id-register check, and it needs one declaration from you.** It reports
  duplicate ids in a declared register — the case with **no textual conflict**, where two legs mint the
  same id in different sections and a rebase merges both cleanly. Declare yours in the `REGISTERS`
  table beside `ISSUE_ID_PATTERN` (`'<path>|<heading mark>|<id shape>'`); **an undeclared register is
  skipped with its reason, so the check is silent until you declare it.**
- **The board worktree now REFUSES where it used to reset.** `kwt_sync` refuses when the worktree
  carries a commit that is not on the trunk, instead of `reset --hard`ing over it, and the detach
  repair refuses rather than reporting *"nothing else changed"* about a state it could not read.
  **There is no opt-out flag** — discarding a commit is a deliberate act and costs a deliberate hand
  command. If a script of yours relied on sync always succeeding, it will now stop.
- **`subtask.sh` refuses two things it used to accept**, both before mutating: an **absent parent**,
  and an **unvalidated `--role`**. The second mattered more than it sounds — a typo'd role reached the
  commit subject, the hook rejected it *mid-operation*, and the `git mv` plus Activity append were left
  uncommitted in the shared worktree the next board op wipes. It also **checks `kwt_finalize`'s return
  at both sites**, so a failed push is no longer reported as success.
- **`release.sh` refuses an unmarked verify-skip override.** Setting the skip variable without the
  marker now exits non-zero having written nothing, and names the legitimate route instead — *an
  unmarked override does not weaken a gate, it removes one.*
- **The rotation now REFUSES a malformed `progress/history/INDEX.md` instead of mis-writing it.** If the
  header row is not followed by a markdown separator, `archive-progress.sh` **exits 1** and prints the
  two lines your file must open with. It will not insert the separator for you: that file is your
  record, and a tool that quietly rewrites it to suit itself is how an index comes to state things
  nobody put there. **Note the posture — the chunk and the rewritten log are already on disk when it
  refuses**, so fix the two lines and **append the printed row by hand rather than re-running.** The
  separator is matched by GFM **shape**, not by exact bytes, so `| --- | --- |` is accepted as readily
  as `|---|---|`. If your index is well-formed, nothing changes for you.
- **The `ISSUE`, `BUG`, `REFACTOR` and `SUBTASK` templates carry a new `pr:` frontmatter key** (`PRD`
  does not — a PRD has no PR), **and cards minted from them start at `pr: null`.**
  `move-issue.sh --set-pr <val>` writes the resolved PR/MR reference into that line on a
  card that has it, and **warns and skips the write-back on a card that does not** — so cards you
  minted from an older template are silently not updated, which is the case to know about. Nothing
  shipped calls the flag; it exists for a forge-aware wrapper of your own, and stays `null` on the
  forge-agnostic path. **If your own tooling parses card frontmatter, expect the new key**; if you want
  it on existing cards, add the line to them, as the templates now write it.
- **If you initialized with a non-default `--prefix`, your classification markers are already defaced —
  grep for them and repair them by hand.** The stamping bug in § Fixed above rewrote the marker's key
  on every shipped file it touched, and **the fix stops future defacement; it cannot go back**, because
  there is no updater (see *How to upgrade an adopted project*). Run
  `grep -rn --exclude-dir=.git -- '-CLASS:' .` and repair any marker whose **key** is not
  `KIT-CLASS:` — the value after the colon (`KIT` / `MIXED` /
  `PROJECT`) was never touched, so the repair is the key alone. Start with `.claude/templates/` and
  `.claude/roles/`, and then check your own cards: every card minted after day one inherited the
  corrupted key from the template it was copied from.
- **If you wrote your adapter from the older `CLAUDE-adapter.template.md`, add the three tables it was
  missing.** The template now carries the roles table, the role-attribution commit-prefix table and the
  code-vs-metadata glob declaration; adding them to the template does not add them to a file already
  written from it, and the rest of the kit cites your adapter for exactly that content.
  **The prefix table is the one that bites**: `AGENTS.md` anchors into your adapter's
  § "Role-attribution commit prefixes" by section name and the `commit-msg` hook **enforces** that
  set, so an adapter without it leaves a dangling anchor plus an enforced-but-unspecified seam, on your
  first commit rather than eventually. Copy the three shapes across and fill them — the values are
  yours, only the shapes come from the template.

**Checked against the board and the tree on 2026-08-28**, at the kit repository's own revision
`9de04c5` plus the reconciliation that reading produced: every adopter-visible change listed above
carries its entry, and every entry that needs something from you is in this section.
**That reading covers the tree AS OF THAT REVISION AND NO FURTHER — entries have landed since, and
they are not inside it.** *An all-clear inherits the date it was taken, never the date it is read.
Re-take it at the cut rather than trusting this paragraph; a stamp that outlives its revision is the
same false assurance the entries above keep being about.* Nothing else above requires an
action — the rest are refusals that fire only on a setup that was already broken, corrections to the
seed's own files, or new material that binds nothing until you reach for it. **A project that never
holds a dogfooding round pays nothing for the two new sheets** — they are one more file each in
directories you already carry.

**Read that as a measurement, not a guarantee — and here is why it is dated.** This paragraph used to
read *"Otherwise none."*: a standing all-clear that no later change re-derived. Adopter-visible work
then landed with no entry at all, twice in the same release cycle, and the all-clear went quietly false
both times while reading exactly as it always had. *Derive, date, or do not state* is the kit's own rule
and it binds this file too. **If the date above is older than the newest entry you are reading, trust
the entries and not the all-clear.**

Worth reading anyway if you maintain guards: `doctrine/instruments.md` § A.2 (*every green owes an
ablation*) is the rule the kit itself had been breaking, and the same shape is easy to
have shipped in your own drift checks.

---

## [0.1.0] — 2026-08-26

The first versioned cut. The kit at this version is what a fresh adoption gets:

- **The process** — [`MANUAL.md`](MANUAL.md): a filesystem-as-kanban board, roles as hats, the
  Dev → QA boundary and its seven steps, branching and role attribution, the session rituals.
- **Two front doors** — [`SEED.md`](SEED.md) (you have nothing) and [`EXTRACTION.md`](EXTRACTION.md)
  (the manifest, with its debt list in § 4).
- **The contracts** — [`contracts/`](contracts/), one sheet per gate stating what any
  implementation must guarantee, when it must refuse, and what green means in countable terms.
  **This is the route for an adopter who takes none of the shell scripts.**
- **The doctrine** — [`doctrine/`](doctrine/), the reasoning behind the standing rules.
- **The harness** — `.claude/`: role docs, leaf-agent definitions with model/effort pins, the skill
  set, two multi-issue runners, the item templates, and an opt-in settings example.
- **The executable kit** — `scripts/`: the initializer, the board mover, id minting, the drift
  report, the landing gate, the archive sweeps, the gate-runner frame, the release ritual,
  notifications (off until configured), the hygiene instruments, and a self-test harness.
- **The board and the registers** — `progress/`, `progress.md`, `ARCHIVE.md`, `requirements/`,
  `dev/`, and the optional `consumers/` distribution machinery.

### Action required

Nothing — this is the first release. Start at [`../README.md`](../README.md) § Day one.
