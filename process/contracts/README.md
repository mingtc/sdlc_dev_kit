<!-- KIT-CLASS: KIT — the contract index. Travels unedited; every sheet beside it does too. -->
# process/contracts/ — the gates and rituals as LANGUAGE-AGNOSTIC LAW

**What must be TRUE, separated from the machinery that currently makes it true.**

The rest of this kit transfers most easily to projects that can run its shell scripts. These sheets
are the half that transfers to everyone else: *"the project need not use any particular language or
shell if they don't want to — but the spirit needs to be there."*

**Read a sheet as a specification.** Sections 1–5 are binding on **any** implementation in **any**
language; section 6 names this kit's own implementation and is marked as *one implementation,
not the definition*. A sheet that made you open the script has failed its only job — say so.

## The six sections, every sheet, no exceptions

| # | Section | What it holds |
|---|---|---|
| 1 | **PURPOSE** | One sentence: what this gate exists to prevent. |
| 2 | **HARD INVARIANTS** | What any implementation must guarantee. The load-bearing section; every invariant carries its own *Why:*. |
| 3 | **REFUSAL CONDITIONS** | When it must fail **loudly**. Silence is the failure mode this kit is organised against. |
| 4 | **WHAT GREEN MEANS** | Observable and countable. *"It passed"* is not a definition. |
| 5 | **MINIMAL INTERFACE** | Information in, information out — **not** a command line. |
| 6 | **REFERENCE IMPLEMENTATION** | A pointer, with its `KIT-CLASS`, marked as one implementation. |

## The sheets

**How many sheets are there?** `find process/contracts -type f ! -name README.md | wc -l` — run it.
*The exclusion is the point: this index is a file in the directory it indexes, so the unfiltered
count answers a different question than the one asked and answers it one too high.* A digit written
here is wrong the first time a sheet is added, and this kit has already been bitten twice by a
transcribed census (see [`../EXTRACTION.md`](../EXTRACTION.md) § The one rule about counting).
**Deriving is not enough on its own — the derivation has to count the thing the sentence names.**

| Contract | Sheet | Implementation it describes |
|---|---|---|
| The verify gate | [verify-gate.md](verify-gate.md) | the one gate runner (MIXED — kit half only) |
| The board mover | [board-mover.md](board-mover.md) | the one way status changes |
| The landing gate | [landing-gate.md](landing-gate.md) | pre-merge gate, squash, state advance |
| Commit attribution | [commit-attribution.md](commit-attribution.md) | the write-time role guard (MIXED — kit half only) |
| Id minting | [id-minting.md](id-minting.md) | monotonic, collision-free identifiers |
| Issue / requirement creation | [issue-creation.md](issue-creation.md) | template + header contract |
| The archive sweep | [archive-sweep.md](archive-sweep.md) | retire, index, preserve |
| The drift report | [drift-report.md](drift-report.md) | one check per invariant, including day-one completeness |
| The auxiliary trunk checkout | [kanban-worktree.md](kanban-worktree.md) | publish to the trunk from anywhere |
| The release ritual | [release-ritual.md](release-ritual.md) | gates before the bump, publish after the push (MIXED — kit half only) |
| The liveness / watchdog ritual — TWO, split by scope (§ 1a) | [liveness-watchdog.md](liveness-watchdog.md) | duration: a discipline; absence: `scripts/notify/stall.sh` |
| The configuration seam | [config-seam.md](config-seam.md) | one definition per adopter value |
| The initializer | [initializer.md](initializer.md) | configure, then **prove** |
| The role gate | [role-gate.md](role-gate.md) | declare the hat before mutating |
| Outbound notification | [notification.md](notification.md) | silent when unconfigured, never a gate |
| The process self-test harness | [self-test-harness.md](self-test-harness.md) | the tools tested in a sandbox (MIXED — kit half only) |
| The acceptance tier | [acceptance-tier.md](acceptance-tier.md) | which tests pin the PRODUCT — **non-travelling reference** |
| Retention completeness | [retention-completeness.md](retention-completeness.md) | a deletion under the retained area requires a same-change ledger row — **non-travelling reference** |
| The progress record | [progress-record.md](progress-record.md) | one record shape, one place, transient by construction — **converged on two producers on purpose** (§ 1a) |

**The first eleven rows are the minimum set** — the set the completeness rule treats as a floor.
The rows after them are **additions**. Most are justified by the rule that makes the set complete
(*every travelling script owes a contract, and those gates had none*); others by its mirror image,
where a rule travels with no implementation to point at. **Read each row's own reason** — this
sentence used to partition them as "most … and one", and the counts did not hold.

