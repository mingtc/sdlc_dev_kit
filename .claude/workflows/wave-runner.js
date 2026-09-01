// KIT-CLASS: KIT — the two-wave parallel runner. Everything project-specific is in CFG below.
export const meta = {
  name: 'wave-runner',
  description: 'Run two waves of zero-overlap issues in parallel (args: {repo, wave1:[...], wave2:[...]}, same per-issue fields as tranche-runner plus the wave-only ones (worktreeMode, phase, restartNote), including docsPath for the direct-to-trunk lite variant). One leg of each pair runs in a self-created worktree so pairs never contend for the main checkout; the board mover and the landing script serialize via the kanban worktree lock. Prompts, schemas and provisioning mirror tranche-runner.js; the park-QA discipline mirrors it EXCEPT that a park this runner cannot verify halts the wave immediately, where tranche-runner grants one bounded fix round first — stated because a claim of mirroring is read as total. The price of the parallelism: merge-conflict bounces are possible — assign zero-overlap surfaces per pair and SAY them in extraDev.',
  phases: [
    { title: 'Wave1', detail: 'first parallel pair' },
    { title: 'Wave2', detail: 'second parallel pair' },
  ],
}

// issue.docsPath — same field name and semantics as tranche-runner.js: true for a
// docs/process-lite issue with NO work branch (direct-to-trunk). On the docs path there is
// nothing for the landing script to squash-merge, so such an issue reports
// `landing: not_applicable` — a true statement rather than a value the caller has to know
// to forgive. This comment used to explain why a `landed:false` on the docs path was
// "CORRECT, not a failure"; that reasoning was right and is preserved by the field now being
// able to SAY it, which is what retired the carve-out rather than deleting it.

// THE PARSE IS GUARDED, and the reason is that the unguarded version's failure named nothing it
// could have named. A non-JSON payload produced a bare `SyntaxError: JSON Parse error: Unexpected
// identifier` whose only location was the HARNESS file, not this one — so the message pointed away
// from the thing that was wrong, at the entry point an operator drives first and is most likely to
// get wrong. The fail-fast was right and is kept: the run still dies at 0 agents, cheaply.
//
// The message names THIS runner, echoes the value it got (truncated, so a large payload cannot bury
// the message), and names the REQUIRED top-level keys only — the full per-issue shape stays at its
// one authoring site above rather than being copied here, because a copied contract is the one that
// rots. This is the same shape as the `if (!CFG.repo) throw` below, which was already a named,
// actionable refusal and simply never got reached.
let ARGS
try {
  ARGS = typeof args === 'string' ? JSON.parse(args) : args
} catch (e) {
  throw new Error(`wave-runner: args must be a JSON object, not prose. Got: ${String(args).slice(0, 60)}\nExpected: { repo, wave1: [...], wave2: [...] } — the full shape is in this file's meta.description and the per-issue fields mirror tranche-runner.js\nUnderlying parse error: ${e.message}`)
}

// ---------------------------------------------------------------------------
// CFG — the only project-specific values in this file. Override any of them per
// run via args; the defaults are the kit's, not any one project's. Keep them in
// sync with scripts/config.sh and the project adapter (CLAUDE.md).
// ---------------------------------------------------------------------------
const CFG = {
  repo:        ARGS.repo,                                   // REQUIRED: absolute path to the main repo
  trunk:       ARGS.trunk       || 'main',
  remote:      ARGS.remote      || 'origin',
  gateCmd:     ARGS.gateCmd     || './scripts/verify.sh',
  setupCmd:    ARGS.setupCmd    || './setup.sh',            // worktree bootstrap, if the project has one
  codePaths:   ARGS.codePaths   || 'src/**, tests/**, and the build/dependency manifest',
  // Pinned-output paths a behavior-preserving change must not move. Empty string = skip
  // the zero-drift diff entirely (a project with no goldens should pass '').
  // `??` NOT `||`, and the difference is the whole point: `'' || <default>` IS the default, so
  // passing the empty string restored the very value it was documented to suppress. `??` falls
  // through only on null/undefined, so '' reaches CFG.goldenPaths, the drift step's own
  // `CFG.goldenPaths &&` guard is falsy on it, and the step is skipped as documented. Do not
  // "tidy" this back to `||` for consistency with its neighbours: this is the one default in this
  // block with a meaningful empty value, and scripts/test/run.sh asserts the `??` in both runners.
  goldenPaths: ARGS.goldenPaths ?? 'tests/fixtures tests/golden*',
  secretsFile: ARGS.secretsFile || '.env',                  // gitignored credentials file, if any
  liveRules:   ARGS.liveRules   || '',
}
if (!CFG.repo) throw new Error('wave-runner: args.repo is required (absolute path to the main repo)')

