<!-- KIT-CLASS: KIT — the git-topology guide. Forge-agnostic by design; § 4 is an OPTIONAL extra. -->
# GIT-HOSTING — the topology this kit needs, and the three regimes it survives

**KIT-CLASS: KIT.** Everything here is transferable. It answers one question — *what does this
process kit actually require of git?* — and then covers the three situations a project finds
itself in: **local-only**, **hosted**, and **pushes refused**.

**The short answer.** The kit needs a git repository with **one remote whose HEAD is set** and a
trunk branch on it. Nothing else. No forge, no API token, no pull-request ceremony, no CI.

---

## 1. The kit is forge-agnostic pure git, and this is a deliberate design choice

The landing path — squash-merge the issue's branch into the trunk, push the trunk, delete the
branch, advance the issue file on the board — is implemented in **plain git** by
[`../scripts/finish-pr.sh`](../scripts/finish-pr.sh). There is no forge client anywhere in the
critical path, and there is no pull request. **The review record is the issue file's Activity
log**, which is a file in the repository, so the audit trail travels with the code and does not
live in someone's account.

**Anonymous evidence that this pays for itself.** The project this kit was extracted from
migrated between two different hosted forges partway through its life — new host, new protocol,
new authentication model, new organization. **The landing script needed zero changes.** So did
the board scripts, the worktree machinery, and every role doc. The only thing that changed was
one remote URL and one line in a consumer-facing updater script. A kit built on a forge's API
would have paid for that migration in every script it owned.

**The optional forge flavor, and why it is not the default.** A team that wants PR/MR ceremony can
add a branch to the landing script that opens and merges through its forge's CLI instead of the
local squash. Keep it opt-in: the portable path is plain git, and the role prefix on the squash
commit is the attribution either way.

**What this means for you:** do not add a forge dependency to a kit script to gain a convenience.
If you need forge automation, put it in a separate script that the kit path does not call.

---

## 2. What the kit actually requires

Three things, and the initializer refuses without them rather than guessing:

1. **A remote** (default name `origin`; the kanban-worktree machinery takes the name as a knob).
   The kanban worktree fetches, resets and pushes through it.
2. **That remote's HEAD set** — `refs/remotes/<remote>/HEAD`. This is the one that bites.
3. **The trunk branch present on the remote** (`<trunk>`; **`main` is the stated default**).

**The silent-corruption class this guards.** The worktree machinery resolves the trunk in order:
`<remote>/HEAD` → the local `init.defaultBranch` → a built-in fallback. If nobody set the
remote's HEAD, the resolution silently lands on a **branch name nobody chose** — and you discover
it on the first board move, from a worktree pinned to the wrong ref. That is why the initializer
**guides rather than bootstraps**: creating a remote is a repository-topology decision an
initializer has no business making for you, so it refuses and prints the recipe.

---

## 3. LOCAL-ONLY — the bare-repo recipe (a perfectly good remote)

A local bare repository satisfies every requirement above. There is no reason to sign up for
anything to start using this kit. Run all four steps; step 1 is the offline case.

```
1.  git init --bare /path/to/<repo>.git
    git -C /path/to/<repo>.git symbolic-ref HEAD refs/heads/<trunk>   # the bare side's HEAD names the trunk
    git remote add <remote> /path/to/<repo>.git   # ABSOLUTE path — see below
2.  git switch -c <trunk>                        # if the trunk does not exist yet
    git add -A && MSG_OK=1 git commit -m '<init>'   # if there are no commits yet: commit the kit AS UNZIPPED
3.  git push -u <remote> <trunk>
4.  git remote set-head <remote> <trunk>         # ← the step whose absence is SILENT
```

**The remote URL must be ABSOLUTE.** A relative path appears to work here and the initializer
REFUSES it, because a relative remote resolves against whatever directory the caller happens
to be in — which is not the same directory for a linked worktree as for the main checkout.

**Step 4 names the branch explicitly on purpose.** `git remote set-head <remote> -a` *asks the
remote what its own HEAD is*, and a freshly created bare repository has none — it fails with
`Cannot determine remote HEAD`.

