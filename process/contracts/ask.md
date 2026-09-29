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
- **One question, one file.** Each call writes exactly one file, named so it sorts by time and
  never collides with another question from the same or a different role.
  *Why:* a question folded into an existing file is a question a later reader can miss; a
  collision silently drops one question's record.
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
| `ask-channel-unusable` | the declared channel cannot be created, or is not writable |
| `ask-write-failed` | the question file could not be written |
| `ask-decisions-write-failed` | `--decision` named a live entry but the register write failed |
| `unknown-option`, `unexpected-argument` | a mis-invocation |

**Not a refusal:** `--decision` naming an id with no live entry in the register, or naming an
entry that has a standing ruling. Either way the call still writes the question file and says, in
its output, where the default is (or is not) recorded — a mistyped id or an already-ruled
question does not stop the session either.

## 4. WHAT GREEN MEANS

1. Exactly one question file exists in the declared channel after the call, naming the asker, the
   time, the question, the working default, and how the answer is recorded.
2. With `--decision` naming a WITHDRAWN register entry (no current ruling): that entry's ruling
   now carries the working default in the provisional form, with the question file's path in the
   token, and nothing else in the entry changed.
3. With `--decision` naming an entry that HAS a standing ruling: that entry is byte-identical to
   before the call.
4. Exactly one progress record exists for the call, carrying an `asked=` extra.
5. The call exits 0 and the caller's own control flow continues — nothing waited on an answer.

## 5. MINIMAL INTERFACE

**In:** who is asking, the question, a working default, and (optionally) a register entry the
default could overturn.
**Out:** one question file's path; where the default is recorded; exit 0.
**Not in:** waiting for or reading an answer, committing, or judging whether the working default
was the right one. Those are the principal's and the project's.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/ask.sh` — KIT-CLASS: KIT. `./scripts/ask.sh --role <role> "<question>" --default
  "<text>" [--decision D-NN]`. The channel and principal come from `PROJECT.md`; the provisional
  marker's format, including the question-file pointer, is `requirements/DECISIONS.md` § The
  FOURTH state; it never fires over an entry `requirements/DECISIONS.md` § The THIRD state does
  not name WITHDRAWN.
