<!-- KIT-CLASS: KIT — a blank shape. Travels unedited; every angle-bracket blank is yours to fill. -->
<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — process/ — NOT to the directory it
     sits in. A link written for where the template SITS resolves while you read it here and
     is dead in every copy an adopter makes: it passes a link check run in the kit and fails
     the only reader who matters. The self-test reads this line to know where to resolve from,
     so keep its shape. -->
<!--
  HOW TO USE THIS FILE
  Copy to process/KIT-FEEDBACK.md and start it on DAY ONE, empty rather than fabricated: it holds
  only what day one actually found, and nothing written to fill it. Delete the HTML comments, and KEEP the quoted
  header below the title: it is visible on purpose, because this file is the one that leaves.
  Fill § About this project BY HAND on day one, and re-read it before every send.
  DROP THE KIT-CLASS MARKER. The `KIT-CLASS:` marker line at the top classifies this file FOR
  THE KIT (does it travel, and which half). It is kit bookkeeping, not your project's.

  WHY IT IS CREATED BEFORE THERE IS ANYTHING TO PUT IN IT: the entries you will want to send are the ones you
  notice in the first week and cannot reconstruct in the third. A file created after the fact is
  written from memory, which is the failure it exists to prevent.
-->
# KIT-FEEDBACK.md — what this project learned that the kit should know

> **This file leaves your project when you send it. Review it and cut before sending.** The most
> revealing parts are § About this project and each entry's *Working on* goal. Cut anything there,
> and any identifier you do not want to send: a card id, a commit, a path, a name in a quoted line.
> It never holds this project's source, diffs, file contents or test output.

**This file flows OUTWARD.** Everything else in `process/` came from the kit; this is the one
document that goes back. It is input to the kit's next extraction, and it is the only channel by
which the kit hears from a project that is actually running it.

**Append-only, newest at the bottom, stable ids.** An entry is `K-NN` and keeps its number forever,
so a later entry can amend an earlier one by name (`K-<NN> AMENDS K-<MM>`) rather than by editing it.
Editing a sent entry breaks the only shared reference you and the kit have.

**When entries are written.** Kit feedback, unless `PROJECT.md` sets `kit-feedback: manual` or `off`: seats write entries at the capture moments without being asked — `process/MANUAL.md` § Kit feedback.

## About this project

<!-- Written BY HAND, for a stranger. NEVER copied from PROJECT.md: you choose what leaves. Every
     entry below is read against this block, so it is what makes an entry mean something to a
     reader who has never seen this project. -->

- **What it is, in two sentences:** <what the project does, and for whom>
- **Stack:** <languages, runtime, test runner, in one line>
- **Environment:** <operating system> · <the agent tool the seats run in, or "none">
- **Kit version:** adopted at <X.Y.Z>; running <X.Y.Z>

## What belongs here, in descending value

**The kit is read far more often than it is run.** Its maintainers sweep it by reading; what they
cannot reach that way is what you find by USE. So the most valuable entry you can write is the one
you could only have discovered by doing the work:

1. **A thing that broke when you ran it.** A script that died, a gate that passed something it
   should have caught, an instruction that could not be followed on your stack. Quote the kit
   script's own diagnostic line. Never quote test-runner or gate output, which carries your
   project's test output, and never your source, diffs or file contents; describe what they showed
   instead.
2. **A rule that could not be obeyed as written** in a conforming project — it contradicts another
   kit rule, or assumes something your adapter does not declare.
3. **A tool or skill that answered confidently and wrongly.** These are the expensive ones: name
   what it reported and what was true.
4. **A gap you had to fill yourself.** If you invented a convention because the kit had none, say
   so and show it — the kit would rather ship your invention than have the next project reinvent it.
5. **Technique you developed that would travel.** Not a complaint; a contribution.

**What does NOT belong here:** your project's own bugs, your preferences about the kit's tone, and
anything you have not measured. *An entry with no evidence costs the kit a round to disprove.*

## The shape of an entry

```
## K-NN — <ONE SENTENCE, THE FINDING ITSELF, not the topic>

**The moment.**
- Hat: <role> · Step: <the kit document and § being followed>
- Working on: <card or PRD id> — <its goal, in one line>
- Found at: <the moment it was noticed — a session close, a run close, an upgrade, a local ruling — or "when asked">
- Kit version: <X.Y.Z> · Project commit: <short sha>
- Kit says: <kit file and line, or §> — or "the kit is silent"
- Workaround taken: <what the project did instead>
- Rule or setting? <optional: would another project want the opposite?>

**What happened, measured <YYYY-MM-DD>.** <what you ran, what you expected, what you got — with the
kit command and its own diagnostic line, or the kit file and its line; never test output>

**Why it is the KIT's rather than this project's.** <the rule, path or § in the kit that is wrong,
missing or unobeyable — or say plainly that you are unsure and why it might be yours>

**What it cost.** <the concrete cost: a discarded dispatch, a wrong landing, an hour>

**Suggested cure, if you have one.** <and mark it as a hypothesis — the kit's maintainers will test
it against their own tree, which has moved since you adopted>

**Instances:** <where and when, so a pattern is visible if it recurs>
```

## Sending it — and RECORD THE CHANNEL

**Send it to the destination `PROJECT.md` § The kit, upstream names** (*Feedback is sent to*). **If
that says nobody, the file stays here, and it is complete as it is**: do not go looking for a
recipient. A recipient you guessed at is worse than none, because the file then leaves to someone
who never agreed to receive it. Nothing sends this file automatically. Sending is always a person's
act, after the review the header asks for.

When you send a snapshot, mark the point and **say how you sent it**:

```
<!-- ────────── SNAPSHOT SENT <YYYY-MM-DD> · via <the channel, named> · through K-NN ────────── -->
```

**Naming the channel is not bookkeeping.** *(Measured 2026-09-04: an adopter and a kit maintainer
compared notes and neither could say by what route the previous snapshot had travelled. Both knew
it had arrived; neither could repeat it.)* A snapshot whose channel nobody recorded cannot be sent
the same way twice, and an entry you believe was delivered is worse than one you know was not.

**Where there is a destination, send early and send partial.** The kit would rather have twelve
entries now than ninety at the next extraction — a finding that arrives while the kit is being
worked on gets fixed; the same finding arriving after a cut waits for the one after it.

## Entries

<!-- The first entry onward, newest at the bottom. A finding day one actually measured belongs
     here all the same; on day one that may be nothing, and nothing is correct. What does not
     belong is an entry written to fill the file. -->
