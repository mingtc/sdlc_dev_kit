<!-- KIT-CLASS: KIT — contract sheet: issue / spec creation. See process/EXTRACTION.md. -->
# CONTRACT — issue / requirement creation

## 1. PURPOSE

To make every work item **born complete** — same shape, same required fields, same starting
state — so that every tool and every reader downstream can rely on the shape without checking.

## 2. HARD INVARIANTS

- **Every item is created from a template, and the template is the shape's only definition.**
  There is one template per item kind, and no other way to bring an item into existence.
  *Why:* a shape defined by example is re-derived slightly differently by every author, and the
  first tool that walks the board is the one that discovers it.
- **The structured header is a CONTRACT: a declared set of keys, every one present, each with a
  declared meaning.** An unset key appears with an empty or explicitly-empty value rather than
  being omitted.
  *Why:* "absent" and "empty" mean different things to a reader and the same thing to a careless
  parser; requiring presence removes the ambiguity.
- **Status is NOT one of those keys.** The item's state is its location, and the header never
  restates it.
  *Why:* two sources for one fact is the drift this whole kit is organised against.
- **The identifier is supplied by the caller and validated before anything is written.** Creation
  never mints its own — **with one declared exception, the specification stream**, whose creator
  derives its number itself because that stream has a single author and therefore none of the
  concurrency hazard this rule exists for ([id-minting.md](id-minting.md) § Spaces and streams).
  *The exception is named here rather than left to the tool, because § 6 binds that tool to this
  sheet: an unstated carve-out reads as the tool being in breach.*
  *Why:* creation is stateless and therefore repeatable and testable; the one place numbers are
  chosen stays the one place (see [id-minting.md](id-minting.md)).
- **The identifier in the header and the identifier in the item's own name AGREE.** The
  substitution that stamps the identifier keys on the header's *key*, never on a donor-shaped
  value, so it cannot silently match nothing.
  *Why:* a substitution that matches nothing fails silently and every created item carries the
  template's example identifier — which is exactly how one project produced a whole board of
  items whose header said one thing and whose name said another, and whose drift report then
  flagged every card on it.
- **Creation is inert.** It writes the new item and nothing else: no state change, no
  publication, no notification.
  *Why:* creating a description of work is not the same act as starting it, and conflating them
  makes drafting expensive.
- **Creation is inert — and therefore creation must SAY that the item is not yet published.**
  Because creation publishes nothing (invariant above), the new item exists only in the
  operator's workspace, and the board mover — which computes against the **published** board —
  cannot see it. Creation therefore prints the publication step as an unmissable next step, and
  does not perform it.
  *Why:* the two invariants together are a trap, and it caught **three independent agents** in
  three unrelated runs, each losing the same twenty minutes to a mover saying only that nothing
  matched. The fix belongs to the **prose and the error message**, not to inertness: a creation
  script that commits and pushes would publish drafts nobody has read and would break § 4.3's
  *"nothing else changed"*. The mover's half of this obligation is in
  [board-mover.md](board-mover.md) § 2.
- **A decomposed child names its parent, and the parent is a real item.** A child that names no
  parent, or an absent one, is an orphan the board cannot roll up.
  *Why:* decomposition whose links do not resolve is a tree only in the author's head.

- **THE ONE CARVE-OUT TO INERTNESS: a creator that writes INSIDE the mover's own publication area
  must publish, and says so.** The invariants above hold for every creator that writes into the
  operator's workspace, and their reason is untouched — creating a description of work is not
  starting it, and a script that published drafts nobody had read would break § 4.3. **But a
  creator whose file lands in the shared, trunk-pinned publication area is in a different
  situation: an unpublished file there is on no ref, invisible to every other lane, and — once
  staged — it blocks the next board operation, which refuses to sync over it.** Inertness there
  does not protect a draft; it strands one.
  So such a creator **publishes as part of creation**, and the carve-out is **contracted rather
  than tacit**: it names itself as the exception, states this reason, and the exception is scoped
  to *writing into the publication area* — not to a script, and not to a kind of item. A creator
  that could write elsewhere gets no carve-out for choosing not to.
  *Why the carve-out is written down instead of the behaviour being changed:* the alternative is a
  creator that appears inert and silently drops what it wrote, which is worse than either honest
  option — and **an implementation that deviates from its own contract sheet without the sheet
  saying so is a contradiction a reader must resolve by guessing.** Preserve the reason, narrow the
  conclusion ([`../doctrine/supersession.md`](../doctrine/supersession.md)).

## 3. REFUSAL CONDITIONS

- No identifier supplied ⇒ refuse; do not mint one silently. *The specification creator is § 2's
  declared exception and derives its own; every other creator here refuses.*
- The identifier is malformed, or already in use on the board ⇒ refuse (already-retired ⇒ warn
  loudly, per [id-minting.md](id-minting.md)).
- The template for the requested kind is missing ⇒ refuse; **never** fall back to writing an
  ad-hoc shape, because that shape immediately becomes a second definition.