// AN OMITTED WAVE IS A NAMED REFUSAL, and here the unguarded case failed in the OPPOSITE
// direction from tranche-runner's: an absent list became [], parallel([]) returned [], and
// [].every(...) is VACUOUSLY TRUE — so both wave gates passed and the run returned
// { halted: null, results: [] }. A GREEN over zero issues, which is the worst of the two
// failures because nothing about it looks wrong. One wave is legitimate; neither is not.
for (const k of ['wave1', 'wave2']) {
  if (ARGS[k] !== undefined && ARGS[k] !== null && !Array.isArray(ARGS[k])) {
    throw new Error('wave-runner: args.' + k + ' must be an array of issue objects when present. Got: ' + JSON.stringify(ARGS[k]))
  }
}
if ((ARGS.wave1 ?? []).length === 0 && (ARGS.wave2 ?? []).length === 0) {
  throw new Error('wave-runner: at least one of args.wave1 / args.wave2 must be a NON-EMPTY array of issue objects — a run over zero issues would otherwise report a clean success. Expected: { repo, wave1: [{id, branch, ...}], wave2: [...] }')
}

const DEFAULT_MODEL = 'opus'
const DEFAULT_EFFORT = 'medium'
// See tranche-runner.js for why an omitted effort must resolve to a real value rather than
// inheriting the session default, and how agentType interacts with the explicit overrides.
function provision(label, phase, model, effort, agentType, schema) {
  const opts = { label, phase, model: model || DEFAULT_MODEL, effort: effort || DEFAULT_EFFORT, schema }
  if (agentType) opts.agentType = agentType
  return opts
}

const COMMON = `
Repository (the main repo, absolute path): ${CFG.repo}
Trunk branch: ${CFG.trunk}

HARD CAP — YOU ARE A LEAF WORKER: do NOT spawn subagents, and do not run workflows. Do all of
this work yourself, in this context. Fan-out is the coordinator's decision, never yours.

Ground rules (non-negotiable):
- Read PROJECT.md first, then CLAUDE.md, then your role doc, then the issue file. The issue's AC is the contract.
- QUOTA-LEAN: targeted reads only; NEVER Read an image or a binary file and never screenshot (verify an artifact by hash / size / listing); no full-suite or repeated-build runs beyond the gates named below.
- OUTPUT LENGTH: lead with the outcome; final report <= ~30 lines; commit subjects compact (what+why, no transcripts); Activity and progress.md notes carry evidence POINTERS (file:line, command + its result line), not pasted output.
- No AI co-author trailers in commits. Never commit a secrets file. Role-prefixed commit subjects.
- ZERO-DRIFT discipline unless the issue explicitly consents otherwise: NO change to the project's pinned output. Any golden/snapshot/fixture diff caused by your change is a bug in your change, not a fixture to update.
- Board moves only via ./scripts/move-issue.sh (never move files by hand), invoked FROM THE MAIN REPO DIR — the scripts commit+push via the kanban worktree and never touch any checkout's branch state.
- A PARALLEL leg is working the same repo on a DIFFERENT issue with ZERO file overlap with yours. If you find yourself needing to edit a file the other leg owns (its issue names its surfaces), STOP and return blocked with the evidence instead of creating a conflict.${CFG.liveRules ? `
- ${CFG.liveRules}` : ''}
`

