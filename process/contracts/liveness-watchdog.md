<!-- KIT-CLASS: KIT — contract sheet: the liveness / watchdog ritual. See process/EXTRACTION.md. -->
# CONTRACT — the liveness / watchdog ritual

## 1. PURPOSE

To make *"is that long run still alive?"* a **question with evidence behind it**, because a hang
is silent and therefore indistinguishable from progress to anyone who is only waiting.

## 2. HARD INVARIANTS

- **A watchdog is ARMED AT LAUNCH for any run expected to outlast a human's attention.** Not
  added later, when the run already looks slow.
  *Why:* the moment you start wondering is the moment you have already lost the baseline you
  needed to compare against.
- **Liveness is ARTIFACT FRESHNESS — growth over time — and never the absence of news.** A live
  run is proven by something measurably changing; nothing else counts.
  *Why:* a hung run and a healthy quiet run emit exactly the same thing, which is nothing, so
  "no complaints" is not a signal at all.
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

## 4. WHAT GREEN MEANS

Green is **a measurement with a timestamp**, not an adjective:

1. The watched signal's **freshness at a stated moment**, and the **delta** since the previous
   sample — a number, not "still going".
2. The **sampling interval and the staleness bound**, so a reader can judge the claim.
3. On alert: the **second probe's** result alongside the first, so escalation is visibly a
   conclusion from two observations rather than from one.

## 5. MINIMAL INTERFACE

**In:** the run's identity; a signal that provably moves while it works; a sampling interval; a
staleness bound; the run's completion marker.
**Out:** timestamped freshness samples with deltas; an alert on a crossed bound; a final verdict
of completed / failed / unknown — and *unknown* is a legal, honest verdict.
**Not in:** killing the run. Deciding to stop work is a human's call informed by these
observations.

## 6. REFERENCE IMPLEMENTATION

> One implementation, not the definition.

- This ritual is **a discipline, not a program** — this kit ships no watchdog binary, which
  is precisely why its rules had to be written down here.
- [`../MANUAL.md`](../MANUAL.md) § Execution discipline, item 4 — the same discipline in the
  transferable manual; the adapter may restate it as project law.
- Provenance: ratified after a run was reported healthy for hours on the strength of no news,
  and hardened again over the seats that followed.