| Addition | Why it earns a sheet |
|---|---|
| The configuration seam | The one place an adopter edits — leaving it uncontracted leaves adoption itself undefined. |
| The initializer | Day one is a gate: it either proves the installation or it does not. |
| The role gate | The process's first rule ("confirm the hat") is otherwise enforced only by prose. |
| Outbound notification | Its contract is almost entirely *what it must NOT do* — be a gate, fail a caller, need configuration. |
| The process self-test harness | It carries the other half of the landing gate's test-only-marker invariant. |
| The acceptance tier | **The mirror-image case: the only artifact class with no travelling spec at all.** Its reference implementation is deliberately **non-travelling** (one test runner's marker), which is exactly why the invariants had to be written here — the whole *"a rewrite from the corpus is acceptable"* claim rests on a tier an adopter can reimplement. |
| Retention completeness | The retention doctrine's one venue-change mechanism, contracted so the rule travels even though no implementation does. **Deliberately non-travelling** — its own § 6 says so, and `scripts/githooks/` ships only `applypatch-msg` and `commit-msg`. *This row called it "a travelling gate", which its sheet contradicts in the same directory.* |

Nothing in the minimum set was merged or split.

## The rules that hold this directory honest

- **Both directions want guarding**, and the guard is the **project's**, not the kit's: every
  travelling (`KIT`/`MIXED`) script has a sheet, and every implementation a sheet cites exists. A
  new gate with no contract should redden the build; so should a contract for a gate that is gone.
  **One of those two directions now ships a guard and one does not** — see the § 6 bullet below,
  which is where the split is stated in full: `case_travelling_scripts_have_a_sheet` runs in your
  tree, and nothing yet checks that a sheet's cited path still exists. Writing THAT second guard in
  your own test runner is [`../EXTRACTION.md`](../EXTRACTION.md) § 4's standing debt.
  *This bullet read "the contracts travel, a guard over them does not" until 2026-09-04. The guard
  shipped on 2026-09-03 and the § 6 bullet was updated in that same change; this bullet was not — the second half of a document still describing the world the first half had
  left.*
<!-- EXEMPT-CLASSES:BEGIN — the self-test derives the exempt path prefixes by reading the
     backticked paths on the NUMBERED ITEMS between these two markers, and on nothing else.
     They are here because the derivation used to be anchored on this bullet's WORDING, and
     the first reword of that wording emptied it. Prose is not an anchor. Move them if the
     block moves; do not delete one without the other.
     THE OPERAND IS THE NUMBERED LIST, NOT THE WHOLE BLOCK. A class is declared by adding a
     numbered item that backticks its path prefix; prose between these markers is read by
     people and by nothing else. The hazard that narrowing answers is stated OUTSIDE these
     markers, immediately below the END, because a note about the derivation cannot live
     inside the derivation's own operand — see the paragraph there. -->
- **SOME CLASSES OF TRAVELLING FILE ARE EXEMPT, and they are named here — each with the test
  applied — so a sweep finds a DECISION rather than a violation.** *(Count them below rather than
  here: this said "TWO CLASSES" and a third was added the day the guard grew wide enough to need
  it.)* The rule above says every travelling script has a sheet. Read
  literally it is false, and it should be — a sheet describes a **reimplementable behaviour**, and
  no class below has one.
  1. **The optional extras.** `scripts/hygiene/` is Python 3, standard-library only, **never a gate,
     and deletable without loss**. A reimplementer who omits every one of them has still built the
     kit. Writing them contract sheets would assert the opposite of the carve-out that makes them
     optional.
  2. **The consumer-side integration surface** — `consumers/`. These serve a DIFFERENT AUDIENCE:
     not a project adopting this kit, but a downstream project that VENDORS an artifact from one.
     A reimplementer building this process from the sheets would not create `consumers/`, and would
     not be wrong — the test below, applied. *Named 2026-09-03, when the guard was widened to walk
     the whole travelling set and reported nine files here. They were never missing sheets; the
     guard had simply never been able to see them.*
  3. **Shared internals of contracted scripts** — `scripts/lib/`. These exist so that two or three
     consumers do not duplicate an idiom; the behaviour they carry is already specified by the
     sheets of the scripts that call them. **A reimplementer working from the sheets alone would not
     create these files, and would not be wrong.** A library is a factoring decision, not a contract.
  *The test that separates an exemption from an oversight:* **could someone build a conforming kit
  from the sheets without this file?** If yes, it is exempt and belongs in a class above. If no, it
  owes a sheet. *And do not close a gap by writing thin sheets to satisfy a count — this directory
  also says a sheet must be short enough to finish, and one nobody finishes reading is not
  reimplementable. Nine
  sheets written to make a census green is the census defect wearing contract clothing.*
  *One thing that looks like a gap and is not:* a sheet may cite its implementation in **placeholder
  form** — `notification.md` says `scripts/notify/<channel>.sh`, because the channel is the adopter's
  instance. A sweep matching literal paths reports the shipped example as uncovered; it is not.
<!-- EXEMPT-CLASSES:END -->

**THE HAZARD THIS BLOCK'S SHAPE ANSWERS, stated here because it cannot be stated inside the block.**
The self-test derives the exempt prefixes from the block above, so **anything in that block that
looks like a path prefix becomes a live operand of the guard** — and the guard is the one that holds
every other travelling script to a sheet. A line reading *"everything under `scripts/` is exempt"*
placed between those markers does not describe the exemption set; it **joins** it, and a prefix that
broad exempts the entire travelling population while the self-test still reports a healthy run. That
is not hypothetical: an earlier attempt to warn about this hazard *inside* the markers became the
hazard, and the guard then judged one file of forty-six and finished green. **So the derivation reads
the NUMBERED ITEMS ONLY**, and this paragraph lives outside the markers where it is prose and nothing
else. *The sibling block in [`issue-creation.md`](issue-creation.md) carries the same hazard with a
different mitigation — it asserts the derived prefixes LOOK like paths — and the two are worth
reading together.*
- **A § 6 row RESTATES the implementation's own `KIT-CLASS` marker, deliberately, and the copy is
  tolerated rather than accidental.** The two statements answer two different readers: the in-file
  marker answers *"what is this file"* for someone holding the file; the § 6 row answers *"what does
  this contract's implementation look like"* for someone holding only the spec — including a
  reimplementer who has no such file at all. **One direction is guarded and one is not, and the
  difference is worth stating:** the self-test now checks that **every travelling script has a
  sheet** (`case_travelling_scripts_have_a_sheet`, which derives the exempt classes from the rule
  above rather than from a list) — that guard SHIPS, so it runs in your tree too. **What is still
  unguarded: nothing checks that a sheet's cited path still exists.** That one goes wrong silently.
  *This paragraph said BOTH were unguarded until 2026-09-03, in the same document whose own guard
  had already landed.* Derive them rather than trusting this list:

  ```sh
  # every path a § 6 bullet names, with the class the sheet claims for it —
  # bullets WRAP, so join continuation lines first or five rows in one bullet are missed
  # THE JOINED BULLET IS PRINTED — each one as the NEXT bullet starts, and the last one at END.
  # This used to finish with an empty END block, so it accumulated every bullet into `b` and
  # emitted NOTHING: an adopter following the honest alternative to a list got a blank screen.
  awk '/^- /{if(b)print b; b=$0; next} /^[[:space:]]+[^[:space:]]/{b=b " " $0} END{if(b)print b}' \
      process/contracts/*.md

  # every travelling file — BOTH COMMENT SYNTAXES, and that is the trap, not the path.
  grep -rlE '^(#|<!--) KIT-CLASS: (KIT|MIXED)' .
  # SCOPE WAS THE OBVIOUS TRAP AND THE PATTERN WAS THE REAL ONE. This read `scripts/ setup.sh`,
  # which is narrower than the rule it supports; widening the PATH to `.` fixed a third of it and
  # no more, because `^# KIT-CLASS:` only matches SHELL comment syntax and every travelling
  # markdown file declares itself in an HTML comment. **RUN BOTH AND COMPARE** — the shell-only
  # pattern returns a small fraction of what both syntaxes return, and the gap is the finding.
  # No figure is written here on purpose: two were, undated, in the very paragraph arguing that a
  # derivation beats a transcribed number, and both were wrong on the tree that shipped them.
  # **A derivation offered as the honest alternative to a list undercounted by two thirds, and
  # then undercounted by less.**
  ```

- **`PROJECT`-class files owe nothing** and no sheet may claim one — a contract over a file the
  adopter never receives reads as an obligation they do not have.
- **A `MIXED` file's sheet describes the KIT HALF only**, and says so in its own section 6.
- **A sheet is short enough to finish.** A sheet nobody finishes reading is not reimplementable,
  and length is the thing most likely to make that true. *This said "≤ one page" until 2026-09-04,
  when it was measured against the directory it governs and **no sheet satisfied it** — the shortest
  is `notification.md`, the longest `drift-report.md`, and every one is past a page. A bar nothing
  clears is not a bar; it is a sentence that makes the next reader distrust the neighbouring rules.
  Derive the spread before invoking this — `wc -l process/contracts/*.md` — and treat a sheet that
  is an outlier against its siblings as the thing to question, not a fixed line count.*
- **The version-literal trap:** any example needing a version uses the obviously-fictional
  `42.x`, so no sample can be mistaken for a real version or rot into a lie when the real one
  moves.

**These sheets describe; they do not amend.** Where writing one reveals that an implementation
violates an invariant it should hold, that is recorded as a finding for whoever owns the backlog —
never fixed silently in the same change.