const WORKTREE_MODE = `
WORKTREE MODE — the main checkout belongs to the parallel leg; you never touch it:
- Create your own worktree for ALL code work: from the main repo dir run
  git worktree add /tmp/wt-<your-issue-id> -b <your-branch> ${CFG.remote}/${CFG.trunk}
  (QA legs: git worktree add /tmp/wt-qa-<issue-id> <the-branch-under-review>).
- Work entirely inside that worktree. Bootstrap its dependencies there — a fresh worktree does
  NOT share the main checkout's installed environment: run ${CFG.setupCmd} (or the project's
  declared setup command) inside the worktree. If your gates need credentials, copy the main
  repo's ${CFG.secretsFile} into the worktree (gitignored; never commit it).
- Run the gates from the worktree, using the worktree's own environment.
- Push your branch from the worktree. Board moves and the landing script run from the MAIN repo
  dir (they use the kanban worktree internally and are lock-serialized — safe alongside the
  parallel leg).
- On completion (or any stop): git worktree remove --force your worktree, from the main repo
  dir. Leave nothing mounted.
`

const DEV_SCHEMA = {
  type: 'object',
  properties: {
    status: { enum: ['dev_complete', 'blocked'] },
    branch: { type: 'string' },
    summary: { type: 'string', description: 'what was built + key design choices' },
    test_evidence: { type: 'string', description: 'gate result line(s) actually observed' },
    deviations: { type: 'string' },
  },
  required: ['status', 'branch', 'summary', 'test_evidence'],
}
// ── THE VERDICT VOCABULARY IS PROJECTED, NEVER RE-ENUMERATED ─────────────────
// The authoring site is `process/MANUAL.md` § The Dev → QA handoff, step 6. These
// two constants are its PROJECTION into this runner's schemas; if they disagree
// with that list, the list wins and these are the defect.
//
// WHY THIS EXISTS. The schemas used to read `verdict: PASS|FAIL` plus
// `landed: boolean` — TWO members against the four MANUAL ratifies, and a boolean
// where the ratified vocabulary has three states. A reviewer returning the
// ratified "pass, every gate green, landing deferred" had nowhere to put it and
// had to flatten; the halt below then read the flattened value as a failure and
// STOPPED A RUN THAT HAD SUCCEEDED. That is not a misaimed check — the check was
// correct about what it was given. It is the read-time defect of
// `process/doctrine/instruments.md` § A.9: the machinery reported on its subject
// and on itself in one vocabulary, so nobody could tell the two apart.
//
// THE TWO AXES ARE ORTHOGONAL AND MUST STAY SO. "Did the review pass" and "did the
// change reach the trunk" are different facts. Collapsing them is the entire bug,
// so `landing` is its own field with its own three values — and `not_applicable`
// exists because a docs-path issue has no landing script to complete, which a
// boolean forces to lie in one direction or the other.
const VERDICTS = ['PASS', 'PASS_AC_CORRECTED', 'FAIL_AC', 'FAIL_REGRESSION']
const LANDING = ['landed', 'deferred', 'not_applicable']
// A verdict that means the review passed. PASS_AC_CORRECTED is a PASS whose AC was
// itself wrong and was corrected with the issue — MANUAL step 6's third verdict.
const isPass = v => v === 'PASS' || v === 'PASS_AC_CORRECTED'

