<!-- KIT-CLASS: KIT — the run-report shape. Copy, fill the <slots>, delete every GUIDANCE line. -->
<!-- LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS — dev/launch/ — NOT to process/templates/
     where it sits. A link that resolves while you read the template and dies in every copy of it
     passes a link check run here and is broken for every adopter. -->
# Run-report template — the close record for one orchestrated run

> **GUIDANCE — how to use this file.** Copy it to
> `dev/launch/<YYYY-MM-DD>-<run-name>-run-report.md`, fill the `<slots>`, delete every line that
> starts with `GUIDANCE`. The report is written **by the runner that executed the pack**, and it
> is the deliverable that closes the pack: the pack is stamped `SPENT` **against this file, by
> name, in the same commit that lands it** ([`process/doctrine/staleness.md`](../../process/doctrine/staleness.md)).
>
> **What a run report is for.** Not a diary. It is (a) the evidence that the run's claims are
> measurements, (b) the ledger of everything the run left behind, and (c) the batch of questions
> the seat answers *between* runs. A report that only grades the legs is worthless — it grades
> the pack, the issues, and the orchestrator's own conduct too.
>
> **Sections are load-bearing, not decorative.** Drop a section only by writing what it would
> have said: "Residue: none" is a claim, and § Residue is where it gets checked. An empty section
> says so explicitly.
>
> **Open it early, write it as you go.** A report started at close is a report reconstructed from
> memory. Open it after the first leg, keep the landing table current, and mark unfinished issues
> `IN FLIGHT` / `NOT STARTED` so an interrupted run leaves a truthful artifact.

---

## The header and the independence clause

> **GUIDANCE.** Two blocks, always. The STATUS banner (`OPEN` → `CLOSED`, or `SUPERSEDED BY` if a
> later report replaces it), and the **independence clause** — the sentence that makes every
> number in the file readable. If a figure was inherited rather than re-measured, it is **labelled
> as inherited** at the point of use. That label is what keeps the clause honest.

```
# <RUN NAME> — RUN REPORT (opened <date>, closed <date>)

> **STATUS: CLOSED. <X> of <N> landed, <Y> parked at close.** The commissioning pack
> [`<date>-<name>-pack.md`](<date>-<name>-pack.md) is **SPENT** (stamped in the same commit as
> this file). <Any mid-run consult document is **SUPERSEDED by this file** and stamped likewise —
> kept as the record of what the seat was consulted on, not as current state.>
>
> **Every figure below was measured by the orchestrator independently of the leg that claimed
> it.** Where the two disagreed, the measurement wins and the disagreement is stated. Figures
> inherited rather than re-measured are labelled as such.
```

---

## 1. The landing table

> **GUIDANCE.** One row per issue, in **execution order** (not pack order — deviations are stated
> below the table with who authorized them). The **verdict path** column is the point of the
> table: not "PASS" but *how* it got there, because the shape of the path is the run's most
> reusable finding. Use the vocabulary consistently:
>
> - `work PASS → QA PASS` — clean.
> - `→ QA FAIL (AC<n>) → 1 fix round → QA #2 PASS` — the normal recovery. Name the AC that failed.
> - `QA PASS-with-AC-correction` — passed, and the AC itself was wrong; the correction is in § 2.
> - `→ QA FAIL → fix → QA FAIL → PARKED` — fix budget spent. Parking is a legitimate close.
> - `PARKED → seat-authorized round 2 → PASS` — name the authorizing commit or message.
> - `PARKED_OK` — parked **and verified parked**: findings evidence-backed, issue in the blocked
>   folder, no half-landed residue. A park nobody reviewed is not a close.
> - `LAND-READY` — verified and reviewed but not landed (blocked-push regime; see
>   [`process/GIT-HOSTING.md`](../../process/GIT-HOSTING.md)). Record the branch and its head SHA. **In the ratified
>   vocabulary this is verdict `PASS` with landing `deferred`** — a success, and the runners continue
>   past it. *(This column had a way to say "green but not landed" before the machinery did, which
>   is how the gap was visible in reports and invisible to the schema that halted on it.)*
>
> The gate column quotes the runner's **own summary line, verbatim** — never a hand-typed count.

