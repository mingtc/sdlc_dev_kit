<!-- KIT-CLASS: KIT — contract sheet: the progress record. See process/EXTRACTION.md. -->
# CONTRACT — the progress record

## 1. PURPOSE

To give an operator, an orchestrator or a successor one place to read *which phase, how long,
what is left* **after the terminal has scrolled away** — without any of them having to learn a
second format, and without any producer depending on being read.

**The beneficiary is the operator first, and that is the test this contract must pass.** A record
that only makes sense to a watching process fails it.

## 1a. THE SCOPE IS TWO CONSUMERS, DELIBERATELY

This contract is **converged narrowly on purpose**. The population of shipped scripts that
announce phases, and of roles whose lifecycle is enumerable in advance, is derivable — both
derivations are in § 5a — and **most of it is deliberately unconverted.**

*Why:* a format is specified from conviction until a run has used it. Converting everything first
means the format proves slightly wrong after its first real run and the migration is then over
every role and script rather than over two. **Widen only after a run has exercised these two**,
and widen from the derivation in § 5a rather than from memory.

## 2. HARD INVARIANTS

- **ONE record shape. Optional FIELDS, never divergent payloads.** Four required fields
  (§ 5), and everything else is an additional `key=value`. **A reader that understands only the
  four required fields must be able to read every record**, and that is the test.
  *Why:* a script's phases are known at authoring time while a role's path branches — QA bounces
  or lands — and that looks like an argument for two shapes. It is not: a branch is an optional
  field, and a divergent payload is exactly what forces the fork in the parser. **A format with a
  fork in the middle has to be learned twice**, and the whole value here is that a dashboard, an
  orchestrator, an operator and a successor reading a post-mortem all need to know one thing
  before they can read anything.
- **ONE declared location, with a structure — not one file.** A single directory, named by a
  declared seam, holding records partitioned by day.
  *Why:* "wherever the script felt like putting it" is the state this contract replaces; a reader
  who must first discover the location has not been given a record.
- **ONE location PER REPOSITORY, not per checkout.** Every worktree of one repository writes to the
  same directory, which by default sits at the **main** checkout, never the worktree the writer
  happens to stand in. The declared seam still overrides it. Where there is no main checkout (a
  bare repository's linked worktree), or where it cannot be identified (for example a submodule),
  the writer's own checkout is the fallback, and the implementation says which.
  *Why:* dispatched work runs in linked worktrees, and those are removed when the work lands. A
  record written under one lands where the reader does not look, and is then deleted with it.
  *Consequence, stated so it is not discovered:* expiry runs on write, so every worktree's writer
  now expires the one shared directory — a leg's own TTL setting governs the orchestrator's records
  too. Keep the TTL one value per repository.
- **A timestamp is REQUIRED and it is absolute.**
  *Why:* it is what makes elapsed time and liveness **exact** rather than inferred. Every other
  way of knowing how long a phase took reconstructs it from arrival order, which is wrong the
  moment two producers write concurrently.
- **The actor is ASSIGNED BY THE CALLER, never self-reported by the agent**, and it **has a
  declared shape** (§ 5b) rather than a convention.
  *Why:* attribution an agent reports about itself is attribution an agent can get wrong. Where
  the dispatching or invoking site already knows the answer — and it does, wherever a hat and an
  id were passed in as arguments — reading it there costs nothing and cannot drift. **And a
  column with no declared shape is one a reader can only filter on best-effort**: it holds
  whatever each caller happened to type, so `actor` earns the same closed treatment `class` has.
- **TRANSIENT BY CONSTRUCTION.** The location is version-control-ignored, records expire on a
  short declared TTL, and expiry runs as a side effect of writing rather than as a task somebody
  must remember. **The rule to write down: *nobody should ever have to dig through old logs for
  anything.*** Durable insight continues to live in reports, the card's activity log and change
  files.
  *Why:* a transient record nobody must curate can be written freely; a durable one immediately
  acquires a retention question, a review question and a privacy question, and the value here
  does not pay for any of them. If you want to keep one of these, what you want is a change file.
- **NEVER A DEPENDENCY, AND THE ABSENCE OF THE WRITER IS A NO-OP.** No producer's verdict, exit
  status or output may change because a record was or was not written. A missing library, an
  unwritable directory or a full disk degrades to silence.
  *Why:* the moment a gate can redden because a log directory was read-only, this stops being
  additive and becomes a new way for unrelated work to fail.
- **AN UNSUBSCRIBED RECORD MAY BE OMITTED.** If nothing is watching, a producer skipping its
  record changes nothing.
  *Why:* that is what makes this genuinely opt-in rather than a dependency wearing additive
  clothes.
- **EACH ADDITION MUST HELP WITH NO WATCHER AT ALL.** A field that exists only to feed a
  dashboard fails this test and does not ship.
  *Why:* a contract justified by a consumer that does not exist yet is specified against a guess,
  and it will be widened by whoever builds that consumer rather than by what an operator needed.

## 3. REFUSAL CONDITIONS

**This contract has NO refusal conditions, and that is a decision rather than an omission.**

A writer here is forbidden to fail its caller (§ 2), so there is no error it could raise that the
caller would be allowed to act on. Every degradation is silent by design.

The one thing that must not happen quietly is **losing a record to a malformed field**. A record
whose class is not a member of the declared set is **written anyway**, normalised to the neutral
class, with the offered value carried in an optional field. **A record whose actor does not match
the declared shape is treated identically** — written, normalised to the reserved actor, offered
value preserved (§ 5b).
*Why:* dropping it would make a typo at a call site indistinguishable from work that never
happened — the one reading this format must never produce. **And refusing it would make this
library a dependency**, which § 2 forbids outright: a validator that can fail a caller is a new
way for unrelated work to go red.

## 4. WHAT GREEN MEANS

- Every record carries the four required fields, in the same positions, with the same separator.
- A reader that parses **only** those four fields reads every record in the corpus — including
  records carrying optional fields it has never heard of.
- Records past the TTL are gone without anyone having run anything.
- A record written from a linked worktree of a repository with a main checkout is in the main
  checkout's directory, and it is still there after that worktree is removed (§ 2 names the
  fallbacks).