- An item with the same name already exists ⇒ refuse rather than overwriting. Overwriting a
  description of work is data loss with no undo in the reader's hands.
- A decomposition names a parent that does not exist, is itself a child, or is retired (done or
  declined) ⇒ refuse. A done parent's tree is swept with it, new children included.
- **An argument standing in a NAME's position that carries an option's syntax — a leading dash —
  ⇒ refuse, non-zero, naming the position it was standing in.** A dash-leading token is never a
  name, in any position, however plausible it looks.
  *Why:* the failure this replaces was not a refusal — it was an **acceptance with a success
  message**. A help request was consumed as the item's short name; a requirement was created
  under a nonsense identifier; the tool printed *"Created:"*; and the identifier was burned before
  anyone read the file. A wrong argument that is accepted quietly is worse than one that halts.
- **A request for the usage text is ALWAYS legal and ALWAYS succeeds** — it is answered before any
  argument is interpreted, and its exit status says success.
  *Why:* if asking how to use the tool can fail, or can do work, the first thing a new adopter
  types is a mutation.
- **WHERE USAGE TEXT IS DERIVED, IT DEGRADES TO NAMING ITS SOURCE — never to a guess, never to an
  error.** A tool whose help text renders a project-configured value (the declared role set, the
  status folders, a trunk name) reads that value from its seam at print time rather than carrying a
  copy. Three rules follow, and they are ranked:
  1. **The request still exits 0 with its full usage text.** The clause above admits no exception
     for a value that could not be read, so the render sits behind a guard and the load of any
     library it needs cannot abort the usage path.
  2. **An unreadable seam prints the seam's own location** — the file and the variable — in place
     of the value. The operator learns where to look, which is the whole job of usage text.
  3. **It NEVER prints the kit's shipped default as a stand-in.** This is the rule with a scar
     behind it: a list that is correct about the kit and wrong about the project reads as
     authoritative and is unfalsifiable from the operator's seat. **A guess is worse than a blank
     here**, because the blank sends them to the seam and the guess sends them to a role their own
     tools will refuse.

  *Why this is stated in the contract and not only in the library that implements it:* a rendered
  value is safe only while the three rules above hold, and a policy that lives in the renderer is a
  policy the next renderer will not inherit.
- **An unrecognised option ⇒ refuse, non-zero, naming it** — never ignored, never treated as a
  positional value. **Refuse with ONE exit status across every script the kit ships**, and in this
  kit that status is **2**: a caller scripting against the set cannot branch on a status that means
  *unknown option* in one tool and something else in the next.
  **2 is not the majority's value, it is the PUBLISHED one:** `finish-pr.sh`'s exit table declares
  `2  Usage error: an unknown option or a missing option value. Nothing was read or touched.`,
  which is the only place the kit writes down what a status MEANS.
  **A surplus POSITIONAL is a different class and keeps its own status** — the two are told apart by
  a `-*)` arm ahead of the catch-all. That distinction is not a divergence; collapsing it would be.

- **`--dry-run` names PREVIEW, everywhere, and nothing else.** Wherever a tool can preview, that word
  is legal and means *change nothing* — including where previewing is already the default, in which
  case it is the explicit spelling of the default and is idempotent. **It must never mean *mutate*,
  and where the tool CAN PREVIEW it must never mean *unknown option*; a mutating tool that offers
  no preview refuses it as unknown like any other flag.**
  **A TOOL THAT MUTATES NOTHING IS OUTSIDE THIS CLAUSE, and refusing the flag is correct there.**
  A read-only report has no preview to offer: every run of it is already a preview, so accepting
  `--dry-run` would teach the operator that the word carries meaning where it carries none, and the
  next tool they try it on may be one that mutates. The refusal should name the flag as unknown and
  exit with the usage-error status like any other unrecognised option. **`--apply` is the opt-in for a tool whose default is to
  preview**, and a tool that mutates by default does not have one: its refusal of `--apply` should
  say so and name the flag that does preview, because the operator arriving with the wrong word
  learned it from a sibling and a bare refusal teaches them nothing.
  *Whether PREVIEW is the default is NOT settled here* — that is each tool's own contract sheet's
  business, and the split is deliberate: a bulk operation over a set the operator did not enumerate
  previews by default (`archive-sweep.md` § 2), while a tool acting on one operand the operator
  typed, behind gates, mutates by default and need only offer a dry mode (`release-ritual.md` § 4).
  **What is settled here is the WORD**, because a word that means three things across one set is a
  vocabulary defect no contract sheet owns.
- **A CONTRADICTORY PAIR IS REFUSED, NEVER RESOLVED.** `--apply --dry-run` is not a last-flag-wins
  question: the two answers differ by whether the repository changes, and guessing is the one thing a
  tool must not do about that. Refuse, name both flags, and say nothing was changed.

**These are the CLI SHAPE, and they bind every command-line tool in the kit, not only the
creators.**

