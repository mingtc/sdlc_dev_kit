<!-- KIT-CLASS: KIT — contract sheet: the liveness / watchdog ritual. See process/EXTRACTION.md. -->
# CONTRACT — the liveness / watchdog ritual

## 1. PURPOSE

To make *"is that long run still alive?"* a **question with evidence behind it**, because a hang
is silent and therefore indistinguishable from progress to anyone who is only waiting.

**AND A SECOND QUESTION:** *has work
stopped moving?* They are not the same question and they do not have the same scope, and reading
them as one cost a coordinated run twenty-four hours across three episodes.

## 1a. TWO RITUALS, AND ONLY ONE OF THEM CAN EVER BE N/A

| | **DURATION liveness** | **ABSENCE liveness** |
|---|---|---|
| the question | is this long run still alive? | has work stopped moving? |
| the subject | one run, while it runs | the project, always |
| armed | at that run's launch | once, and never disarmed |
| **retired** | **by the act that ends that run, in the same step** — § 2 | **never — the project has no end** |
| **N/A for** | **a project with no long runs — legitimately** | **nobody** |

**THE SPLIT IS THE FINDING, and it was paid for in full.** This sheet's scope test was invariant 1
below — *"any run expected to outlast a human's attention"* — restated in the transferable manual
as *"~30 minutes"*. A project reading that honestly, having no runs of that length, declared the
whole ritual **not applicable**. Its reasoning was correct and the conclusion was a hole: **the
failure that then arrived was not a run hanging. It was work stopping.** Three times, and nobody
was watching, because the only ritual on this page was scoped by a duration the project did not
have.

**So: a duration scope may exempt a project from the duration ritual and from nothing else.** If
your answer to the absence half is *N/A*, the answer is wrong — there is no project in which
"has anything happened lately" is a question without a subject.

## 2. HARD INVARIANTS

- **A watchdog is ARMED AT LAUNCH for any run expected to outlast a human's attention.** Not
  added later, when the run already looks slow. **This is the DURATION ritual, and it is the one
  a project may declare N/A** — see § 1a for what that does not exempt.
  *Why:* the moment you start wondering is the moment you have already lost the baseline you
  needed to compare against.
- **A DURATION watchdog is RETIRED BY THE ACT THAT ENDS ITS RUN, in the same step — and that
  step ENUMERATES what the run armed rather than walking a list of handles it happens to hold.**
  **This binds the DURATION column only.** § 1a's *"once, and never disarmed"* for the ABSENCE
  half is correct and unchanged: the absence watchdog's subject is the project, which has no end,
  so it has no ending act to be retired by. Nothing above is superseded — the arm invariant and
  this one are the two halves of one lifecycle.
  *Why:* a teardown written as a list of handles — pids, session directories, process names —
  **cannot retire a thing that has neither**, and the party most likely to hold such a thing is
  the party running the teardown. Measured: a coordinated run's own recurring wake-up fired
  eleven and a half minutes after that run's `CLOSE`, having never been eligible for either of
  the two stop mechanisms the close ritual had. Nothing was harmed that time. The previous run's
  strays were not so cheap — two samplers still running **six days** after its close, both
  pointed at deleted paths, one appending rows to a tracked file every five minutes, and clearing
  them became the next run's blocking precondition.
  *And the check that would have caught it must be read back, not assumed:* a process listing
  cannot see a scheduled wake-up. Confirming retirement means **reading the scheduler back** —
  the same gesture arming it already made.
- **ABSENCE liveness is armed ONCE, for the project, and is never N/A.** Its subject is not a run;
  it is whether the work is moving at all.
  *Why:* the measured failure was not a hang. Work stopped, the party who would have noticed was
  the party who had stopped, and a ritual scoped to long runs had nothing to say about it.