- Removing the writer entirely leaves each converted producer's output and exit status
  **byte-identical**. *This is the one that must be measured by ablation rather than asserted:
  it is the invariant whose violation is invisible until something unrelated turns red.*

## 5. MINIMAL INTERFACE

**In:** an actor, a class, a description, and zero or more optional `key`/`value` pairs.

**The four required fields:**

| field | why it is required |
|---|---|
| `timestamp` | makes elapsed time and liveness EXACT rather than inferred |
| `actor` | who wrote it — assigned by the caller, in the shape § 5b declares |
| `class` | one of `status` / `info` / `warning` / `error` — what a reader filters on |
| `description` | the human-readable line |

**Out:** nothing a caller may read. A write either happened or did not.

**For the operator:** a way to read the most recent records back, in arrival order, with no
argument required. That read is not a convenience — it is what discharges § 2's *must help with
no watcher at all*, so an implementation without it has not implemented this contract.

## 5a. THE POPULATION, AND HOW TO DERIVE IT AGAIN

**Do not trust a list here; run these.** Both are stated as commands rather than as counts
because a transcribed census is wrong the first time a script is added
([`../EXTRACTION.md`](../EXTRACTION.md) § The one rule about counting).

Shipped scripts that **announce a phase at run time** — an `echo`/`printf` whose payload opens
with the phase marker, as distinct from a comment separator that merely contains it:

```sh
grep -rlE '^[[:space:]]*(echo|printf)([[:space:]]+-[A-Za-z]+)*[[:space:]]+"──' scripts consumers setup.sh
```

*Control the pattern before trusting its answer.* A looser match on the marker character alone
returns most of the tree, because the same glyph rules the comment banners.

Roles whose lifecycle is **enumerable in advance** — a numbered workflow:

```sh
for f in .claude/roles/*.md; do
  printf '%s %s\n' "$f" "$(awk '/^#+ +(Workflow|The flow)/{w=1;next} /^## /{w=0} w&&/^[0-9]+\./{c++} END{print c+0}' "$f")"
done
```

