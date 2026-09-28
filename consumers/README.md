<!-- KIT-CLASS: KIT — the consumer-onboarding walkthrough. Fill the <seams>; the flow travels. See process/EXTRACTION.md. -->
# Consuming `<vendored-name>` — zero-knowledge onboarding

> **Two audiences, one page.**
> **If you are a CONSUMER** — you want to use this project from *your* repo — start at
> [Prerequisites](#prerequisites) and run the commands. Every `<angle-bracket>` on this page
> is something the project's maintainers fill in **before** they hand you the link; if one is
> still a placeholder when you read it, that is a bug in their onboarding, not in yours.
> **If you MAINTAIN a project and are filling this in**, read
> [`process/doctrine/distribution.md`](../process/doctrine/distribution.md) first — it is the
> *why* behind every rule below — then fill the seams here and in
> [`update_vendored.sh`](update_vendored.sh).

**Is this directory even for you?** Only a project that **ships something into other
repositories** needs `consumers/`. If yours does not, delete the directory. Unused
distribution machinery that looks configured is worse than none: somebody eventually runs it.

---

## The one rule to remember

**The vendored artifact is never auto-updated.** Refreshing it is always a deliberate command
a human runs. The optional nag (git hook, CI job) only *tells you* an update exists — it never
applies one. Nothing in this directory phones home, and nothing installed by it updates itself.

---

## How this project ships (the 20-second version)

It is **not** installed from a public package index and **not** installed from a live git URL.
Instead you **vendor a built artifact** into your repo (`./vendor/<the artifact>`) and **pin
it** through your own dependency mechanism. A fresh clone of *your* repo then reproduces its
environment from that local artifact — **no upstream remote needed** (a public index is used
only for ordinary transitive dependencies, if your ecosystem has them).

The **only** step that ever contacts the upstream remote is building or refreshing the
artifact (`update_vendored.sh`). A normal `git pull` in your repo touches no upstream network
at all.

The upstream remote can be anything git can clone — a forge, or a **local bare repository** on
a shared disk. See [`process/GIT-HOSTING.md`](../process/GIT-HOSTING.md); nothing in this flow
assumes a forge exists.

---

## Prerequisites

- `git` on your machine, plus whatever your own project needs to build and install
  `<the artifact kind>`.
- **One-time** network (or filesystem) access to the upstream repo — only to build the
  artifact.
- Whatever **configuration or credentials** the project itself requires. The authoritative,
  per-operation list is the one the project's own shipped guide carries; Step 3 names only the
  minimum.

You do **not** need: a clone of the upstream source, submodules, or any additional tooling
beyond your project's own.

---

## Step 1 — Onboard (build + vendor the artifact)

From **your** repo root, run the onboarding script that ships with the project (point it at
wherever you have the upstream checkout — a colleague can hand you the path; you never open its
files):

```bash
/path/to/<project>/consumers/setup-consumer.sh
```

This does four things and then **prints exactly what remains**:

1. copies `update_vendored.sh` into your `scripts/`,
2. copies the advisory git-hook template into your `scripts/`
   (`scripts/<vendored-name>-post-merge.hook`),
3. copies the **router skill pack** into your `.claude/skills/`, if the project ships one
   (see Step 5),
4. builds the latest tagged artifact and vendors it into `./vendor/`.

The tail of its output is your to-do list. Follow it — the rest of this page is the same list
with more explanation.

## Step 2 — Pin the artifact and install it

The script prints one line on stdout: the **pin line** for your dependency manifest. Record
**that exact line** through `<your dependency pinning mechanism>` (a requirements manifest
entry, a lockfile entry, a vendored-path dependency — whatever your ecosystem uses), then
install the artifact into your environment.

**The first install and a later refresh are deliberately different commands:**

| | Resolve transitive dependencies? | Why |
|---|---|---|
| **First install** | **Yes** | The environment has none of this project's dependencies yet; skipping resolution leaves them uninstalled and the failure surfaces much later, somewhere unrelated. |
| **Later refresh** | **No** | Only the artifact moved. Re-resolving every transitive dependency on a working environment is slow and can silently move versions you did not ask to move. |

`update_vendored.sh` prints the **refresh** form when it finishes; `setup-consumer.sh` prints
the **first-install** form. Use the one you were handed.

## Step 3 — Provide configuration / credentials

The project reads its configuration from your repo's own untracked config (**never
committed** — this kit's house rule is that a credentials file is gitignored, always).

```
<ENV_VAR_NAME>=...        # <what it is; which surface needs it>
<ENV_VAR_NAME_2>=...      # <...>
```

Read the vendored guide (`./vendor/<vendored-name>-GUIDE.md`) for the authoritative list,
including anything a *write* or *mutating* surface needs that a read-only one does not.

## Step 4 — Wire the advisory update nag (recommended, optional)

So you find out when a newer release exists **without** having to remember to check. This is a
**nag only** — it never updates anything.

**Git hook (fires after `git pull` / `git merge`).** From your repo root:

```bash
cp scripts/<vendored-name>-post-merge.hook .git/hooks/post-merge
chmod +x .git/hooks/post-merge
```

That's it — no path editing. On your next `git pull`, if a newer release tag exists you'll see
a `[<vendored-name>] UPDATE AVAILABLE …` line. It never fails your pull, never writes to
`./vendor/`, and never updates. (The same file works as `.git/hooks/post-checkout` if you also
want a nag on branch switches.)

**CI job (optional).** Two templates ship, both advisory and non-failing:

| Template | For |
|---|---|
| [`ci/vendored-freshness-check.yml`](ci/vendored-freshness-check.yml) | A forge that reads a repo-root pipeline file and can `include:` a local YAML. |
| [`ci/.github-actions-example.yml`](ci/.github-actions-example.yml) | GitHub Actions — copy to `.github/workflows/`. (GitHub is an optional extra here, not an assumption.) |

Each runs `update_vendored.sh --check` in a job that is **allowed to fail**: it surfaces
"UPDATE AVAILABLE" and never breaks the pipeline.

## Step 5 — The router skill pack (if the project ships one)

`setup-consumer.sh` copies a handful of small **router** skills into your `.claude/skills/`.
You can also install or refresh them on their own, without re-vendoring the artifact:

```bash
/path/to/<project>/consumers/install-skills.sh
```

Each file fires on a **task shape** and answers with an **address**: the name of a section in
the vendored guide, or the console command to run. That is all they do.

**They are deliberately thin, and that is not an oversight to fix.** A skill file that
*explains* something the guide already explains becomes a second copy of it, and the copy is
the one that goes stale: the artifact moves, the copy does not, and nothing tells you. So the
routers point and stop. If you improve one, keep it pointing — and if the section you want does
not exist, that is worth reporting upstream rather than writing the missing prose into a skill
file.

The pattern, the citation guard that makes a stale pointer fail the **upstream build** rather
than your agent, and the A/B rule that a pack must earn its keep on measures, are all in
[`skills/README.md`](skills/README.md).

**Version skew is the known cost of copying.** The pack points at the release it was copied
from; your artifact may be older. Each file says which release it came from and tells you to
run `scripts/update_vendored.sh`. After any refresh, re-run `install-skills.sh` so the pointers
and the artifact move together.

---

## Refreshing later (always deliberate)

When the nag tells you an update exists — or any time you choose — run **your own copy** of the
refresh script from your repo root:

```bash
scripts/update_vendored.sh            # build + vendor the LATEST release tag
scripts/update_vendored.sh v1.2.0     # build + vendor a specific tag
scripts/update_vendored.sh --check    # report-only: is a newer tag available?
```

After a real (non-`--check`) run, re-pin the line it prints and re-install it into your
environment (Step 2, refresh column). That is the *entire* update loop — nothing about it is
automatic.

**Exactly one artifact lives in `./vendor/`.** The refresh removes older ones before copying
the new one. If a second one ever appears, `--check` **refuses to guess** which is current
instead of picking one by sort order — because picking wrong means a healthy checkout reports
"UPDATE AVAILABLE" and offers a **downgrade** as the remedy. Delete the stale artifact, keeping
the one your manifest pins, and re-run.

**What a refresh leaves in `./vendor/`.** The artifact plus one copy of each release document
the project ships, all refreshed on every run and all taken from the tag you vendored, so after a
successful run they describe the artifact sitting next to them:

| In `./vendor/` | What it is |
|----------------|------------|
| `<the artifact>` | The thing you pin. |
| `<vendored-name>-GUIDE.md` | Usage recipes + what the project can and cannot do. |
| `<vendored-name>-CHANGELOG.md` | The full engineering log. |
| `<vendored-name>-RELEASE_NOTES.md` | **What changed that affects you**, release by release — public surface, observable behaviour changes, new refusals, configuration and permission requirements, dependency moves, known limitations. Read this one before you re-pin. |

A tag older than one of those documents simply skips that drop with a logged note; the refresh
still succeeds. (Which documents land is the `RELEASE_DOCS` seam in `update_vendored.sh` —
projects ship different sets.)

**`--check` also tells you what you would be getting.** When a newer tag exists it prints the
release notes' section headers for the versions in between, plus the subsection titles that
have something to say — so "should I update?" is answered with the reason, not just a version
number. It stays report-only: it never writes to `./vendor/`, never updates, and **its stdout
stays exactly one verdict line** (`UP TO DATE` / `UPDATE AVAILABLE` / `AHEAD`) because the hook
and the CI templates **grep** it; the detail is printed alongside, on stderr. Reading those
headers costs a small throwaway clone — set `VENDORED_CHECK_NOTES=0` to skip it and keep the
check to a single lightweight remote query. The advisory git hook already does exactly that, so
your `git pull` stays fast.

---

## What each file in `consumers/` is for

| File | Purpose |
|------|---------|
| [`setup-consumer.sh`](setup-consumer.sh) | One-time onboarding: copies the scripts, vendors the artifact, prints your to-do list. |
| [`update_vendored.sh`](update_vendored.sh) | The refresh script (copied into your `scripts/`). Builds/vendors an artifact; `--check` reports only. **All project values are named seams at the top of the file.** |
| [`hooks/post-merge`](hooks/post-merge) | Advisory git-hook template (nag only). `setup-consumer.sh` copies it into your `scripts/`. |
| [`skills/`](skills/README.md) | The router-pack pattern, the citation guard, and one skeleton (`EXAMPLE-start-here/`). Author your own routers here; `install-skills.sh` skips the README and `EXAMPLE-*`. |
| [`install-skills.sh`](install-skills.sh) | Copies the pack into your `.claude/skills/`. Enumerates the directory, so it needs no editing when a router is added. Re-run after every refresh. |
| [`ci/`](ci/) | Two opt-in, advisory, non-failing CI templates (forge-generic + GitHub Actions). |

You never need to read the upstream **source** to consume the project — these consumer files
plus the vendored documents are the whole contract.

---

## For maintainers: the seams you must fill

In [`update_vendored.sh`](update_vendored.sh) (one block at the top, plus the seam functions below):

| Seam | What it is |
|---|---|
| `VENDORED_NAME` | The name of the thing you ship. |
| `UPSTREAM_REPO_URL` | **The single migration point.** Keep it one line: a forge move then costs each consumer one edit. |
| `ARTIFACT_GLOB` | Which files in `./vendor/` are the artifact — must never match a dropped document. |
| `TAG_PREFIX` / `RELEASE_TAG_RE` | Your release-tag convention. Non-release tags must never be picked as "latest". |
| `RELEASE_DOCS` | The release documents you ship, and the names they are dropped under. |
| `build_artifact()` | Your build command, run against the checked-out tag, output to a scratch dir, **all chatter on stderr**. |
| `artifact_version()` | Version out of an artifact filename. |
| `ver_gt()`, `notes_headers()`, the two `--sort=-v:refname` tag picks | Only where your versions are not digits-and-dots: the one version comparison (`--check` uses it too), the release-document header reader, and how the latest tag is chosen. They sit below the seam block; replace them together with `artifact_version()`. |
| `pin_line()` and `install_hint()` in `update_vendored.sh` — where both are AUTHORED | Your pinning mechanism, and the two install hints (first-install resolves dependencies; refresh does not). `setup-consumer.sh` only CAPTURES the pin line into `PIN_LINE=` and prints one hint; editing it there changes what is displayed, not what is produced. |

Then fill this page's `<angle-brackets>`, and read
[`process/doctrine/distribution.md`](../process/doctrine/distribution.md) for the rules the
script encodes: the tag is authoritative, the distribution branch is a fast path and never a
requirement, `--check` never mutates, exactly one vendored artifact, and a template change is
worth a re-copy note in the release documents.

## How this machinery is tested (maintainer-side, never consumer-side)

The kit's own harness (`scripts/test/run.sh`) carries a consumer-updater family gated on the
`CONSUMER_SCRIPT` seam: a project that declares an updater sets it (in the harness config or
env) and gets contract smoke checks — syntax, a working `--help`, and `--check` proven
report-only. **Consumers never run this**; it is the kit maintainer's gate. The DEEP scenario
matrix (the three verdicts, the multi-artifact refusal, the reachable no-artifact failure) is
per-project by nature — the artifacts it must fabricate are the project's — and belongs in the
distributing project's own test surface.
