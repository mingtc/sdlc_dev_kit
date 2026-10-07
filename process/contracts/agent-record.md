<!-- KIT-CLASS: KIT — contract sheet: the agent record and the same-agent landing refusal. See process/EXTRACTION.md. -->
# CONTRACT — the agent record

## 1. PURPOSE

To make "the checker is not the author" something the landing can check rather than something a
role is trusted to have done. Every commit an agent creates is recorded against the identity that
created it — the harness session and the agent within it; the landing refuses a QA verdict
committed by an identity that also committed the code it judges. A role name is a label anyone can
type; the harness's identity is not, so the bar rises from switching hats to forging a record.

## 2. HARD INVARIANTS

- **The identity is the harness's, never the role's.** It is the pair (session, agent): the hook
  payload's session id, and its per-agent id for a dispatched agent or `main` for the session's own
  thread, which has none. The commit message, the role prefix and the card are never read for it.
  *Why:* a role tag is typed by the author; checking it would refuse nothing a liar cannot retype.
- **Two sessions are two identities, and so are two agents of one session.** `main` in a fresh
  top-level session is not the `main` that wrote the code; an orchestrated run's Dev and QA legs
  share a session and are still two.
  *Why:* the separation that matters is a reviewer that did not write the change — a second
  session gives it, and so does a dispatched leg; the session alone cannot tell legs apart.
- **Only a commit the call CREATED is recorded.** A commit is recorded when it became reachable
  during the call and some worktree's HEAD reflog shows this repository making it (a commit,
  cherry-pick, revert, `am`, or a rebase's pick). A fetched, pulled or fast-forwarded commit is not.
  *Why:* without that filter, the agent that pulls another's work is recorded as its author.
- **A claim is added, never overwritten.** Two calls that both see one commit appear both stay on
  its record, and such a commit is ambiguous: the landing treats it as unrecorded.
  *Why:* overlapping calls cannot tell whose the commit is; a guess could refuse a correct landing.
- **The hook rewrites nothing, blocks nothing and prints nothing.** It always exits 0 and discards
  its own output; a payload it cannot read records nothing.
  *Why:* it runs around every Bash call, so a defect in it must never be able to stop one, and a
  rewritten command would change what an adopter's permission rules see.
- **The landing reads the record before the squash.** The squash replaces the branch's commits
  with one the lander makes, so the code commits are read on the branch before it.
- **No record is UNRUNNABLE, printed, never a pass.** A verdict commit with no single recorded
  identity, or a branch with no code commit that has one, prints `AGENT_CHECK: UNRUNNABLE — <why>`
  and the landing proceeds.
  *Why:* a project without the hooks wired must still land; saying so keeps the absence visible.

## 3. REFUSAL CONDITIONS

`finish-pr.sh`, and `subtask.sh move <slice> qa_complete` for a slice's own card, refuse before
anything moves, through `kit_refuse` with rule id `qa-verdict-same-agent`, when the identity recorded
for the QA-verdict commit is one of the identities recorded for the branch's code commits. The
QA-verdict commit is the newest trunk commit that changed the card's `## QA Verdict` section.
`main` in one session on both sides is a refusal: one undispatched seat wore both hats.

## 4. WHAT GREEN MEANS

1. A commit made by the session's own thread is recorded `main`; one made by a dispatched agent is
   recorded with that agent's id; a commit pulled in by a call is not recorded.
2. Two overlapping calls that both see one commit appear leave both claims on its record.
3. A landing whose verdict and code were committed by one identity — one agent, or `main`, in one
   session — is refused with nothing moved; one where they differ (two agents of one session, or
   `main` in two sessions) lands, and the records reach the remote. A slice's move is refused the
   same way.
4. A landing with no record on either side prints `AGENT_CHECK: UNRUNNABLE` and lands.

The self-test's agent-record cases demonstrate each line with the payloads the harness sends.

**What green does not show:**

- **A record is forgeable by anyone who can write refs** (`git update-ref`). The aim is to make
  skipping the review cost a forgery, not to make forgery impossible.
- **A commit made without a reflog entry** (`git commit-tree` with `update-ref`), or outside the
  harness (a terminal, another tool), has no record, so the check is UNRUNNABLE for it.
- **A forge that squashes or rebases on merge** changes the shas the records name.
- **A human committing while an agent's Bash call is open** is recorded as that agent unless the
  agent also commits it — the same limit overlapping calls have, without the second claim.
- **Records reach the remote on the next trunk push after the call that made them**, not at once;
  the landing reads the local records, which the same machine always has.

## 5. MINIMAL INTERFACE

**In:** the harness's Bash-call payloads (`tool_use_id`, `cwd`, `session_id`, and `agent_id` for a
dispatched agent), before and after each call.
**Out:** one ref per created commit, `refs/kit-agent/<sha>`, pointing at a blob of lines
`agent=<id> session=<id>`; carried to the remote by every trunk push and fetched by the landing
into `refs/kit-agent-remote/`, which is read together with the local record.
**Not in:** whether the review was any good — that is the `## QA Verdict` table's job.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/hooks/agent-record.sh` — KIT-CLASS: KIT. Wired in
  [`.claude/settings.json.example`](../../.claude/settings.json.example) as PreToolUse(Bash)
  `agent-record.sh pre` and as PostToolUse(Bash) and PostToolUseFailure(Bash)
  `agent-record.sh post`. `pre` snapshots every branch and remote-tracking tip and every worktree's
  HEAD under the git directory, keyed by the call's id; `post` diffs against it.
- `scripts/lib/agent-record.sh` — KIT-CLASS: KIT. The record's one reader and writer, its push and
  fetch, and `kit_agent_landing_check`, which `scripts/finish-pr.sh` and `scripts/subtask.sh` call.
  `scripts/lib/push-retry.sh` pushes the records after every trunk push it makes.