**Step 1's `symbolic-ref` line is NOT interchangeable with step 4, and the order is why** — which
is why the recipe now does both. Setting the bare side's HEAD *at creation* is the safer form.
*(It used to be offered here as an alternative to step 4, and README § Day one's recipe did not
use it; an adopter following that recipe verbatim got a bare repository whose HEAD named git's
default branch, and a `git clone` of it that warned* "remote HEAD refers to nonexistent ref" *and
checked out nothing — reproduced 2026-09-26.)*

*Measured:* a freshly created bare repository's HEAD points at git's own default branch name,
which your first push may never create. Run against that, `git remote set-head <remote>
<trunk>` **exits 0 and changes nothing on the remote** — it writes a local tracking ref and
leaves the bare side's HEAD pointing where it was. The mismatch surfaces much later, as
`HEAD branch: (unknown)` from `git remote show`, at whatever moment something tries to
resolve the trunk. Setting HEAD on the bare side cannot mislead that way: it writes the fact on
the side that owns it. **When you control the bare repository, step 1 does it; step 4 is still
needed for your local record of it, and is all you can do when you do not control the remote.**

The kit initializer prints this same recipe when it refuses.
<!-- RULE-COPIES:BEGIN — deliberate copies of this recipe; the self-test holds them.
key: the bare side's HEAD names the trunk
copies: README.md scripts/kit-init.sh
RULE-COPIES:END -->

