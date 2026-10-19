<!-- KIT-CLASS: KIT — contract sheet: the non-blocking ask. See process/EXTRACTION.md. -->
# CONTRACT — the non-blocking ask

## 1. PURPOSE

To give a session a route to a blocking question **that returns**, so a question with nobody
watching to answer it records itself and lets the session keep working, rather than ending on an
interactive prompt nothing will answer.

## 2. HARD INVARIANTS

- **It never blocks.** The call writes the question and a working default, then returns to its
  caller — it does not wait, poll, or hold the session open for an answer.
  *Why:* an interactive question with nobody watching is a hang, not a pause
  (`process/doctrine/orchestration.md` § A.5's unattended corollary).
- **The principal and the channel are read from the project's own declaration, never guessed or
  hard-coded.** `PROJECT.md` § *Who answers when nobody is watching* names both; an undeclared or
  unfilled principal or channel is a refusal, not a default channel invented on the spot.
  *Why:* a question sent somewhere nobody declared is a question nobody will find.
- **One question, one file.** Each call into a directory channel writes exactly one file, named so it
  sorts by time and never collides with another question from the same or a different role. A
  channel that names a file is the declared exception: each question is appended to it, which is
  why PROJECT.md leads with the directory form.
  *Why:* a question folded into an existing file is a question a later reader can miss; a
  collision silently drops one question's record.
- **The channel is a path inside the repository.** An absolute channel or one with a `..` component is
  refused (`ask-channel-unusable`), never re-rooted under the repository or written beside it.
  *Why:* a question filed outside the tree is one no later session of this project will find.
- **A STANDING RULING IS NEVER TOUCHED.** `--decision D-NN` writes the register only when that
  entry has NO current ruling (`requirements/DECISIONS.md` § The THIRD state, WITHDRAWN); an
  entry with a standing ruling is left byte-identical, and that ruling — not the working default
  — is what the session proceeds under until the principal answers.
  *Why:* overwriting a standing ruling would let a question provisionally grant its own premise
  merely by being asked — "may I lift D-09?" must not itself lift D-09.
- **The working default is recorded as PROVISIONAL, never as a settled ruling.** Where it lands in
  the requirements register (a WITHDRAWN entry named by `--decision`), it carries a marker a
  machine can recognise, with the question file's own path IN the marker
  (`requirements/DECISIONS.md` § The FOURTH state) — and where the register carries no live entry
  for it, or the entry has a standing ruling, the question file itself is the record, and the call
  says so.
  *Why:* a guess that reads exactly like a ruling is indistinguishable from one, and the next
  reader inherits it as settled.
- **It never commits.** The question file and any register edit are left for the project's
  ordinary metadata-commit route.
  *Why:* committing on a session's behalf hides whose decision it was to land the record, and
  when.
- **Every refusal leaves one countable record**, through `kit_refuse`
  ([`progress-record.md`](progress-record.md) § 1a), naming a stable rule id.
  *Why:* a refusal seen only on a terminal cannot be audited after the session ends.

## 3. REFUSAL CONDITIONS

| Rule id | When |
|---|---|
| `ask-no-role` | no `--role` given |
| `ask-no-question` | no question given |
| `ask-no-default` | no `--default "<working default>"` given |
| `ask-role-not-declared` | `--role` is not a member of the project's declared role set |
| `ask-no-project-md` | no `PROJECT.md` to read the principal and channel from |
| `ask-no-principal` | `PROJECT.md`'s `principal:` is missing or still `<angle-bracket>` |
| `ask-no-channel` | `PROJECT.md`'s channel line is missing or still `<angle-bracket>` |
| `ask-role-is-principal` | `--role` names the seat `PROJECT.md` declares as principal — the asker may not be the seat that answers; `Next:` re-run with the asking seat's own role, or decide it and record the ruling |
| `ask-channel-unusable` | the declared channel is not a path inside the repository, or cannot be created, or is not writable |
| `ask-card-malformed` | `--card` names something that is not a card id (`<PREFIX>-N`, or a slice's `<PREFIX>-N-sM`); `Next:` re-run with the parked card's id (`ls progress/*/`), or leave `--card` off |
| `ask-card-not-found` | `--card` is shaped like a card id but names no card under `progress/` in this checkout; `Next:` check the id, pull the trunk if the card is newer, or leave `--card` off |
| `ask-write-failed` | the question file could not be written |
| `ask-decisions-write-failed` | `--decision` named a live entry but the register write failed |
| `ask-unknown-option`, `ask-unexpected-argument` | a mis-invocation |

**Not a refusal:** `--decision` naming an id with no live entry in the register, or naming an
entry that has a standing ruling. Either way the call still writes the question file and says, in
its output, where the default is (or is not) recorded — a mistyped id or an already-ruled
question does not stop the session either.

## 4. WHAT GREEN MEANS

1. Exactly one question file exists in the declared channel after the call, naming the asker, the
   time, the card it parks (when `--card` named one), the question, the working default, how the
   answer is recorded, and how to answer in the file (one `**Answer` block at its end).
2. With `--decision` naming a WITHDRAWN register entry (no current ruling): that entry's ruling
   now carries the working default in the provisional form, with the question file's path in the
   token, and nothing else in the entry changed.
3. With `--decision` naming an entry that HAS a standing ruling: that entry is byte-identical to
   before the call.
4. Exactly one progress record exists for the call, carrying an `asked=` extra.
5. The call exits 0 and the caller's own control flow continues — nothing waited on an answer.

## 5. MINIMAL INTERFACE

**In:** who is asking, the question, a working default, and (optionally) a register entry the
default could overturn and the card the question parks.
**Out:** one question file's path; where the default is recorded; exit 0.
**Not in:** waiting for or reading an answer, committing, or judging whether the working default
was the right one. Those are the principal's and the project's.

**The project's half: who reads an answer, and what reconciling it means.** A question file is
*answered, not reconciled* while it carries an `**Answer` block and no `requirements/DECISIONS.md`
entry cites its path. `scripts/check-board.sh` lists those files, each with the card the question
parks. The Orchestrator is the reader: at session start it dispatches the PM-hat leg for each, and
reconciling means exactly three acts — record the literal answer as a `D-NN` that cites the question
file; edit the parked card to cite it (`[decision: D-NN]` on the bullet it settles); move the card
out of `blocked/`. Anything the answer leaves unruled is filed again through `ask.sh` under a working
default, never ruled by the leg
(`.claude/roles/orchestrator.md` § An answered question is ready work).
*Why:* an answer nothing is woken to act on leaves its card parked in a column no session reads, with
the principal's decision in a file nobody opens.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/ask.sh` — KIT-CLASS: KIT. `./scripts/ask.sh --role <role> "<question>" --default
  "<text>" [--decision D-NN] [--card <ID>]`. The channel and principal come from `PROJECT.md`; the provisional
  marker's format, including the question-file pointer, is `requirements/DECISIONS.md` § The
  FOURTH state; it never fires over an entry `requirements/DECISIONS.md` § The THIRD state does
  not name WITHDRAWN.