| # | Issue | Landing SHA | Verdict path | Gate on the branch (verbatim) |
|---|---|---|---|---|
| 1 | **<PREFIX>-<a>** <identity> | **`<sha>`** | <path> | `<verbatim summary line>` |
| 2 | **<PREFIX>-<b>** <identity> | **`<sha>`** | <path> | `<verbatim summary line>` |
| 3 | **<PREFIX>-<c>** <identity> | — | **PARKED_OK** | `<verbatim summary line>` |

**Run-order deviation<, if any>:** <what the pack ordered, what actually ran, and **who
authorized the change** — a commit or a recorded seat ruling. "Nothing else moved" is worth
saying.>

**Close gate, on `<trunk>`, unpiped, exit code read from the summary block:**

```
<the verbatim summary block from ./scripts/verify.sh, including its PASS/FAIL lines>
```

<Any change in the skipped/deselected count is explained here as *the new normal* or *drift* —
an unexplained change in what a gate skips is a finding, not noise.>
`./scripts/check-board.sh`: **<clean ✓ | the findings, verbatim>**.

---

## 2. Per-issue detail

> **GUIDANCE.** One subsection per issue: `### <PREFIX>-<n> — <verdict>, \`<sha>\``. Two to ten
> lines each. What belongs here and nowhere else:
>
> - **what the issue actually delivered**, in the reader's terms, not the diff's;
> - **the AC corrections** — where the AC was wrong and QA judged the departure justified,
>   quoting the AC clause that permits the judgment;
> - **an overturned premise** — when the issue's own diagnosis was wrong and the leg proved a
>   different mechanism. Say the old diagnosis, the new one, and the evidence. This is a *result*,
>   not an embarrassment;
> - **the guard transformations**, each naming the issue and carrying the original reason
>   forward ([`process/doctrine/supersession.md`](../../process/doctrine/supersession.md));
> - for a parked issue: the findings, and the **park verification** (§ 1's `PARKED_OK`).

### <PREFIX>-<n> — <PASS | FAIL → fix → PASS | PARKED_OK>, `<sha>`

- <delivered>
- <AC correction / overturned premise, with the evidence>
- <guard transformed: which guard, what changed, whose reason it still carries>

---

## 3. Gates — measured independently, never relayed

> **GUIDANCE.** A short section that exists to be checkable. For each gate the run cares about:
> what was run, **where** (which worktree, which ref), the verbatim summary, and the exit code —
> read from the summary block rather than from a piped `$?`. Then the two comparisons that catch
> silent regressions:
>
> - **the collected-test-identifier diff against the trunk** (`+n / -m`) — what your runner calls
>   its test ids; a removal is a behavior change until an AC names it;
> - **the generated/golden artifact diff** — empty, or the consented set enumerated.
>
> A gate claimed by a leg and not re-run by the orchestrator is labelled **relayed** and treated
> as unverified. Prefer to re-run: it is cheap, and the belt's whole premise is that self-reports
> miss what instruments catch.

| Gate | Where | Verbatim summary | Exit |
|---|---|---|---|
| <full gate script> | `<trunk>` at close | `<…>` | `<0>` |
| <quick gate> | `<branch>` pre-land | `<…>` | `<0>` |

---

## 4. Behavior-preservation accounting

> **GUIDANCE.** State it **precisely rather than as "zero"**, because a pack's spine is usually
> *zero-except-where-an-AC-names-each-removal*, and a bare "zero" hides the difference between
> "no test was removed" and "no test **function** was removed while parametrized case labels
> moved". Both are fine; only one of them is true. Enumerate:
>
> - collected identifiers before → after (net), then **every removal, with its justification and
>   its named successor**, and the granularity at which the number is zero;
> - generated/golden artifacts: byte-identical throughout, with the consented exceptions
>   **enumerated one by one** (not "a few goldens moved");
> - expensive-artifact regenerations: a small table — row, issue, size, what moved, cost paid.
>   **The generated diff is the disclosure**; no hand arithmetic in prose;
> - **where the source tree was untouched as promised**, at zero lines, per issue. A promise kept
>   is evidence too, and it is the cheapest thing in the report to verify.

- **Collected identifiers: <before> → <after> (<net>).** <k> removed across <N> landings, **each
  justified and reviewed**: <enumerate — id, count, reason, successor>. At <granularity> the run
  removed **zero**.
- **Generated/golden artifacts: byte-identical throughout, with exactly <n> consented,
  enumerated exception(s)** — <enumerate>.
- **<Expensive artifact>: <before> → <after>**, paid by <n> regeneration(s) and no hand
  arithmetic.
- **Source untouched where promised:** <issue> at 0 lines; <issue>'s <boundary> at 0 lines.

---

## 5. Incidents

> **GUIDANCE.** A section per incident, headed `## ⚠ <what fence was breached>`. Only real
> incidents — a fence crossed, a resource created that the pack forbade, a credential or live
> ring fired, a worktree poisoned. Write it in this order, because it is the order a reader needs:
>
> 1. **How it was found** — and if an instrument found it rather than a self-report, say so, with
>    the instrument's readings before and after. That asymmetry is usually the most transferable
>    lesson in the whole report.
> 2. **What exists now, named** — every artifact, by identifier, with its state. A count is not a
>    name; the operator cannot reclaim a count.
> 3. **What was NOT touched** — the permanent/unpurgeable class especially. A bounded blast
>    radius is a finding.
> 4. **Cause, mechanically.** No adjectives. The exact flag, command or condition, and **whether
>    the trap was documented** — a documented trap that fired anyway is a design finding, not a
>    discipline finding.
> 5. **Attribution and honesty.** Which leg, from timestamps, and what that leg reported. If the
>    report was wrong without being deceptive, say exactly that — the failure to connect a slow
>    run to its cause is a different defect from a false claim, and it needs a different cure.
> 6. **The cure, and whether it landed.** A structural fence beats an instruction.
>    See [`process/doctrine/live-resources.md`](../../process/doctrine/live-resources.md).

---

## 6. The belt readings

> **GUIDANCE.** The between-leg checks and what they read. A table, or one line per boundary —
> whichever is shorter. The point is that the readings **exist and are dated**, so a later
> incident can be bracketed to a leg. Include the unchanging readings: "identical bytes and hash
> at all <n> boundaries" is the reading that makes an incident's single movement legible.

| Reading | At open | Movement during the run | At close |
|---|---|---|---|
| <destructive-resource ledger> hash / size | `<hash>` / <n> B | <none, or the one movement with its boundary> | `<hash>` / <n> B |
| Tree (`git status --porcelain`) | clean | <…> | clean |
| Board (`check-board.sh`) | exit 0 | <…> | exit 0 |
| Remote (`git ls-remote <remote> <trunk>`) | `<sha>` | monotonic, <n> readings | `<sha>` |

---

## 7. The dominant defect class

> **GUIDANCE.** Optional but high-value: when several FAILs turn out to be **one shape**, say the
> shape, tabulate the instances, and then find the **structural cause** — which is almost never
> carelessness. Then: the mitigation applied mid-run, and whether it worked, measured. A defect
> class with a mid-run mitigation and an after-measurement is the finding most likely to change
> how the next pack is written, which is exactly what this section is for.
>
> Recurring example worth recognizing: **a claim broader than its evidence**, structurally caused
> by many issues writing into **one shared open section** — each leg validates its own additions
> and never re-reads the section, so every absolute an earlier issue lands becomes a tripwire the
> next one breaks. The cure that worked: sweep each affected document **separately** (twin
> documents are not mirrors), **scope rather than delete** an earlier change's still-true claim,
> every number **derived + dated + method-stated or not stated at all**, and **a correction must
> reach where it SHIPS**, not only the ruling that records it.

---

## 8. Discrepancies — the repo beat the text, and the file wins

> **GUIDANCE.** A numbered ledger. Every place the pack, an issue, a plan or an audit disagreed
> with the tree — **including the ones that cost nothing**, because the pattern is the value.
> Each entry: what the text said → what the tree said → what was done (corrected in the brief /
> corrected in the file / left standing and why / **not filed, and who owes the filing**).
> Two kinds are worth calling out explicitly when they occur:
>
> - **a stale baseline** — a figure a mint derived before this run's own earlier issues moved it.
>   The report says so, because the next reader will otherwise treat it as a defect;
> - **a retired number rehabilitated as a prediction** — a figure discarded as wrong that turns
>   out to describe a real state some distance away. Say which state; it is evidence about the
>   model, not noise.
>
> End with the positive control: **"otherwise every figure the mint asserted measured true"**,
> and list the ones re-derived and matched. A discrepancy ledger with no verified-true list reads
> like a complaint.

1. <text said → tree said → disposition>
2. <…>
<n>. **Otherwise every figure asserted at mint measured true.** Independently re-derived and
matched at open: <list>.

---

## 9. Decisions for the seat — batched, none of them stopped the run

> **GUIDANCE.** The batch. This section is why the run did not pause: everything that needed a
> human or a seat judgment and was **not one of the four stop events** lands here
> ([`process/doctrine/orchestration.md`](../../process/doctrine/orchestration.md)). Each item: the question, the
> evidence, and a **recommendation** — a decision request without a recommendation pushes the work
> back to the seat. Say who owns each (PM scope / seat ruling / operator action) and whether it
> blocks anything.
>
> Include, as separate named items: issues filed during the run (with what discovered them);
> issues that turned out **subsumed** by a change that falsified them rather than scheduled
> behind it; Minors observed and deliberately **not** filed, with who owns the filing; and the
> riders — a bound whose *wording* is narrower than its *reason*, a sentence that is a universal
> over a set with one member that does not fit. Riders are cheap to record and expensive to
> rediscover.

- **<PREFIX>-<n>** *(<QA-filed | seat | PM>, `discovered_in: <PREFIX>-<m>`)* — <question>.
  Evidence: <…>. **Recommendation:** <…>. Owner: <…>. Blocks: <nothing | …>.
- **<observation with no id>** — <the finding, and who owes the filing>.

---

## 10. Residue, by name — and it is probably not "none"

> **GUIDANCE.** The pack usually expects none. Check anyway, and name each item — a count cannot
> be reclaimed, cleaned up, or handed to an operator. The classes that recur:
>
> 1. **Live/destructive resources** that outlived the run: named identifiers, current state, whose
>    they are to reclaim, and what will flag them next.
> 2. **Branches still on the remote** after a landing reported deleting them — with the head SHA
>    and the assertion that the contents *are* on the trunk. If it looks systematic rather than
>    incidental, say so; that is a kit defect worth an issue.
> 3. **Worktrees and local branches** the run created: removed at close, or named as surviving.
> 4. **The explicit zeros**, stated as claims so they are checkable: zero destructive resources
>    created, zero uploads, zero live writes.

1. <named resource / state / whose it is / what flags it next>
2. <branches surviving on the remote, with SHAs, and whether it looks systematic>
3. <worktrees + local branches, removed or surviving>
4. **ZERO <resource class> created. ZERO <sends>. ZERO <uploads>.**

---

## 11. Close-out state, and the orchestrator's own misses

> **GUIDANCE.** Two blocks. First the mechanical close: the board census by folder, the board
> check's own output, worktrees left standing and why, anything swept.
>
> Then — **required, not optional** — the orchestrator's own misses. *A report that only grades
> others is worthless.* List them: a leg's claim let through unchallenged, a diff computed against
> a stale baseline, a reasoning error inherited from a leg, a mis-report from truncated output,
> **and every pause taken on something that was not a stop event**. Where a miss produced a
> standing rule, say which rule — a doctrine sheet whose reason is a named miss in a named report
> is a rule that survives its author.

**Board:** `todo` <n> · `in_progress` <n> · `dev_complete` <n> · `qa_complete` <n> · `blocked`
<n> (<which, and whether pre-existing>). `./scripts/check-board.sh`: **<clean ✓ | findings>**.
**Worktrees:** <removed at close | left standing, named, and why>.

**The orchestrator's own misses, recorded because a report that only grades others is worthless:**

- <miss> — <what it cost, and the rule it produced, if any>
- <miss> — <…>

---

## Closing checklist (the runner's, before the report lands)

- [ ] Every `<slot>` filled; every `GUIDANCE` line deleted.
- [ ] Every figure either **re-measured** by the orchestrator or **labelled inherited**.
- [ ] Every gate quote is verbatim and unpiped, with its exit code read from the summary.
- [ ] Every removal of a test identifier or generated artifact is enumerated and justified.
- [ ] Residue named, not counted. Zeros stated as claims.
- [ ] The decision batch has a recommendation and an owner per item.
- [ ] The orchestrator's own misses section is non-empty or explicitly says why.
- [ ] The commissioning pack is stamped **SPENT against this file by name, in this commit**; any
      mid-run consult document is stamped **SUPERSEDED by this file**.
- [ ] `dev/launch/` has its row in `dev/README.md` (the **directory's** row, added when the
      directory was created — not a row per report), and this report is named to that directory's
      dated convention so its own README and an `ls` place it. *Per-file rows are not owed for a
      split-out directory; `dev/README.md` § The index discipline states the exception.*