**A CONVERTED PRODUCER NEED NOT BE A MEMBER OF EITHER DERIVED SET, and conflating the two counts
is the first mistake available here.** The board mover appears in neither derivation — it emits no
phase marker, and it is not a role document — yet it is one of the two converted producers, because
it is where a role's transition already passes. So *"how many producers are converted"* and *"how
much of the derived population is converted"* are different questions with different answers, and
adding them reports a narrow change as a broad one.

**Most roles need nothing from this contract**, and that is the expected answer rather than a gap:
where a role's transition already passes through a script that was given the hat and the id as
arguments, converting *that script* records the role's lifecycle with **no reporting obligation on
the role at all**. Prefer that every time it is available — it is the version an agent cannot get
wrong.

## 5b. THE ACTOR'S SHAPE, AND THE RESERVED EXTRA KEYS

### The actor

**Two kinds, because the converted producers are two kinds** — § 5a's rule that a converted
producer need not be a member of the role population is the reason this is not one:

| kind | shape | example |
|---|---|---|
| role side | `<role>` or `<role>:<issue-id>` | `Dev`, `Dev:<PREFIX>-042` |
| script side | `<name>.sh` | `verify.sh` |

**The role vocabulary is DERIVED, never listed here.** Run it:

```sh
sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" scripts/githooks/commit-msg | head -1
```

That is the same seam `scripts/lib/role-set.sh` reads and the same one the commit-msg hook
enforces, so a project that narrows its role set narrows this column with it and nothing needs
re-typing. *A list written here would be a second declaration of a fact that already has an
authoring site, and the second one drifts.*

**The role is matched CASE-SENSITIVELY.** The hook matches its tags case-sensitively, so `dev` is
not the seat `Dev` anywhere else in this kit; accepting it here would put two spellings of one
seat in the column, which is the split this shape exists to close. Normalising the case instead
would rewrite attribution § 2 reserves to the caller.

**An actor matching neither kind still writes.** The column is set to the reserved value
`unknown` and the offered value is carried in `declared-actor=<value>` — exactly as an unknown
class is carried in `declared-class=`. So a typo is **visible** rather than either lost or
silently accepted, and `actor != unknown` is a filter a reader can trust.

**The shape has two halves, and only one of them needs the role set.** The STRUCTURAL half — a
non-empty role, a non-empty id after any colon, and no whitespace anywhere — is true of the
declared shape on every tree, so an implementation checks it unconditionally. The MEMBERSHIP half
is the role-set lookup.

**An unreadable role seam ACCEPTS the membership half rather than tagging it**, and that policy
differs from every other reader's on purpose. `kit_require_role` announces its skip on stderr and
`kit_role_resolve` substitutes a stamped default and says so; a writer bound by § 2 can do
neither, since it may not write to stderr and may not fail its caller. So it takes the harmless
direction: tagging every role-side record on a tree whose hook was deleted would turn a missing
hook into a **poisoned log**, corrupting the column this shape exists to make filterable, whereas
accepting them leaves the column exactly as filterable as it was before. **The structural half is
still enforced there** — an unreadable seam stops the writer guessing *which roles are legal*, not
*what the shape is*.

**An implementation reads the role set through the seam's OWNER and holds no copy of the read.**
A second copy of that expression is the defect [`../EXTRACTION.md`](../EXTRACTION.md) § 2.4 exists
to catch, and calling it a fallback does not make it anything else: the copies then disagree about
the same file with nothing in either to show it.

### Reserved extra keys

Extras are otherwise free-form `key=value`. **A key with a meaning readers rely on is declared
here rather than invented at a call site**, for the same reason the class enum is closed: two
callers inventing the same key with different shapes is a filter that silently under-collects.

| key | shape | written when |
|---|---|---|
| `run=` | a single token — a run or session id | a run id is in scope (below) |
| `declared-class=` | the offered class, normalised to one token | the class was outside the enum |
| `declared-actor=` | the offered actor, normalised to one token | the actor was outside § 5b's shape |

**A preserved value is collapsed to ONE TOKEN.** Extras are read back by splitting the field on
spaces, so whitespace inside a value would split one key into two and hand a reader a `key=value`
nobody wrote. An empty value is written as a placeholder rather than as nothing after the `=`.