**If the commit-message hook is already wired**, step 2's commit needs a subject the hook accepts
(a role-prefixed subject, or the hook's own documented bypass) — see the hook and the setup script
under [`../scripts/`](../scripts/). Wiring the hooks *after* the initial commit avoids the
question entirely.

**Notes on living local-only.**

- Put the bare repository somewhere your backups reach. It is now the only copy that is not a
  working tree.
- Everything in the kit works: branches, landings, the kanban worktree, board moves, the trunk
  push. Nothing is degraded.
- Adding a hosted remote later is a URL change, not a migration of the process — but read § 5
  first, because *adding* a second writable remote is exactly where projects get hurt.

---

## 4. OPTIONAL — a hosted forge

> **This whole section is an optional extra.** Skip it entirely if you are local-only. The
> examples use one popular host's conventions; every host differs in the details and none of the
> details are load-bearing for the kit.

### 4.1 SSH key and host config

Generate a key **for this machine and this host**, and pin it in your SSH config so git never has
to guess:

```
ssh-keygen -t ed25519 -f ~/.ssh/<host-nickname> -C '<machine>-<host>'

# ~/.ssh/config
Host <host>
    HostName <host>
    User git
    IdentityFile ~/.ssh/<host-nickname>
    IdentitiesOnly yes
```

`IdentitiesOnly yes` matters: without it a machine with several keys offers them in an order you
did not choose, and a host that accepts the *first* valid identity can authenticate you as the
wrong account.

### 4.2 The organization-authorization gotcha

**A key that authenticates you is not necessarily a key that can reach an organization's
repositories.** Hosts with single-sign-on organizations require the key to be **authorized for
that organization** as a separate act, performed by the account owner in a web UI, after the key
is registered. Symptom: authentication succeeds, the repository "does not exist".

**Therefore: `ssh -T` is not the proof.** It tests that the host recognizes you, which is the
question you did not need answered.

```
# NOT the proof — only says the host knows who you are:
ssh -T git@<host>

# THE PROOF — says this key can read this repository through this org:
git ls-remote git@<host>:<org>/<repo>.git
```

Make `ls-remote` the gate in any migration or setup checklist, and make its output — the refs it
printed — the recorded evidence. It is also the cheapest between-leg liveness reading a run has
(§ 6, and the between-leg belt in [`doctrine/orchestration.md`](doctrine/orchestration.md)).

### 4.3 Commit identity

The author email in your commits is a **separate identity** from your SSH key. If the email on
your commits is not registered to your account on the host, the commits appear **unlinked** —
correct content, no attribution. Check it before a long run, not after:

```
git config user.email          # what your commits will claim
git log -1 --format='%an <%ae>' # what the last one claimed
```

Neither the kit nor any script fixes this for you; it is one line of local config and one setting
on the host. Record it as a residual item if you cannot resolve it immediately — an unlinked
history is annoying to explain later and impossible to rewrite cheaply.

### 4.4 What the kit still does not need

An API token, a bot account, a CI configuration, a protected-branch rule, or a PR template. If
you add protected branches, note that the kit's landing path **pushes the trunk directly**; a
protection rule that forbids that turns every landing into the blocked-push regime of § 6.

---

## 5. THE MIRROR LAW — exactly one writable source of truth

**The law.** At any instant, exactly one remote is writable and authoritative. Every other copy
is **read-only**, and something must enforce that, not merely intend it.

**The fatal state, named so it can be recognized:** a **force-syncing mirror** (an automation that
periodically force-pushes A → B) *plus* **a writable B**. Work committed to B lives until the next
sync fires and then ceases to exist. Nothing in git protects you: the sync's force-push is doing
exactly what it was told. And it is a **state that cannot be verified by observation** — a sync
fire is an *event*, not a steady state, so a hundred quiet readings prove nothing. The donor
project sat in this state for days and accumulated exactly that kind of evidence: monotonic remote
readings at every leg boundary, no regression ever seen, question still open, because "we have not
been bitten yet" is not a safety argument.

**The corollaries.**

- **A mirror is configured read-only, or the sync is disabled. Both-or-neither is a package**, and
  half of it landing is the dangerous outcome. If someone reopens writes on the mirror without
  disabling the sync, you are in the fatal state and it looks fine.
- **Treat any unexplained regression of the authoritative remote as a sync fire**, and treat local
  git history as the recovery source. That is worth writing into a run's standing facts.
- **The safe way out is containment, not coordination.** See § 5.1.

### 5.1 The migration order: make the destination a SUPERSET first

Moving from remote A to remote B, safely, with a sync of unknown state pointing at one of them:

1. **Snapshot both sides.** `git ls-remote` each remote to a file, and record a rollback point
   (the exact command that restores the old URL). Refs are cheap; regret is not.
2. **Census the old host's URL** across the repository and its consumer-facing artifacts — every
   place a URL is hard-coded is a seam that must move with you.
3. **Establish containment before anything else.** Verify the destination's current state is an
   **ancestor** of local (`git merge-base --is-ancestor`), and that the ref difference between the
   two remotes is exactly what you expect. **Push nothing to the destination before you are ready
   to push everything.**
4. **The everything-push.** Push the trunk, **all tags**, and any published side branches to the
   destination, so that **destination ⊇ everything**. This is the step that makes the whole
   problem go away: once the destination is a superset, a stray sync fire in either direction is
   **convergent** rather than destructive. The fatal window is closed *by construction* rather
   than by an agreement with a human who has to remember something.
5. **Swap the remote URL.** One command. Verify: fetch clean, in sync, containment re-checked.
6. **Prove it end to end with a real consumer action** — not a `git` command. Run whatever the
   project ships that reads the remote (an update checker, a release query) and require its
   success output. Passing your own fetch is not proof that your users can reach you.
7. **Leave the old side untouched and read-only.** Do not delete it. Decommissioning belongs to
   whoever owns that host, later, deliberately.
8. **Sweep the documentation in the same change** — the remote URL in setup docs, the migration
   fact wherever a script comment cites the topology, and the rollback command. Then record the
   **residuals** you could not finish: commit-identity verification, CI configuration that is
   shaped for the old host, consumer templates that name it.

**Force-pushed branches are a policy, and the policy is written down.** If your release process
publishes an orphan branch by force (a distribution branch, a docs branch), that branch's
"replace" semantics are part of its own documented policy, and a force in the migration is
expected rather than alarming. Say which branches those are before you push, so nobody has to
judge it mid-migration.

---

## 6. THE BLOCKED-PUSH REGIME — when the remote refuses, work does not stop

Pushes get refused for mundane reasons: a protection rule, a hook, an expired credential, a host
outage, an in-flight migration. The kit's answer is that **a refused push is a landing problem,
not a work problem.**

### 6.1 The regime

- **Closes become verified land-ready branches with recorded verdicts.** The reviewer does the
  full review, runs every gate, and records the verdict in the issue file's Activity log as a
  distinct close state — `LAND-READY` (the donor spelled it `PASS_LAND_READY`) — meaning
  *reviewed, gates green, not landed*. The verdict is a real close; only the merge is deferred.
- **State the regime at preflight and re-check between issues.** Which regime a run is in changes
  what "done" means, so it belongs in the run's standing facts and in the between-leg readings.
  A blocker that lifts mid-run is a normal event — the donor discovered a three-day blocker had
  quietly lifted only because a run re-checked.
- **Branches accumulate, and that is fine, provided they are enumerated.** Every land-ready
  branch is named in the run report with its head SHA, and the board reflects the verdict.
- **No stacking unless you say so.** Independent branches each cut from the trunk are far cheaper
  to land later than a stack. If a run must stack, the **binding landing order** is written down
  in the report, because it will not be re-derivable later.
- **Nothing is "temporarily" committed to the trunk to work around the blocker.** That trades a
  deferred merge for a corrupted history.

### 6.2 The landing day

When the route reopens, land deliberately, as its own piece of work:

1. **Execute the whole day locally first** — every squash-merge, in the recorded order, with the
   quick gate per landing and the full gate at milestones. If something is wrong, you find it
   with nothing pushed.
2. **Then push once**, and re-verify: remote trunk equals local head, tags present, board clean.
3. **Never blind-union a conflict in a source file.** A mechanical union once glued a truncated
   statement together in the donor project. Rebuild the region from both sides, deliberately.
4. **Re-derive generated artifacts after each merge, not once at the end** — and if your project
   annotates predicted sizes, note that these predictions **compose additively** across merges,
   which makes each landing's prediction independently checkable against measurement. Confirmed
   predictions are the cheapest evidence you will ever collect.
5. **Reconstruct what a rewrite dropped.** A branch that rewrote a shared index file may have
   dropped index entries other branches added. The guard that enforces indexing is the
   reconstruction instrument: run it, and re-insert exactly what it names.

### 6.3 The cross-branch id-collision class — check this at every landing

**The failure:** several branches, developed in parallel, each read "the next free id" from a
shared append-only register — a decision log, a ruling register, a numbered index — and each
correctly took *the same* one. Every branch is individually right. The merge is wrong: duplicate
ids, and the duplication is silent because each side's diff looks fine.

**The rule:** **at every landing of a branch that adds to a shared register, collision-check the
register and renumber on the way in.** A register may tolerate a **gap**; it must never tolerate a
**duplicate**. Renumbering at landing time is cheap; discovering a duplicate months later, cited
from three documents, is not.

**The prevention, which is weaker than the check but worth having:** any leg that mints into a
shared register **re-reads the next free id from the file at write time**, never trusting a
number quoted in a brief — and the register's own guard tolerates gaps by design, so a leg that
skips an id costs nothing.

**Generalize it.** The same shape appears anywhere parallel branches allocate from a shared
sequence: issue ids, migration numbers, fixture indices, changelog section anchors. If a number
is derived from "what exists now", it is a collision candidate the moment two branches exist.

---

## 7. Checklists

**New project, local-only.** Bare repo created **with its HEAD on the trunk** (§ 3 step 1's
`symbolic-ref`) and backed up · remote added · trunk pushed ·
`git remote set-head` run **explicitly** · initializer re-run and satisfied · one board move
performed as a smoke test.

**Adding a hosted remote.** Key generated and pinned with `IdentitiesOnly` · key registered ·
**key authorized for the organization** · `git ls-remote` against the actual repository succeeds
and its output recorded · commit email checked · § 5's mirror law read before a *second* writable
remote exists anywhere.

**Migrating hosts.** Both sides snapshotted · rollback command recorded · old-host URL census done
· containment verified · **everything-push (trunk + tags + published branches) so destination ⊇
local** · URL swapped · consumer-level proof green · old side left untouched and read-only · docs
swept in the same change · residuals recorded by name.

**Entering or leaving the blocked-push regime.** The regime named in the run's standing facts ·
verdicts recorded as land-ready with gates green · branches enumerated with head SHAs · landing
order written down if anything stacks · re-checked between issues · at landing: local-first,
register collision-check, no blind unions, generated artifacts re-derived per merge.
