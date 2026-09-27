<!-- KIT-CLASS: KIT — contract sheet: the initializer. See process/EXTRACTION.md. -->
# CONTRACT — the initializer

## 1. PURPOSE

To turn *"the process is installed"* from a belief into a **proven state**, by performing every
precondition the process depends on and then demonstrating each one working.

## 2. HARD INVARIANTS

- **It CONFIGURES; it does not copy the process in.** The list of what travels is authored in the
  manifest, and the initializer does not carry a second copy of it.
  *Why:* two copy-lists drift, and the executable one wins by accident.
  The build ships a machine-readable manifest, `process/KIT-MANIFEST`, generated from the tree;
  reading it is not carrying a second copy. The preflight uses it for exactly ONE question — is any
  shipped path on disk and not committed (§ 3) — and enforces presence only for a **hand-listed
  minimum**, for the reason § 3 gives.
- **It PROVES what it claims, by exercising it.** After configuring, it creates a throwaway work
  item, moves it, asks the drift report for a verdict, and forces a deliberately-invalid commit to
  be rejected.
  *Why:* every finding in this kit's own cold-read review was found by reading, and every one of
  them would have been found by running.
- **The proof cleans up after itself.** The throwaway artifacts of the self-check do not survive
  it.
  *Why:* a first day that ends with a fake item on the board teaches that the board holds noise.
- **A SECOND run refuses, and writes nothing.** It names what is already configured and stops;
  there is no resume path.
  *Why:* a half-configured repository is the worst state available, and resuming into one requires
  knowing which half is real — which nothing can know.
- **A repository that has already lived is protected by the same refusal.** Existing work items, an
  existing history, an existing index: each is evidence that this repository is not new.
  *Why:* the destructive case is running the initializer in a working repository, and it must be
  refused by a rule rather than by the operator's memory.
- **The trunk is REQUIRED and CONFIRMED, never inferred.** It is supplied explicitly and
  cross-checked against the publication remote's own answer; a disagreement refuses.
  *Why:* silently defaulting the trunk is how the first board change goes to a branch nobody
  meant.
- **It GUIDES toward topology decisions; it does not make them.** Creating a publication remote is
  refused with a complete recipe — including the offline, local-bare-repository path — rather than
  performed.
  *Why:* where a project's code lives is not an initializer's call.
- **Session state is EXCLUDED FROM VERSION CONTROL by the initializer, not by each actor.** The
  hat declaration's own path, and the auxiliary checkout's, are written into the ignore list as
  part of installation.
  *Why:* measured — versioned session state forks per branch, blocks a branch switch, and reaches
  a landing gate as a merge conflict over a fact nobody was collaborating on. Four actors paid for
  it in the first twelve hours of one adoption.
- **A substitution NAMES THE SPACE IT REWRITES, and a convention's KEY is not in it.** The stamper
  rewrites **values** — an identifier prefix, a trunk name, a project name. It never rewrites the
  **key** of a convention, even where that key is spelled with the same characters as the
  placeholder being replaced. **And any census of surviving placeholder residue exempts those keys
  in the same change**, or protecting the key from the rewrite merely moves the failure into the
  census.
  *Why:* measured. The shipped classification marker's key begins with the same literal as the
  shipped placeholder prefix, so a prefix substitution rewrote the **key** and left the **value** —
  every stamped file carrying the marker came out with a line that refutes itself, and every work
  item minted afterwards inherited it. **The general form is worth more than the instance: a
  substitution whose pattern is a placeholder literal will match every convention that uses that
  literal as a key** — and the collision is found by grepping for a marker that is no longer there,
  which is to say it is found late. *(The two halves are one change or neither works: the shipped
  census matches the same residue pattern, so exempting the key from the rewrite without exempting
  it from the count trades a defaced marker for a failed self-check.)*
  *Authoring site:* the convention, and both halves of this rule stated for the **authors** of
  conventions rather than for the tool, are [`../EXTRACTION.md`](../EXTRACTION.md) § The one file
  classification convention. This sheet binds the initializer; that section binds whoever invents
  the next convention. **They are one rule with two audiences and must not drift into two.**
- **Every precondition it performs is ASSERTED afterwards, with a count where a count exists.**
  Reporting success on a partial result is the failure this whole step exists to prevent.
  *Why:* "created the board" is not the same claim as "created every declared container and
  counted them" — and the count is **derived from the declared set**, never a hand-typed digit.

**The hooks path has TWO owners and one lifecycle, and every site that names it cites this row.**
`core.hooksPath` is **per-clone git config** — it is not committed and does not travel. So
`kit-init.sh` wires it **once at adoption**, and because it runs before the initialization commit it
is also the only one of the two that can commit the hooks' **executable bit** so a repaired mode
reaches every future clone. `setup.sh` re-wires and repairs it on **every fresh clone**, which is
the only thing that can, because a clone starts with neither.

## 3. REFUSAL CONDITIONS

