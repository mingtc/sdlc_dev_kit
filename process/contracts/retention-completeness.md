<!-- KIT-CLASS: KIT — contract sheet: retention completeness. See process/EXTRACTION.md. -->
# CONTRACT — retention completeness

## 1. PURPOSE

To keep a **retirement** — the removal of a document's bytes from the working tree under a
signed ledger — from ever happening WITHOUT the ledger row that makes it recoverable, so that
"the bytes are gone" and "the ledger says so" can never silently drift apart.

## 2. HARD INVARIANTS

- **A deletion staged under the retained-evidence area is REJECTED unless a companion ledger
  file is staged, naming that path, in the SAME proposed change.**
  *Why:* a row promised for later is a row that does not happen; the deletion and its ledger
  entry must be inseparable at the moment either one is proposed.
- **A rename is never treated as a deletion.** Moving a document — reorganizing it, parking it
  elsewhere in the retained area — must never trip this gate.
  *Why:* treating every move as a deletion would make ordinary reorganization fight the exact
  gate meant to catch deliberate removal, and people disable gates that punish innocent moves.
- **Enforcement happens at proposal time, in every checkout sharing the enforcing
  configuration — not only the primary one.**
  *Why:* one unguarded entrance is the whole fence (the same reasoning
  [commit-attribution.md](commit-attribution.md) states for its own write-time guard). In this kit
  that explicitly includes the auxiliary trunk checkout, which is a real checkout that makes real
  commits.
- **This gate exists BECAUSE the direction cannot be an offline test.** Proving that a deletion
  which happened was ledgered requires knowing a file once existed, which means reading live
  version-control state — and a suite that forbids its tests from doing that cannot host this
  check. The venue change is deliberate and is stated, not implied.
  *Why:* an obligation with no venue silently becomes nobody's.
- **A documented one-off bypass exists, and its existence does not weaken the completeness
  claim**, because a stronger, human-run check is the actual gate this one only queues work
  for.
  *Why:* the speed bump exists to catch the ordinary case cheaply; the harder claim (that the
  ledger row is truthful, not merely present) is owed to a slower, human verification, and a
  bypass that skips the cheap gate does not skip that one.
- **The rejection names the offending path(s) and both ways to satisfy the gate.**
  *Why:* a gate people cannot satisfy from its own message gets disabled (the same reasoning
  [commit-attribution.md](commit-attribution.md) states for its refusal message).

## 3. REFUSAL CONDITIONS

- A proposed change deletes a path under the retained area, and no companion ledger file is
  part of the same change ⇒ reject, naming the path(s).
- A proposed change deletes a path under the retained area, a companion ledger file IS part of
  the same change, but does not name that path ⇒ reject, naming the path(s).
- The documented bypass is asserted ⇒ not a refusal condition.

Deliberately **not** a refusal: a rename, at any strength of rename-detection heuristic; the
truthfulness of a ledger row's own fields (a wrong byte count, an unfetchable commit) — that is
owed to a human verification this gate cannot perform, never to this gate.

## 4. WHAT GREEN MEANS

1. A change that deletes nothing under the retained area proceeds without comment.
2. A change that deletes a path there AND names it in a companion ledger row, in the same
   change, proceeds without comment.
3. A change that deletes a path there without a naming row is **rejected**, and does not exist
   afterward.
4. A rename within or out of the retained area is never rejected by this gate, at any strength.

## 5. MINIMAL INTERFACE

**In:** the set of proposed deletions under the retained area (rename-resolved, so a moved
document is excluded); the proposed content of the companion ledger file.
**Out:** proceed silently, or refuse, naming the unledgered path(s) and the two ways to satisfy
the gate (add the row, or confirm the operation is a rename).
**Not in:** whether a ledger row is truthful, or whether the retirement it names was actually
authorized — both are owed to a slower, human verification this gate cannot perform.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/githooks/pre-commit` — KIT-CLASS **MIXED**: this sheet describes the **kit half**
  (a staged deletion under a retained-evidence directory requires a same-change, path-naming
  ledger row; renames are exempt at any detection strength; a documented one-off bypass
  exists). The retained directory's name and the ledger file's path and seven-field shape are
  the project's law and must be replaced on adoption — see
  [`../doctrine/retention.md`](../doctrine/retention.md) § A.4.
- [`../doctrine/retention.md`](../doctrine/retention.md) § A.5 — the reason this direction could
  not be an offline test and moves venue to this gate instead.
- The human verification this gate defers to — that a ledger row's fetch-back actually works —
  is [`../doctrine/retention.md`](../doctrine/retention.md) § A.6, "retirement-QA".