<!-- CLI-SHAPE-EXEMPT-CLASSES:BEGIN — the self-test derives the exempt path prefixes by reading the
     backticked paths between these two markers. Anchored on the MARKERS, not on this bullet's
     wording, because contracts/README.md's equivalent block was once anchored on prose and the
     first reword of that prose emptied it. Prose is not an anchor. Move them if the block moves;
     do not delete one without the other. -->
**WHAT "COMMAND-LINE TOOL" EXCLUDES, and each class carries the test that admits it.** *(Count them
below rather than here.)* A shipped program that is not invoked by someone who could type a flag is
not bound by the shape above — and saying so here, once, is the alternative to every reader of the
set deciding it again. **The test that separates a class from an excuse: could this program ever
receive an option from a human or from a script a human wrote? If yes, it is bound.**

1. **Protocol-invoked programs** — `scripts/githooks/`, `scripts/hooks/`, `consumers/hooks/`,
   `scripts/notify-hook.sh`. Their caller is git, the agent harness, or a pipe, and each passes a
   fixed argument shape that is never an option. A usage handler on one answers a question nobody
   can ask it. *They are still bound by everything else the kit says about refusals; what they are
   not bound by is a CLI shape for a CLI they do not have.*
2. **Sourced seams and shared internals** — `scripts/lib/`, `scripts/config.sh`. These are **dot-
   sourced** into another program, so they have no argument vector of their own; the behaviour they
   carry is specified by the sheets of the scripts that call them. Executing one directly is a
   mistake, not an interface. *The self-test derives the exempt prefixes from the BACKTICKED PATHS
   in this block, so **nothing between these markers may put a non-path in backticks** — which is
   why the sourcing operator is spelled as a word.*
3. **Vendored upstream helpers** — `.claude/skills/`. Scripts inside a vendored skill directory are
   not ours to shape: an upstream re-copy would revert any change we made, which is the same reason
   their class lives in the skills README's provenance table rather than in an in-file marker.

**An exemption that names a path the kit does not ship is COVERAGE SHRINKING SILENTLY**, so the
self-test asserts every prefix above still matches something. Deleting a class is a decision; a
class quietly matching nothing is not.
<!-- CLI-SHAPE-EXEMPT-CLASSES:END --> *They are authored here because this is where the failure that produced them was paid
for; they are stated as general because a shape declared per-tool is a shape that diverges per-tool.
**Where a tool in your set diverges — a different exit status, a missing usage handler, a usage
request that refuses — that is a defect against this section, and it is fixed against THIS WORDING
rather than against the other tools**: reconcile a set to its own majority and the next reading
finds a different majority and standardises on that instead.*

## 4. WHAT GREEN MEANS

1. **Exactly one** new item exists, in the starting state, and its path is printed.
2. Its header carries **every declared key**, and its identifier **matches its name** — checkable
   by reading the file, and checked in bulk by the drift report.
3. **Nothing else changed**: no other item, no board state, no publication.

## 5. MINIMAL INTERFACE

**In:** the item kind, a validated identifier, a short name, and the kind's own optional links
(a parent, a requirement, a story set).

**The short name has a declared SHAPE, and this is where it is declared.** A short name is
**lower-case letters, digits, and single hyphens between them** — it starts and ends with a letter
or digit, and carries nothing else: no spaces, no dots, no slashes, no underscores, no upper case,
no leading or trailing hyphen, no run of two hyphens. **Anything outside that shape is refused at
the door under § 3's existing rule**, naming the position and the character; it is never silently
rewritten into legality, because a caller who asked for one name and got another has lost the one
thing they typed.

*Why the shape is this narrow, and why it is stated ONCE here rather than as a pattern per tool:*
**a short name does not stay a short name.** It travels into a branch name and into a file name, and
those two have different enemies — a branch name must be a legal reference, so a space, a colon, a
tilde, a caret, a backslash, a run of two dots or a trailing dot makes the reference illegal or
ambiguous; a file name must survive being handled by a shell and a filesystem, so a space, a quote,
a leading dash, a slash or a glob character turns one argument into two or one path into another.
**The shape is the intersection of what both accept**, which is why it is stricter than either alone
looks like it needs. *A character either travels everywhere the name goes, or it refuses at the
door — the failure this prevents is not a rejected name, it is an ACCEPTED one: the tool exits zero,
the item is written, and the illegal branch name is discovered later by someone who did not type it.*

**The validation implements this section; it does not define it.** State the shape here, cite it
there — a pattern spelled out per tool is a pattern that drifts per tool, and the tools would then
disagree about what a name is.
**Out:** the created item's path, and a non-zero exit for every refusal above.
**Not in:** the content of the work. A template that pre-writes the plan is a template nobody
edits.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/new-issue.sh`, `scripts/new-bug.sh`, `scripts/new-refactor.sh`,
  `scripts/new-prd.sh`, `scripts/subtask.sh` — KIT-CLASS: KIT, one per item kind.
- The templates themselves live under the agent-harness directory (`.claude/templates/`), which is
  path-pinned; the manifest names them, and the initializer stamps them.
- The identifier-substitution invariant in § 2 is a real incident's lesson, recorded in
  [`../EXTRACTION.md`](../EXTRACTION.md) § 2.