- **THE ABSENCE SIGNAL IS THE NEWEST COMMIT ACROSS ALL REFS ON THE REMOTE — never `HEAD`, and
  never the checkout.** Read it with `git ls-remote` and take the newest committer date across
  every head.
  *Why:* `HEAD` is one branch in one worktree. In a process that moves work between refs
  constantly, a probe on the checked-out tip measures one lane of a road. Measured, at one
  instant, in a project of exactly this shape: **697 minutes since HEAD moved, 1 minute since
  anything moved.** A monitor keyed on `HEAD` reported a dead project that was working normally,
  and its next reading will be believed less.
  *And the remote rather than a clone is a POLICY, said as one:* the process publishes to the
  remote, so a leg working longer than the threshold **without pushing** is, from the process's
  point of view, stalled. Reading every clone would need access the process does not have.
- **THE SIGNAL MUST BE A BY-PRODUCT OF WORK, NOT SOMETHING A WORKER CAN EMIT.** An empty commit
  moves *newest commit across all refs*. So does a one-line heartbeat appended to the running log.
  **A check you can satisfy by editing the answer is not a check** — the rule is
  [`../doctrine/instruments.md`](../doctrine/instruments.md) § A.12, and this is where a liveness
  signal meets it.
  *Why:* the first genuinely stalled run will otherwise be kept "alive" by exactly that gesture,
  by someone acting in good faith who believes the signal is the point.
- **THE THRESHOLD IS RELATIVE TO THE DECLARED CADENCE, not a fixed number of minutes.** A run that
  declares expected quiet of four hours is not stalled at ninety minutes.
  *Why:* an alarm on a fixed threshold fires through every night and every weekend until somebody
  mutes it, and a muted alarm is worse than none — it reads as armed.
- **Liveness is ARTIFACT FRESHNESS — growth over time — and never the absence of news.** A live
  run is proven by something measurably changing; nothing else counts.
  *Why:* a hung run and a healthy quiet run emit exactly the same thing, which is nothing, so
  "no complaints" is not a signal at all.
  **Where the watched thing is a PROMPTED AGENT SESSION, this invariant has a second edge and it
  is the sharper one:** such a session cannot emit anything while idle, because sending is an act.
  So it cannot report the one state you need — that it has stopped — and two of them watching each
  other go quiet together. What a spawner owes a set of them (only the spawner has a clock; notes
  from inside the work; overdue with a named owner; pause and done as files; and the obligation
  written where an unprompted successor will find it) is
  [`../doctrine/subagent-control.md`](../doctrine/subagent-control.md) § A.15.
- **The watched signal MUST be one that actually moves mid-run.** Choose it by asking *what
  changes while this is working?* and confirm that it does before trusting it.
  *Why:* a watchdog keyed on something that cannot move is not a watchdog; it is a scheduled
  false alarm.
- **A symbolic link is RESOLVED before its freshness is read.** The freshness of the link is not
  the freshness of the thing it points at.
  *Why:* a link's own timestamp never moves, so an unresolved probe reports a dead run forever
  and trains its reader to ignore it.
- **NEVER key liveness on output that is written through a buffered pipeline** — anything whose
  visible tail can only appear when the run finishes.
  *Why:* by construction that artifact cannot grow mid-run, so it false-alarms every time, which
  is how a watchdog becomes noise and then becomes ignored.
- **An alert is a trigger to PROBE, NOT TO CONCLUDE.** Distinguish a settle or throttle pause
  from a hang with a longer sampling window, an independent signal, or an inspection of what the
  worker is doing.
  *Why:* a short zero-progress window is routine, and a watchdog that concludes from one sample
  kills healthy work.
- **Every status statement about an unfinished run rests on a FRESH probe.** A report of health
  older than the last sample is not a report.
  *Why:* no news sometimes is not good news, and repeating a stale reassurance is how eight hours
  of nothing get reported as progress.
- **Exit without the run's own completion marker is a FAILURE**, however clean the exit looked.
  *Why:* a worker that dies quietly is the exact case every other signal misses.

## 2a. THE READER — the half this sheet did not have

**A SIGNAL NOBODY READS IS ABSENCE-OF-NEWS ONE LEVEL UP.** Every invariant above is about choosing
and sampling a signal. None of them says who looks, and that omission is what the measured failure
actually was: the signal moved, or did not, and **nobody was reading it** — because the party who
would have noticed the stall was the party that had stalled.

