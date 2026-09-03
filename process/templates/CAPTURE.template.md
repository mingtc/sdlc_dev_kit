<!-- KIT-CLASS: KIT — a blank shape. Travels unedited; every angle-bracket blank is yours to fill. -->
<!--
  HOW TO USE THIS FILE
  Copy next to the capture artifacts it describes — the LEDGER, not the corpus (see the class
  line below). Name it for the probe and the date, e.g. `<area>-probe-<YYYY-MM-DD>.md`.
  Fill every <angle-bracket> blank, delete the HTML comments.
  Any version shown in an example is the deliberately fictional 42.x; ids are shown as
  <ISSUE-ID> (your prefix, e.g. <PREFIX>-042).
  DROP THE KIT-CLASS MARKER above from your copy — it classifies this file for the kit, not for
  your project.
  THE DISCIPLINE THIS SHAPE SERVES: process/doctrine/live-resources.md (a disposable target,
  restored) and process/doctrine/negative-claims.md (enumerate, or say "unmeasured").
-->

<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — dev/rounds/<date>-<name>/ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape. -->
# <area> — measured-truth capture, <YYYY-MM-DD> (<ISSUE-ID>)

**Class: EVIDENCE LEDGER, not corpus-core.** This file records **what was measured, once, at a
moment** — it is read to learn *how we came to know*, never to learn *what is currently true*.
The ruling this evidence produced belongs in the register of standing rulings (`DECISIONS.md`) or
in the ruling's home document, in the **same change** that lands the finding; this capture is what
that entry's **Provenance** points at. A capture that is treated as a source of current truth will
be cited long after the system it probed has changed.

**It is also retained evidence, and it is PARKED rather than deleted** — its price was paid once
and is not re-derivable at that price. *(Doctrine:
`process/doctrine/retention.md`; raw capture trees are retired **never**.)*

## Verdict — <GO / NO-GO / one sentence of what is now known>

<!-- Lead with it. A reader who stops here should still have the load-bearing answer. -->

`<the finding, present tense, in one or two sentences>`

## Endpoints called

<!-- Every endpoint the run touched, in the shape the external system names them — not a prose
     summary. This is what makes the run re-derivable and what a permissions/scope review reads. -->

| # | Endpoint (method + path) | Why it was called | Result |
|---|---|---|---|
| 1 | `<METHOD> <path>` | <what it was probing> | `<code>` / `<one-line outcome>` |

## Budget & pacing

<!-- A live probe spends someone's quota and someone's rate limit. Say what it cost, so the next
     run can be planned rather than discovered. -->

- **Calls:** `<n>` total (`<n>` write, `<n>` read).
- **Pacing:** `<e.g. ~1 call/sec, serial; no concurrency>`.
- **Window:** `<start>–<end>`.
- **Anything throttled or retried:** `<what, and how it was handled — or "none">`.

## Verbatim codes & bodies — the load-bearing answers

<!-- VERBATIM, not paraphrased, for every answer a conclusion rests on. A paraphrase cannot be
     re-read for a detail nobody knew to look for on the day.
     REDACT CREDENTIALS AND THE IDENTIFIERS OF PRINCIPALS — accounts, users, tenants, hosts, the
     authenticating identity's own address — NEVER THE CONTENTS. The field names, link types,
     codes and bodies are the measured truth this capture exists to hold; the people and machines
     are not. *"Redact secrets"* alone did not say this, and an email address is not a secret:
     read literally, the rule argued FOR keeping it.
     THIS IS NOT A LICENCE TO DROP THE CAPTURE. If redaction would destroy the measured truth,
     that is a case for § What this does NOT establish, not for deleting or gitignoring the file:
     raw capture trees are retired never (see the note at the top of this template, and
     process/doctrine/retention.md). The curated finding note is what a reader needs; the raw
     capture is retained REDACTED, not dropped. -->

```json
<the exact response body / error code that the verdict rests on>
```

- Capture files: `<path/to/capture-01.json>`, `<path/to/_run_ledger.json>`.
- Probe scripts: `<path/to/probes/>` — committed, so the audit trail survives this session. If the
  run used no script, say so rather than shipping an empty directory.
- Re-derive with: `<the exact command>`.

## Teardown proof

<!-- A live probe that created something owes proof that it is gone, or an explicit statement of
     what it deliberately left behind and why. "I cleaned up" is not proof. -->

- **Target used:** `<the DISPOSABLE target — never a real one>`.
- **Created:** `<what, where>`.
- **Removed:** `<what, when>` — proof: `<the delete call's code / the read-back that now fails>`.
- **Restored to baseline:** `<what baseline, and how it was verified>`.
- **Deliberately left:** `<what and why — e.g. a resource whose deletion verb does not exist>`.

## What this does NOT establish

<!-- The section that stops a capture from being over-cited. State the boundary of the evidence:
     the forms actually tried, and the neighbouring forms that were NOT tried and are therefore
     UNMEASURED, not refuted. A negative claim's scope may never exceed its evidence's scope —
     evidence about one grammar grounds a claim about that grammar, not about its class.
     Doctrine: process/doctrine/negative-claims.md (enumerate the attempts, or say
     "unmeasured"). -->

- **Tried:** `<the exact forms/shapes/parameters exercised>`.
- **Untried, therefore unmeasured:** `<the neighbours a reader will assume were covered>`.
- **Scope of the claim:** `<the narrowest statement the evidence actually supports>`.
- **Axes not covered:** `<other accounts, other tenants, other versions, other clients>`.

## Open questions

1. `<what a further probe would have to do to settle it — or "none">`
