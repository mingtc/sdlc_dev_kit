<!-- KIT-CLASS: KIT — contract sheet: the unattended Stop hook. See process/EXTRACTION.md. -->
# CONTRACT — the unattended Stop hook

## 1. PURPOSE

To stop a session, launched with nobody watching, from ending its turn on a question addressed
to whoever is not there — once, mechanically, at the moment the turn is about to close, rather
than relying on a role or skill to remember to route the question through
[`ask.md`](ask.md) instead.

## 2. HARD INVARIANTS

- **It judges the turn's ENDING, not its content.** The ending is the final paragraph: the last run
  of non-blank lines, with fenced code blocks and inline code spans removed. A sentence in it that
  ends on a question mark (the mark followed by closing emphasis, quotes or brackets, then
  whitespace or the end) decides the outcome; a question in an earlier paragraph, inside code, or in
  a URL's query string is not what this gate reads, and neither is a request with no question mark
  ("say so if you want it", "please confirm"). *Why:* a gate that scans the whole turn for any
  question mark blocks on a question the model already answered itself in the same breath; and a
  gate that reads only the last line lets through a question followed by its default on the next
  line, which is how a closing question is ordinarily written.
- **It fires at most once per turn.** The harness re-invokes a blocked turn's own stop event, and
  that second call must be let through, or the session is stuck re-asking itself forever.
  *Why:* a hook with no loop guard turns "catch it once" into "catch it forever."
- **A blocked turn is told where to put the question, not merely that it was wrong to end.** The
  block names [`scripts/ask.sh`](../../scripts/ask.sh) and the working-default shape it needs.
  *Why:* a block with no instruction produces a second, differently-worded unaddressed question
  rather than a filed one.
- **It is opt-in, launched deliberately, never the default every project copies.** It ships only
  in the unattended profile, activated by being passed at launch.
  *Why:* the same block is wrong for an attended session — a human mid-conversation is not
  helped by having their own question bounced back at them.
- **On any payload it cannot parse, it ALLOWS.** A missing or unreadable field is read as nothing
  to judge, never as grounds to hold the session open.
  *Why:* a parsing defect must never be able to hang a session the mechanism was built to keep
  moving.

## 3. REFUSAL CONDITIONS

Not applicable in the usual sense — this is a Stop-event hook, not a command that refuses a call.
Its two outcomes:

- A sentence in the turn's final paragraph ends on a question mark AND this is not the
  loop-guarded re-invocation ⇒ **block once**, naming `scripts/ask.sh` and the working-default
  shape.
- Anything else — a statement ending, a question only in an earlier paragraph or in code, no
  message, an unparseable payload, or the loop-guarded re-invocation ⇒ **allow**, silently.

## 4. WHAT GREEN MEANS

1. A turn that ends on an unaddressed question is blocked exactly once, and the block names the
   non-blocking route.
2. The same turn's next ending — whether it files the question, states a next action, or ends on
   a statement for any other reason — is allowed; the session is never held a second time over
   the same stop event.
3. A turn whose final paragraph holds no question, or whose question sits in an earlier paragraph
   or in code, is allowed on the first try.
4. A malformed or partial payload never blocks.

## 5. MINIMAL INTERFACE

**In:** the Stop event's payload — at minimum, the turn's last assistant message and whether this
is a loop-guarded re-invocation.
**Out:** allow, or block-once with an instruction naming the non-blocking route.
**Not in:** deciding whether the question was a good one, filing it, or choosing the working
default — those are the role's and `scripts/ask.sh`'s.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/hooks/stop-ask.sh` — KIT-CLASS: KIT. Reads the Stop event's JSON payload with POSIX
  tools (no `jq`): a small hand-written scanner reads `stop_hook_active` and
  `last_assistant_message` out of the single-line payload, tracking JSON escape sequences so an
  escaped quote inside the message is never mistaken for the string's end, and un-escaping `\n`
  before deciding which paragraph is last. Wired only in
  [`.claude/settings.unattended.json.example`](../../.claude/settings.unattended.json.example)'s
  `hooks.Stop`, alongside `env.KIT_UNATTENDED=1`, which `.claude/skills/start/SKILL.md` § 4 reads
  as the signal that nobody is watching.