const QA_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    landing: { enum: LANDING, description: 'landed = the landing script completed; deferred = verified but deliberately not landed (blocked-push regime) — a SUCCESS, not a failure; not_applicable = there was nothing to land (docs path)' },
    ac_walk: { type: 'string', description: 'per-AC PASS/FAIL with concrete evidence' },
    unmet_ac: { type: 'array', items: { type: 'string' } },
    gate_evidence: { type: 'string', description: 'gate-runner + binding gate outputs observed' },
    notes: { type: 'string' },
  },
  required: ['verdict', 'landing', 'ac_walk', 'gate_evidence'],
}
const PARK_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    // A park lands nothing, so `not_applicable` is the TRUE value rather than an
    // exemption. This replaces the hand-written carve-out that used to say
    // "ALWAYS false for a park — never a failure signal": the reason it gave was
    // right, and with a three-valued field it no longer needs to be an exception.
    landing: { enum: LANDING, description: 'ALWAYS not_applicable for a park — nothing is merged and the issue stays in blocked/' },
    // `park_walk` / `unmet`, matching tranche-runner.js. These used to be `ac_walk`
    // and `unmet_ac` here — the QA field names, reused for a park — so the same
    // outcome came back under two different shapes depending on which runner
    // produced it, and any consumer had to know which. A park review is not an AC
    // walk; the honest names are the ones that describe what it checked. One
    // vocabulary, projected — the same one-vocabulary rule, one level down.
    park_walk: { type: 'string', description: 'per-check PASS/FAIL with concrete evidence: issue sits in blocked/; findings/verdict evidence-backed and honestly scoped; no half-landed residue (clean tree, no stray branch, board move committed); no claim contradicted by the tree' },
    unmet: { type: 'array', items: { type: 'string' }, description: 'what makes the park unverifiable — the fix-round brief' },
    gate_evidence: { type: 'string', description: 'gate runner / check-board.sh / git state observed' },
    notes: { type: 'string' },
  },
  required: ['verdict', 'landing', 'park_walk', 'gate_evidence'],
}

// See tranche-runner.js: an interpolated absent field prints "undefined" into the
// brief as though it were an instruction. Where there is no binding gate, say so.
function gatesOf(issue) {
  return issue.gates ? String(issue.gates) : 'none declared for this issue — the suite alone is the bar here'
}

function devPrompt(issue, fixNotes) {
  // Optional fields are defaulted, never assumed — `.length` on an absent
  // `depends_on` throws and takes the whole wave down at its first issue.
  const deps = Array.isArray(issue.depends_on) ? issue.depends_on : []
  const chain = deps.length
    ? `DEPENDENCY CHAIN — VERIFY FIRST: this issue depends on ${deps.join(', ')} being LANDED on ${CFG.trunk}. Before any work: git log --oneline --grep to confirm each predecessor's "→ qa_complete" landing commit exists on ${CFG.trunk} AND its issue file sits in progress/qa_complete/ or progress/done/. If any link is missing, STOP immediately: return status=blocked with the evidence. Never work past a missing chain.`
    : `This issue has no dependencies inside this wave.`
  const restart = issue.restartNote || ''
  const wt = issue.worktreeMode ? WORKTREE_MODE : ''
  // ROLE IS READ HERE, not assumed to be Dev. meta.description above promises 'same per-issue
  // fields as tranche-runner', and `role` is one of them — it was accepted and silently ignored,
  // so a Refactorer-hat issue placed in a wave was briefed as Dev, pointed at dev.md, and told to
  // stamp its board move [Dev]. Same two lines as tranche-runner's devPrompt, deliberately
  // identical: a promise of 'the same fields' is only true if the same code reads them.
  const role = issue.role || 'Dev'
  const roleDoc = role === 'Refactorer' ? '.claude/roles/refactorer.md' : '.claude/roles/dev.md'
  const workMode = issue.docsPath
    ? `DOCS/PROCESS PATH (the direct-to-trunk lite variant per CLAUDE.md — this issue touches NONE of ${CFG.codePaths}): there is NO work branch. Work directly on a fresh-pulled ${CFG.trunk}; commit each logical change straight to ${CFG.trunk} with a [Dev]-prefixed subject and push. If you find yourself needing to touch a code path, STOP and return blocked — that would be mis-scoped.`
    : `CODE PATH: create branch ${issue.branch} from a fresh ${CFG.remote}/${CFG.trunk} and work there.`
  const resume = fixNotes
    ? `THIS IS A FIX ROUND: QA bounced the issue back to in_progress with these unmet AC / notes — address exactly these${issue.docsPath ? ` (docs path: continue direct on ${CFG.trunk})` : ' on the SAME branch (do not recreate it)'}:\n${fixNotes}`
    : `Fresh pickup: if the issue file is still in progress/todo/, move it todo → in_progress via ./scripts/move-issue.sh ${issue.id} in_progress --role ${role} --note "picked up"; if a stopped earlier attempt already moved it, skip the move. ${workMode}${restart}`
  return `Wear the **${role} hat** per ${roleDoc} for issue ${issue.id} (${issue.title}).
${COMMON}${wt}
${chain}
${resume}
Requirements:
- ${issue.docsPath ? 'Docs work: no TDD cycle — each AC still needs its own evidence pointer (file:line or command + result).' : 'TDD per the test-driven-development skill: failing test first, no exceptions.'}
- ${CFG.gateCmd} green before handoff; paste the observed result line into test_evidence.
- Every AC has a passing test or a documented progress.md justification.
- ${issue.docsPath ? `Ensure all commits are pushed to ${CFG.trunk}. THEN the board move:` : 'Push the work branch. THEN the board move:'} ./scripts/move-issue.sh ${issue.id} dev_complete --role ${role} --note "..." — the dev_complete move IS part of done-ness.
- Append your session summary to progress.md per your role doc.
${issue.extraDev || ''}
Return the structured result only.`
}