**AND COLLAPSING TOUCHES WHITESPACE AND NOTHING ELSE: a value that is ALREADY one token is
carried BYTE FOR BYTE.** The declared keys exist to keep an offered value VISIBLE — a typo the
caller made is preserved so a reader can see it — so a writer that rewrites a value nobody asked
it to rewrite defeats the key's whole purpose. The failure is also worse than the split the
collapse prevents: a split record is *visibly* malformed and any tokenising reader trips on it,
whereas a quietly shortened value is **well-formed and wrong** — it parses, it reads as an answer,
and nothing in the record shows that the caller offered something else. **An implementation that
substitutes a separator must not then trim that separator from the ends**, because at that point
a substituted separator and one the caller typed are the same character and no trim can tell them
apart. Trim the whitespace at the edges *first*, while it is still whitespace; collapse what is
left in the interior after.

**AN EXTRA'S VALUE IS ONE TOKEN, AND THAT IS THE CALLER'S OBLIGATION — THE WRITER CARRIES IT
VERBATIM RATHER THAN REPAIRING IT.** The same split applies to an extra the caller passed:
`step=13 of 13` reaches a reader as the key `step=13` followed by two bare tokens. But a caller's
`key=value` is the caller's, and the writer's only duty is to keep the record one line with its
four columns.

- **This is stated rather than enforced, and that is a choice.** Normalising the value half would
  make the writer rewrite data the caller typed — which is the very defect the byte-for-byte rule
  above forbids for the keys the writer DOES own, and which § 2 reserves to the caller for
  attribution already. A
  writer cannot both decline ownership of a caller's values and repair them.
- **So a caller remains free to split the field.** There is no mechanism and no refusal. An
  unenforced obligation is weaker than a guard; it is the correct instrument only because the
  guard would have to take back ownership the writer deliberately declined.
- **A worked example in an implementation is the wording an adopter copies**, so an example that
  splits the field teaches the defect. Write `step=13/13`, never `step=13 of 13`.

**`run=` is an EXTRA and not a fifth required column, deliberately.** It groups an orchestrator
and every subagent it spawned across every producer — a reader greps `run=<id>` — and a run that
spans midnight is two day files and one grep. Making it required would oblige every reader that
does not care about runs to learn it, which § 2's four-field envelope exists to prevent.

- **It comes from a declared environment seam** — `KIT_PROGRESS_RUN` in the reference
  implementation — and **empty or unset writes no key at all** —
  never `run=` with nothing after it. An empty key is a column that looks answered and is not,
  and it would make a reader filtering on `run=` collect every unrelated record.
- **An explicit `run=` argument WINS over the environment**, and never produces two keys. The
  environment is ambient and inherited; an argument was typed at that call site for that record.
  That precedence is what lets a caller change the run id on the fly without disturbing an
  environment its children also read.
- **PROPAGATION IS NOT GUARANTEED, AND THIS IS A STATED LIMIT RATHER THAN AN OVERSIGHT.** A
  subagent spawned with a cleared environment writes records with **no `run=` and says nothing
  about it**. No writer can detect that from the inside — there is no difference it can see
  between "no run in scope" and "a run whose id was dropped on the way in". **The dispatching
  site owns passing it on.** Written down because an unset seam that degrades silently is the
  shape a reader mistakes for a working one.

## 6. REFERENCE IMPLEMENTATION

**One implementation, not the definition.**

- [`scripts/lib/progress-record.sh`](../../scripts/lib/progress-record.sh) (`KIT-CLASS: KIT`) —
  the one writer. Tab-separated, four fixed columns then `key=value` extras; one file per UTC day
  under a version-control-ignored directory at the main checkout's root, from the first entry of
  `git worktree list`, accepted only when it is not bare and is its own top level; expiry on write.
  It validates the class and the
  actor the same way — write, normalise, preserve the offered value — and reads the role
  vocabulary from the seam § 5b names rather than holding a copy of it.
- Converted producers, and **only** these two: [`scripts/verify.sh`](../../scripts/verify.sh)
  (the script side — per-gate start and outcome, plus one run summary) and
  [`scripts/move-issue.sh`](../../scripts/move-issue.sh) (the role side — the board transition,
  recorded after the push and never before).

Tab-separated rather than JSON deliberately: the four required columns are then split by any
reader in any language with no quoting rules to agree on first, and `awk -F'\t'` is the floor this
kit already requires. JSON needs an encoder in every writer.