- Any file in the preflight's **hand-listed minimum** — the files without which nothing else can
  run — is missing ⇒ refuse, naming each one. **This is a minimum presence check, not a manifest
  check**, and the difference is not an oversight. *The live reason:* a shipped file the adopter
  deletes is theirs to delete, so presence is enforced only for the files without which nothing else
  can run — a manifest-wide presence check would refuse every legitimate deletion. The next bullet
  reads `process/KIT-MANIFEST` for commitment, never for presence. **A file
  that travels but is not in the minimum is not caught here** — say so rather than implying a
  coverage the tool does not have.
- A shipped path — per the shipped `process/KIT-MANIFEST` — is on disk but not committed ⇒ refuse,
  naming them and the command that commits the kit. *Why:* the initializer commits only the paths it
  writes and trusts the first commit to hold the rest of the kit; an empty first commit made that
  false, and the run still reported success with the root documents, the adapter stub and the setup
  script untracked and absent from the trunk (measured). **On disk AND not tracked, never merely
  absent from HEAD:** a shipped file the adopter deleted before the first commit is theirs to delete.
  **An IGNORED shipped path counts:** ignoring is not how a shipped file is declined (deleting is),
  it leaves the file here and absent from every clone, and the usual cause is an ignore rule written
  for other repositories — measured: a globally ignored adapter file passed a version that asked
  only about untracked, non-ignored files. The refusal names the ignored ones and the explicit
  override. No manifest, or one with no readable paths ⇒ no check, and the run says so; no commits
  yet ⇒ the no-commits refusal already stands.
- A path the initializer will COMMIT is ignored ⇒ refuse, naming it and the rule's finder, with a
  remedy that un-ignores it in the repository. *Why:* the commit step names these paths explicitly,
  and version control refuses an explicit path an ignore rule matches even when everything beneath it
  is tracked — so the run failed **after** stamping, and the next run refused as already-lived: a
  half-initialized repository with no resume path (measured: `.claude/` in a local or global excludes
  file). The test is the commit step's own staging command, dry-run, so the preflight and the commit
  cannot disagree; the list of paths is declared once and both read it. Un-ignore rather than work
  round: the initializer commits these paths on purpose, and a staging step that skipped an ignored
  directory would silently drop what it later creates there.
- No publication remote, or the remote publishes no default branch ⇒ refuse **with the recipe**,
  including the offline path.
- The remote is a filesystem path that is not absolute ⇒ refuse, with the one-line fix. *Why:* the
  auxiliary checkout runs version-control operations from a different working directory, where a
  relative path resolves to nothing — and the failure otherwise surfaces mid-proof, disguised as an
  access error (measured 2026-08-26).
- A gate command is supplied but the gate definition already declares its gates, or is not the
  shipped frame ⇒ refuse; a declared gate table is never overwritten or appended to. (A supplied
  command **fills** the shipped frame's empty table, or writes a minimal runner where none exists —
  see § 6.)
- The supplied trunk disagrees with the remote's own default ⇒ refuse; do not pick a winner.
- The repository shows signs of already being configured, or of already having lived ⇒ refuse,
  naming the evidence.
- A required gate definition is absent and none was supplied ⇒ refuse. The landing gate depends on
  it existing before the first landing, not eventually.
- The post-stamp census finds a surviving foreign value ⇒ **fail loudly** — not *refuse*
  ([config-seam.md](config-seam.md) § 4.3). *The verb is exact and the distinction is this sheet's
  own: a refusal means **nothing was written**, and this census runs **after** the initializing
  commit. The tree is initialized when it fires. It reports a bad result; it cannot un-write one.*
- Any assertion in the self-check fails ⇒ fail loudly. A self-check that reports success on a
  broken installation is worse than no self-check.

## 4. WHAT GREEN MEANS

1. Every precondition is **performed and then asserted**, each printing its own confirmation.
2. The trunk is **printed as confirmed**, alongside the source it was confirmed against.
3. The self-check's every step passed — including the **rejected** invalid commit, which is the
   only proof that the attribution guard is actually wired.
4. A **single completion statement** and a zero exit status; anything less is a failure, not a
   partial install.

## 5. MINIMAL INTERFACE

**In:** the identifier prefix, the trunk, the role set, and the project's gate command; a
repository that already holds the files the manifest lists.
**Out:** a per-precondition confirmation, the confirmed trunk, the self-check's per-step verdicts,
one completion statement — or a refusal that names every blocking fact at once.
**Not in:** copying the process in, creating a remote, or choosing the project's gates.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/kit-init.sh` — KIT-CLASS: KIT. Configure, create the board, wire the attribution
  guard, write the ignore entries, commit and publish, then the placeholder-free self-check.
- [`../EXTRACTION.md`](../EXTRACTION.md) § 1.3 — the precondition table it performs, which doubles
  as the manual fallback for an adopter reimplementing it.
- Note for a reimplementer: given a gate command, that script **fills** the shipped gate runner's
  empty table when that is what it finds, and *writes* a minimal runner only when none exists —
  the write arm is why it contains a second class marker, belonging to the file it emits rather
  than to itself. The fill arm exists because the kit ships the runner: an initializer that
  refused on "the runner already exists" made the front door's own first command refuse on every
  fresh copy (measured 2026-08-26).
