<!-- KIT-CLASS: KIT — transferable doctrine. § A is the pattern; § B is the adapter's fill-in, with anonymized worked examples from the donor project. -->
# Distribution doctrine — shipping a project into other repositories

**KIT-CLASS: KIT.** Seven rules for the case where your project is not the end of the line:
something else vendors it. § A is the transferable pattern. § B is what the project adapter
fills in.

**Scope.** This sheet governs **outbound distribution** — an artifact you build, a consumer
that pins it, and the thin machinery in [`consumers/`](../../consumers/README.md) that keeps the
two in step. If your project ships to nobody, none of it binds you; delete `consumers/` and
stop here. **Nothing in this kit requires a forge**: every rule below works with a local bare
repository as the remote (see [`GIT-HOSTING.md`](../GIT-HOSTING.md)).

**Why it is written down at all.** Distribution failures are **slow** failures. A consumer
holds a *copy* — of your artifact, of your updater script, of your documents — and a copy that
drifts announces nothing. The default outcome of an undocumented distribution model is a set of
downstream repos each running some past version of everything, with nobody able to say which.
Every rule below exists to make one of those silences loud.

**Neighbour sheet.** [`supersession.md`](supersession.md) binds this one: when evidence
overturns a rule here, keep the reason and replace only the conclusion. The reasons in § A are
the load-bearing part — several of them are incidents, and an incident with its reason stripped
gets re-lived.

---

## A. The pattern (this is the transferable part)

### A.1 — **The tag is authoritative**

> Every released version must be reproducible from its **tag in the source repository**, using
> only a clone, a checkout, and the project's own build. Every other channel — a distribution
> branch, a package index, a cached build, an artifact somebody emailed you — is a
> **convenience** that may be absent, stale, or wrong, and must be treated as one.

The tag is the only channel you can still reconstruct after the forge changes, the index
account lapses, or the build cache is pruned. So the updater's build-from-tag path is not a
fallback in the apologetic sense — it is the definition, and the fast path is the optimization.

Two consequences the machinery has to honour:

- **A release tag must be recognizable by pattern** (`v1.2.0`-shaped, or whatever you choose),
  and "latest" must be computed over **only** those tags. Process tags, baselines and
  experiments live in the same namespace, and a version-sorted "newest tag" that does not
  filter will one day hand a consumer a refactor baseline as a release.
- **Ask for an old version and you get a build**, not an apology. Any channel carrying only the
  current release must decline politely and let the tag path run.

### A.2 — **The single-commit distribution branch** (the forge-agnostic releases page)