- **The absence half needs a reader that is NOT the party being watched.** An alarm, not a habit.
  A discipline that says *watch this signal* has, for the absence question, simply restated
  absence-of-news at a higher altitude.
- **Self-monitoring is legitimate for the DURATION half** — a run watching its own workers has an
  outside observer, namely the run. It is not legitimate for the absence half, where the thing
  that stops is the thing that would have looked.
- **The reader must be able to reach a person.** A file nothing opens, a log nothing tails and a
  status line nobody is looking at are all the same artifact.

*The kit ships one:* [`scripts/notify/stall.sh`](../../scripts/notify/stall.sh) reads the remote's
freshest ref against a threshold and reports through the notification hook. It is the smallest
thing that answers *who looks*, and it exists because the discipline alone did not.

## 3. REFUSAL CONDITIONS

- A long run is launched **without** a watchdog ⇒ that is the defect; the run's status is
  unknowable from then on.
- The chosen signal cannot be shown to move during a healthy run ⇒ refuse the signal and pick
  another; do not arm a watchdog you already know will lie.
- The freshness of the signal cannot be read at all ⇒ report **unknown**, never alive. Unknown and
  alive are different answers.
- A sample crosses the staleness bound ⇒ raise the alert, and escalate only after a second,
  independent probe agrees.
- The worker is gone and the completion marker is absent ⇒ report failure, whatever the exit
  status said.
- **The ABSENCE half is declared N/A ⇒ refuse the declaration.** A project with no long runs may
  exempt itself from the duration ritual; there is no project without work that can stop. § 1a.
- **The absence signal is `HEAD`, or a checkout, or anything a worker can emit on purpose ⇒
  refuse the signal.** Those are three different defects with one consequence: a reading that is
  true of something nobody asked about.
- **Nothing reads the absence signal ⇒ the ritual is not armed, whatever is configured.** § 2a.
- **A run ends and its DURATION watchdog is still armed ⇒ that run is not closed.** The close is
  not done when the work is done; it is done when what the run armed has been enumerated and
  retired. **A process check does not discharge this** — a scheduled wake-up has no process, so
  *nothing in `ps`* is a reading about processes and not an answer about arms.

## 4. WHAT GREEN MEANS

Green is **a measurement with a timestamp**, not an adjective:

1. The watched signal's **freshness at a stated moment**, and the **delta** since the previous
   sample — a number, not "still going".
2. The **sampling interval and the staleness bound**, so a reader can judge the claim.
3. On alert: the **second probe's** result alongside the first, so escalation is visibly a
   conclusion from two observations rather than from one.

## 5. MINIMAL INTERFACE

**In:** the run's identity; a signal that provably moves while it works; a sampling interval; a
staleness bound; the run's completion marker; **and, for the DURATION half, the enumeration of
what this run armed** — every watcher, sampler and scheduled wake-up, each with the act that
retires it.
**Out:** timestamped freshness samples with deltas; an alert on a crossed bound; a final verdict
of completed / failed / unknown — and *unknown* is a legal, honest verdict; **and, at the close of
a DURATION run, that enumeration walked, with each arm read back as retired.** Walking an empty
enumeration is a normal close and **completes without error** — a retirement step that failed on
a run that armed nothing would make every clean close look broken, which is how a step gets
skipped.
**Not in:** killing the run. Deciding to stop work is a human's call informed by these
observations.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- **The DURATION half is a discipline, not a program:** it is armed per run, keyed on whatever that
  run's own artifacts are, and no shipped program could know what those are. **The ABSENCE half is
  a program:** its signal is the same for every project running this process — the remote's
  freshest ref — so it can be one, and it is:
  [`scripts/notify/stall.sh`](../../scripts/notify/stall.sh). *A gate beats a sentence wherever a
  sentence can be replaced by one.*
- [`../MANUAL.md`](../MANUAL.md) § Execution discipline, item 4 — the same discipline in the
  transferable manual; the adapter may restate it as project law.
- Provenance: ratified after a run was reported healthy for hours on the strength of no news,
  and hardened again over the seats that followed.
