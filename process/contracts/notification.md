<!-- KIT-CLASS: KIT — contract sheet: outbound notification. See process/EXTRACTION.md. -->
# CONTRACT — outbound notification

## 1. PURPOSE

To let a long-running process reach a human **without the process depending on being able to** —
so that the checklist item "fire a ping" costs nothing when no channel is configured.

## 2. HARD INVARIANTS

- **Unconfigured is a SILENT SUCCESS, never an error.** With no channel selected, every send is a
  no-op that exits successfully.
  *Why:* if the absence of a chat integration can fail a step, every adopter's first run fails on
  something irrelevant to their work.
- **Notification is NEVER a gate.** Nothing in the process waits on, or branches on, whether a
  message was delivered.
  *Why:* an outbound channel is the least reliable component in the system; letting it block work
  imports its reliability into the process.
- **One stable calling surface, many channels.** Callers name a class of event and a message; the
  channel is selected by configuration and swapping it changes no caller.
  *Why:* the alternative is every call site knowing a chat product, and a migration that touches
  every call site.
- **Routing is by EVENT CLASS, and the classes are a closed, declared set.** Which classes are
  loud, quiet, or dropped is configuration.
  *Why:* per-call-site urgency decisions produce a channel that is either all noise or all
  silence, and both end with the human muting it.
- **Every message identifies its source run.** A message that cannot be traced back to what
  produced it is noise.
  *Why:* the recipient is usually watching several runs, and an unattributed alert forces them to
  go and look — which is the cost the notification existed to save.
- **Secrets are never in the process's tracked content, and never in the message.** The channel's
  credentials come from the environment.
  *Why:* an outbound integration is the most common way a credential reaches a repository.
- **A delivery failure is reported to the local output and swallowed otherwise.** The caller
  continues.
  *Why:* see the second invariant: the only thing worse than a missed message is a run abandoned
  because of one.

## 3. REFUSAL CONDITIONS

- No channel configured ⇒ **not a refusal**: silent no-op, success.
- An unknown event class ⇒ refuse at the call site, listing the legal classes. Silently inventing
  a class breaks routing for everyone.
- A configured channel with missing credentials ⇒ report locally and continue; do not fail the
  caller.
- A message with no source identity ⇒ refuse to send. Unattributed alerts are the failure mode.

## 4. WHAT GREEN MEANS

1. With no channel configured: **nothing sent, nothing printed, zero exit** — provable by running
   it in a clean environment.
2. With a channel configured: the message arrives on it, carrying **its class and its source
   identity**.
3. The caller's outcome is **identical either way** — the process's behaviour does not depend on
   delivery.

## 5. MINIMAL INTERFACE

**In:** an event class from the closed set; a message; the source run's identity; optional
progress or reference detail.
**Out:** delivered or silently skipped; a local note on failure; success in every case that is
not a caller mistake.
**Not in:** message formatting for a particular channel — that belongs to the channel adapter, and
adding a channel means adding one adapter and nothing else.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- `scripts/notify.sh` — KIT-CLASS: KIT. The stable calling surface, the class routing, the
  no-op-when-unconfigured rule.
- `scripts/notify/<channel>.sh` — KIT-CLASS: KIT. One channel adapter ships as an example;
  siblings are added beside it, and adding one touches nothing else.
- `scripts/notify-hook.sh` — KIT-CLASS: KIT. The adapter that lets an agent harness raise the
  same classes.
- Credentials come from the project's ignored environment file. That the channel **shares that file
  with the project's own secrets** is a known smell rather than a design choice — it is recorded in
  [`../EXTRACTION.md`](../EXTRACTION.md) § 4, and an adopter who separates them is improving on the
  kit, not departing from it.