> A consumer-only branch, republished at every release as **one commit** carrying just the
> current release's artifact, its release documents, and a short README. `git clone --branch
> <dist> --depth 1 <url>` is then the entire consumer entry: no forge API, no release-page
> scraping, no credentials beyond the ones git already needs.

This is the cheapest way to give consumers a "releases page" when you cannot assume a forge has
one — and it is why a local bare repository is a complete distribution endpoint.

**The tradeoff, stated plainly:** the branch is **replace-history**. Each publish force-pushes
a fresh single commit, so **its history is not a record and older releases are not on it, by
design.** That is the price of it being small and cheap; A.1 is what makes the price payable.

Three rules keep that from becoming a trap:

1. **Force-push is normally forbidden; this branch is the named exception.** Write the
   exception down beside the rule it breaks, name the branch in it, and never use the branch
   for anything else. An unnamed exception becomes a habit.
2. **A publish can fail, so the branch can lag the tag.** Consumers must therefore treat it as
   a **fast path with a fallback** — verify it carries the version being asked for, and drop to
   the tag path otherwise. Never let it be the only path.
3. **Exclude it from anything that walks branches** — CI that builds every branch, board or
   release tooling that enumerates refs, "stale branch" reports. It is not development work and
   it will trip anything that assumes branches contain source.

### A.3 — **The consumer-updater contract**

> The refresh script is a **tool other tools call**. Its interface is therefore a contract, and
> the contract is: **one machine-readable verdict, report-only checks, and no mutation you did
> not ask for.**

- **Exactly one verdict line on stdout, and it is a grep target.** A check prints one of a
  small closed set of verdicts (this kit's set: `UP TO DATE` / `UPDATE AVAILABLE` / `AHEAD`).
  **All narration goes to stderr** — every log line, every warning, the whole what-changed
  report. This one property is what lets a git hook and a CI job consume the script with
  `head -1` and a `case`, instead of a parser that breaks the next time you add a log line.
- **`--check` NEVER writes.** Not to the vendor directory, not to the repo, not anywhere.
  Everything it needs that is not already on disk comes from a throwaway clone it deletes
  before returning.
- **A report must never break the answer it decorates.** Every failure path in the
  decorative part of a check — no temp dir, clone refused, a tag with no notes, an empty
  version span — prints a note and returns **success**. The verdict is the product; the
  explanation is a bonus and must degrade like one.
- **Automation may report; only a human updates.** Nags (hooks, CI) are advisory by
  construction: they swallow errors, always exit successfully, and never touch the vendored
  artifact. A nag that can fail a build or break a `git pull` gets uninstalled, and then you
  have no nag at all.
- **A machine-readable answer is a declared output, not a substring of a human line.** When a
  sibling script needs a value the updater knows (where the vendored artifact lives, what the
  artifact glob is), give it a **declared** way to ask. String-slicing the human-facing pin
  line couples every caller to one project's pinning syntax — and the coupling is invisible
  until the syntax changes.
- **The build's chatter belongs on stderr too.** Build tools are loud on stdout; one stray line
  and the pin line is no longer the whole answer.
- **Two install hints, not one.** A **first install** must resolve transitive dependencies; a
  **refresh** must not (only the artifact moved, and re-resolving can silently move versions
  nobody asked to move). Print the one that matches the situation, and say which it is.

### A.4 — **Vendored-artifact hygiene: exactly one, and ambiguity is a refusal**

> A consumer's vendored directory holds **exactly one** pinned artifact. When it holds more,
> the tooling **refuses and says what it found** — it never picks one.

**The incident (worked example from the donor project, anonymized).** The updater answered
"which version is vendored?" by listing the artifact glob and taking the first entry. That
directory is **long-lived**: a stale artifact can sit beside the current one, from a
half-finished refresh, a bad merge, or a hand copy. Sort order then decides the answer — and
when it picks the older file, a perfectly healthy checkout reports **UPDATE AVAILABLE** and
offers, as the remedy, a **downgrade**. The remedy is worse than the disease, and everything
about the report looks correct.

**The rule and its nuance.** Which artifact is current is a question only a human can answer, so
the tooling refuses, lists the candidates, and says what to delete. **But the idiom is not the
problem — lifetime is.** "Take the first match" stays *correct* in a directory the run itself
just created (a build output directory, a fresh shallow clone), because such a directory cannot
hold a stale artifact. Keep the fast idiom where it is safe, refuse where it is not, and write
the distinction next to both so the next reader does not "fix" the safe one or trust the unsafe
one.

**A second finding from the same fix, worth its own rule: capture, then test, then select.**
Written as one line, `X=$(list-things | head -1)` fails the **assignment** when nothing matches
under strict shell error handling — so the `[ -n "$X" ] || die "..."` written on the next line
is **unreachable dead code**, and the failure it exists to explain dies bare, with no message.
Capture with an explicit "empty is allowed", test, *then* select.

### A.5 — **The release documents travel WITH the artifact**

> Every refresh drops the project's release documents — the usage guide, the changelog, the
> consumer-facing release notes — **beside** the artifact, sourced from the same checked-out
> tag, so they always describe the artifact sitting next to them.

**Why:** a vendoring consumer's *entire* view of your project is the artifact plus whatever
lands beside it. Without the drop, "what changed under me since I last re-vendored?" has **no
in-band answer** — the consumer must find your repo, guess a tag, and read. Two further
properties make the drop trustworthy:

- **From the tag's own tree, before the build.** Deterministic, and the same bytes that tag
  ships. Not from the built artifact, not from the trunk.
- **A missing document is a logged skip, not a failure.** Any tag older than a document
  genuinely does not carry it; that is a normal case for a while, and the refresh must still
  succeed.

### A.6 — **Update communication: a template change means a re-copy note**

> Consumers hold **copies** of the consumer-facing templates — the updater script, the nag
> hook, the CI job, the skill pack. Editing your copy upstream changes **nothing** downstream.
> So a change to any of them earns a note in the release documents telling consumers to
> **re-copy it**, and the note is placed **by the release documents' own criteria** — you do
> not invent a new section for it.

The failure this prevents is total silence: every consumer keeps running last year's updater,
including its bugs, and the fix you shipped reaches nobody. That last clause matters most for
**bug fixes in the updater itself** — the consumer running the buggy copy is exactly the one who
will never notice.

Two escalations of the same rule:

- **A change to the verdict strings or the stdout contract (A.3) is a BREAKING change** for
  every hook and CI job that greps them. Announce it as one.
- **A change to the skill pack** means "re-run the installer", which onboarding already says —
  say it again in the notes, because nobody re-reads onboarding.

### A.7 — **The updater reads the REPO, not the artifact**

> A freshness check's what-changed report is read from the **upstream repository at the tag**
> (a throwaway shallow clone), never from the vendored artifact — because the consumer does not
> *have* the new artifact yet. That is the whole point of checking.

This finding has one consequence in each direction, and both are easy to get backwards:

- **Truncating release notes INSIDE the artifact is safe for the check.** If you ship only the
  most recent releases' notes inside the artifact to keep it small, the check's delta is
  unaffected — it never reads the packaged copy. Decide in-artifact truncation on artifact-size
  grounds alone.
- **Compacting the notes file IN THE REPO degrades the check.** Archive or fold away old
  sections and a consumer who skipped many versions gets a **silent gap** in the report. If you
  compact, keep the section **headers** (they are what the delta prints), or keep an archive
  file the updater is taught to read as well.

**And when a version is missing from the notes, say so.** Read the version headers from *both*
the notes and the changelog and take the union: a version the changelog documents and the notes
do not is an **un-noted release**, and printing "this version has no notes section — see the
changelog" beats leaving a gap the reader will not notice.

---

## B. Project duties — filled by the adapter

The rules above are the pattern. **These are the values and duties one project supplies**; fill
them in the adapter (`CLAUDE.md` / `PROJECT.md`) and in the seam block at the top of
[`consumers/update_vendored.sh`](../../consumers/update_vendored.sh). Delete this section
wholesale if the project ships to nobody.

| Duty | Fill in |
|---|---|
| **Do we distribute at all?** | `<yes / no>`. If no: delete `consumers/` and this sheet. |
| **What is the artifact?** | `<one built file per release, of kind …>` — and the glob that matches it and nothing else. |
| **The upstream remote** | `<url or local bare repo path>` — recorded on **one line**, in one file (A.1, and the migration point below). |
| **Release tag convention** | `<pattern>`, and which tags are explicitly **not** releases. |
| **Release documents shipped** | `<the list>`, and the name each is dropped under beside the artifact (A.5). |
| **Distribution branch** | `<branch name, or "none">`. If used: where the force-push exception is written down, and where the branch is excluded from branch-walking tooling (A.2). |
| **Who publishes, and when** | `<the release step that publishes, and whether a dry run publishes nothing>`. |
| **Pinning mechanism** | `<how a consumer records the artifact>`, and the two install commands (first install vs refresh, A.3). |
| **Release-notes criteria** | `<what earns a note>` — so A.6's "placed by the notes' own criteria" has criteria to obey. |
| **Consumer register** | `<none — self-service>` *(the default: consumers are not tracked, and the update loop is pull-based)*, or `<where consumers are listed and who tells them>`. |

**Worked examples from the donor project, anonymized** — kept because each carries a reason
that generalizes, and a reason removed is a reason re-learned:

1. **The one-line migration point.** The donor kept its upstream URL on a single line in a
   single file, with a comment saying *why* it was alone there. It then migrated forges once,
   mid-life: because the value lived on one line, each consumer's migration was a one-line edit
   plus one re-vendor. **Keep the seam, keep the comment.**
2. **The downgrade hazard.** A.4's incident is this project's — found by reading, not by an
   outage, which is the only cheap way to find it. The fix shipped **both** the refusal and the
   nuance comment explaining where the fast idiom stays correct, so the next reader does not
   "simplify" it back.
3. **The advisory nag that opted out of its own extras.** The donor's `--check` gained a
   what-changed report that costs a shallow clone. The nag hook, which runs on every pull,
   sets the environment flag that skips it — because *a nag slower than the thing it nags about
   gets uninstalled*. Cheap by default, detailed on demand.
4. **The pack that had to earn its keep.** The donor shipped a consumer-side router skill pack
   built to be **A/B measured** — the comparison designed and written down *before* the pack
   was called valuable, with thinness as the variable under test. The rule that travels is in
   [`consumers/skills/README.md`](../../consumers/skills/README.md): a pack that does not win on
   measures gets deleted, not defended — and it stays deletable only while it contains
   **addresses and no content**.