// THE ZERO-DRIFT CHECK IS AN UNNUMBERED CONTINUATION OF THE GATES STEP, DELIBERATELY — see the
// same note in tranche-runner.js. A conditional item inside a hand-numbered list makes the list
// skip a number whenever the item is absent.
//
// NOTE A REAL DIVERGENCE THIS DID NOT FIX: this procedure has one FEWER step than tranche's, and
// the missing one is 'Run the gate'. tranche's QA is told to run it; this one is not, while the
// verdict block below still tells the reviewer what to do IF the gate reports a gate that could
// not run. That is a missing instruction, not a numbering artifact, and it is filed separately
// rather than smuggled in with a renumbering.
function qaPrompt(issue) {
  const wt = issue.worktreeMode ? WORKTREE_MODE : ''
  const driftStep = CFG.goldenPaths && !issue.docsPath
    ? `\n   ZERO-DRIFT check (a binding gate for this issue, not a separate step): git diff ${CFG.trunk}...${issue.branch} -- ${CFG.goldenPaths} must show no output changes. REPORT THE PATHS THIS ACTUALLY MATCHED in gate_evidence. If it matched NOTHING, say so loudly and treat the step as NOT RUN — an empty match means this project's pinned output does not live at '${CFG.goldenPaths}', and a diff over nothing reads exactly like a clean diff.`
    : ''
  return `Wear the **QA hat** per .claude/roles/qa.md for issue ${issue.id} (${issue.title}). You are the fresh-eyes reviewer; judge only the AC and the gates.
${COMMON}${wt}
Procedure (the Dev → QA boundary, code-work flavor):
1. Read the issue file in progress/dev_complete/ (its AC is the contract) and the linked PRD story.
2. ${issue.docsPath ? `DOCS PATH: there is NO branch — the work is already committed direct on ${CFG.trunk}. git pull and review the [Dev] commits cited in the issue Activity/handoff.` : `Check out the branch ${issue.branch}${issue.worktreeMode ? ' in YOUR OWN worktree (see WORKTREE MODE)' : ' (git fetch, then git switch)'} and run ${CFG.gateCmd} — anything red that is not pre-existing on ${CFG.trunk} → FAIL outright.`}
3. Walk the AC line by line; record PASS/FAIL per bullet with concrete evidence.
4. Binding cross-cut gates for this issue: ${gatesOf(issue)}. A green suite alone is NOT a PASS where a binding gate applies.${driftStep}
5. Verdict — the four ratified tokens, from process/MANUAL.md § The Dev → QA handoff step 6, which is their one authoring site: PASS · PASS_AC_CORRECTED (the implementation is right and the AC's own illustration was wrong; correct it with the issue) · FAIL_AC · FAIL_REGRESSION. Report the verdict and the landing SEPARATELY — they are two different facts and this schema keeps them apart.
   On a pass (all AC + gates) → ${issue.docsPath ? `close it — ./scripts/move-issue.sh ${issue.id} qa_complete --role QA --note "<verdict summary>", then set landing=not_applicable: a docs path has NOTHING to land, which is a true statement rather than a workaround.` : `land via ./scripts/finish-pr.sh ${issue.id} FROM THE MAIN REPO DIR, then set landing=landed only if that script COMPLETED. If you verified the change but deliberately did not land it — a blocked-push regime, a held trunk — that is landing=deferred, and it is a SUCCESS: report it and do not downgrade the verdict to make it look like one.`}
   Append the progress.md QA line. On a fail → ./scripts/move-issue.sh ${issue.id} in_progress --role QA --note "<unmet AC>" and return FAIL_AC (an AC bullet is unmet) or FAIL_REGRESSION (previously-green behaviour broke). Do NOT fix code yourself.
   If ${CFG.gateCmd} reports a gate that COULD NOT RUN, you have no evidence about the implementation and therefore no verdict to issue: stop and report the precondition failure. Do not spend FAIL_AC or FAIL_REGRESSION on it — both assert something false about the code.
${issue.extraQA || ''}
Return the structured result only.`
}

// PARK-QA BRIEF. Its `landing=not_applicable` sentence carries a superseded conclusion whose reason
// is kept here rather than in the prompt: the sentence used to read "landed is ALWAYS false", a later
// change replaced that boolean with the three-valued `landing` field and updated the schema beside it
// without following the rename into this brief, so the instruction named a field the schema no longer
// defined. The schema moved and the prose did not — the very divergence that change existed to
// prevent, one layer over.
//
// THAT NARRATION USED TO LIVE INSIDE THE RETURNED TEMPLATE LITERAL, and it broke the file: the pair
// of backticks it put around `landing` TERMINATED the literal, so wave-runner.js did not parse at all
// and the wave path was unloadable from the commit that added the narration through the next release.
// Nothing caught it, because nothing in the kit parses these files. Two rules come out of it and both
// belong here: maintainer narration goes in a `//` comment, never in a string that is sent to an
// agent as instructions; and a backtick inside a template literal is a lexical hazard, not a styling
// choice.
function parkPrompt(issue) {
  return `Wear the **QA hat** per .claude/roles/qa.md. Issue ${issue.id} was PARKED by its Dev (status=blocked). Verify THE PARK, not the feature: the issue sits in blocked/ with findings; the findings are evidence-backed and honestly scoped; the tree shows no half-landed residue (clean status, no stray branch); nothing in the park's claims is contradicted by the repo. Do not re-litigate whether parking was right — that is the PM's call. ${COMMON}
Return the structured result only: the ratified verdict for whether the PARK is true, and landing=not_applicable — a park lands nothing, so that is the true value rather than an exception you are being granted.`
}

const results = []
async function runIssue(issue) {
  log(`${issue.id}: Dev starting (${issue.worktreeMode ? 'worktree leg' : 'main-checkout leg'})`)
  let dev = await agent(devPrompt(issue, null), provision(`dev:${issue.id}`, issue.phase, issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
  if (!dev || dev.status !== 'dev_complete') {
    if (issue.parkable && dev && dev.status === 'blocked') {
      const park = await agent(parkPrompt(issue), provision(`park-qa:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, PARK_SCHEMA))
      if (park && isPass(park.verdict)) { log(`${issue.id}: PARKED and verified`); return { id: issue.id, outcome: 'PARKED_OK', dev, park } }
      return { id: issue.id, outcome: 'PARK_UNVERIFIED', dev, park }
    }
    return { id: issue.id, outcome: 'BLOCKED_DEV', dev }
  }
  log(`${issue.id}: QA starting`)
  let qa = await agent(qaPrompt(issue), provision(`qa:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
  // Both FAIL tokens trigger the one bounded fix round. Tested through isPass()
  // rather than against a literal, so a fifth token added at the authoring site
  // cannot silently fall through this branch as neither-pass-nor-fail.
  if (qa && !isPass(qa.verdict)) {
    log(`${issue.id}: QA ${qa.verdict} — one bounded fix round`)
    const notes = `${(qa.unmet_ac || []).join('\n')}\n${qa.notes || ''}`
    dev = await agent(devPrompt(issue, notes), provision(`dev-fix:${issue.id}`, issue.phase, issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
    if (dev && dev.status === 'dev_complete') {
      qa = await agent(qaPrompt(issue), provision(`qa2:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
    }
  }
  // THE HALT KEYS ON THE VERDICT, NEVER ON THE LANDING. A deferred landing is
  // continue-and-defer, not a stop: the review succeeded and said so, and the only
  // question a halt should answer is whether the REVIEW failed.
  //
  // This replaces `(!issue.docsPath && !qa.landed)` and the docsPath carve-out that
  // went with it. That carve-out's reasoning was sound and is preserved by the
  // three-valued field rather than by an exception: a docs-path issue returns
  // `not_applicable` because there is genuinely nothing to land, so it no longer
  // needs a special case to avoid reading as a failure. One less hand-patch, and
  // the next flattening case will not need a third.
  if (!qa || !isPass(qa.verdict)) {
    return { id: issue.id, outcome: 'FAILED_AFTER_FIX_ROUND', dev, qa }
  }
  // A PASS that did NOT land is still a success, and the run continues — but the
  // outcome NAMES it, because "verified and landed" and "verified, landing
  // deferred" are different facts and a report that spells both `LANDED` has
  // re-merged the two axes downstream of the schema that separated them.
  if (qa.landing === 'landed' || qa.landing === 'not_applicable') {
    log(`${issue.id}: LANDED`)
    return { id: issue.id, outcome: 'LANDED', qa_evidence: qa.ac_walk, gates: qa.gate_evidence }
  }
  log(`${issue.id}: LAND-READY (verified; landing deferred)`)
  return { id: issue.id, outcome: 'LAND_READY', qa_evidence: qa.ac_walk, gates: qa.gate_evidence }
}

// THE WAVE SUCCESS PREDICATE HAS ONE AUTHORING SITE. It was written out verbatim once per wave,
// so a third wave meant a third copy — and the outcome vocabulary it keys on is itself carried by
// hand in several places, so a change there would have had to find every copy of this line too.
//
// LAND_READY is a PASS whose landing was deferred, so it does not halt: the halt keys on the
// VERDICT, never on the landing, per the note above runIssue.
const waveOk = rs => rs.every(r => r.outcome === 'LANDED' || r.outcome === 'LAND_READY' || r.outcome === 'PARKED_OK')

// THE WAVES ARE A TABLE, NOT A COPY-PASTED PAIR. Adding a third wave was five hand edits across
// four places (a phase call, a parallel call, a results push, a predicate copy, a halt branch);
// it is now one row here plus its meta.phases entry above — and meta.phases is the one part a
// table cannot supply, because the harness reads it before this code runs.
//
// BOTH PHASES ARE ANNOUNCED EVEN WHEN A WAVE IS EMPTY, which is what the previous shape did and
// is deliberately preserved: meta.phases DECLARES both, and a declared group that never opens
// makes the progress display describe a shape the run did not have.
const WAVES = [
  { phase: 'Wave1', halt: 'wave1', issues: ARGS.wave1 ?? [] },
  { phase: 'Wave2', halt: 'wave2', issues: ARGS.wave2 ?? [] },
]

for (const w of WAVES) {
  phase(w.phase)
  const out = (await parallel(w.issues.map(i => () => runIssue(i)))).filter(Boolean)
  results.push(...out)
  if (!waveOk(out)) return { halted: w.halt, results }
}
return { halted: null, results }
