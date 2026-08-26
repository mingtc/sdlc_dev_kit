// KIT-CLASS: KIT — the two-wave parallel runner. Everything project-specific is in CFG below.
export const meta = {
  name: 'wave-runner',
  description: 'Run two waves of zero-overlap issues in parallel (args: {repo, wave1:[...], wave2:[...]}, same per-issue fields as tranche-runner plus worktreeMode + phase, including docsPath for the direct-to-trunk lite variant). One leg of each pair runs in a self-created worktree so pairs never contend for the main checkout; the board mover and the landing script serialize via the kanban worktree lock. Prompts, schemas, provisioning and the park-QA discipline mirror tranche-runner.js. The price of the parallelism: merge-conflict bounces are possible — assign zero-overlap surfaces per pair and SAY them in extraDev.',
  phases: [
    { title: 'Wave1', detail: 'first parallel pair' },
    { title: 'Wave2', detail: 'second parallel pair' },
  ],
}

// issue.docsPath — same field name and semantics as tranche-runner.js: true for a
// docs/process-lite issue with NO work branch (direct-to-trunk). On the docs path there is
// nothing for the landing script to squash-merge, so a QA PASS carrying the schema-literal
// `landed:false` is CORRECT, not a failure (see the outcome check in runIssue below, and
// PARK_SCHEMA's identical existing distinction for a park's `landed`).

const ARGS = typeof args === 'string' ? JSON.parse(args) : args

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
  goldenPaths: ARGS.goldenPaths || 'tests/fixtures tests/golden*',
  secretsFile: ARGS.secretsFile || '.env',                  // gitignored credentials file, if any
  liveRules:   ARGS.liveRules   || '',
}
if (!CFG.repo) throw new Error('wave-runner: args.repo is required (absolute path to the main repo)')

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
const QA_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: ['PASS', 'FAIL'] },
    landed: { type: 'boolean', description: 'true only if the landing script completed' },
    ac_walk: { type: 'string', description: 'per-AC PASS/FAIL with concrete evidence' },
    unmet_ac: { type: 'array', items: { type: 'string' } },
    gate_evidence: { type: 'string', description: 'gate-runner + binding gate outputs observed' },
    notes: { type: 'string' },
  },
  required: ['verdict', 'landed', 'ac_walk', 'gate_evidence'],
}
const PARK_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: ['PASS', 'FAIL'] },
    landed: { type: 'boolean', description: 'ALWAYS false for a park — never a failure signal' },
    ac_walk: { type: 'string', description: 'the park claims verified/refuted with evidence' },
    unmet_ac: { type: 'array', items: { type: 'string' } },
    gate_evidence: { type: 'string' },
    notes: { type: 'string' },
  },
  required: ['verdict', 'landed', 'ac_walk', 'gate_evidence'],
}

function devPrompt(issue, fixNotes) {
  const chain = issue.depends_on.length
    ? `DEPENDENCY CHAIN — VERIFY FIRST: this issue depends on ${issue.depends_on.join(', ')} being LANDED on ${CFG.trunk}. Before any work: git log --oneline --grep to confirm each predecessor's "→ qa_complete" landing commit exists on ${CFG.trunk} AND its issue file sits in progress/qa_complete/ or progress/done/. If any link is missing, STOP immediately: return status=blocked with the evidence. Never work past a missing chain.`
    : `This issue has no dependencies inside this wave.`
  const restart = issue.restartNote || ''
  const wt = issue.worktreeMode ? WORKTREE_MODE : ''
  const workMode = issue.docsPath
    ? `DOCS/PROCESS PATH (the direct-to-trunk lite variant per CLAUDE.md — this issue touches NONE of ${CFG.codePaths}): there is NO work branch. Work directly on a fresh-pulled ${CFG.trunk}; commit each logical change straight to ${CFG.trunk} with a [Dev]-prefixed subject and push. If you find yourself needing to touch a code path, STOP and return blocked — that would be mis-scoped.`
    : `CODE PATH: create branch ${issue.branch} from a fresh ${CFG.remote}/${CFG.trunk} and work there.`
  const resume = fixNotes
    ? `THIS IS A FIX ROUND: QA bounced the issue back to in_progress with these unmet AC / notes — address exactly these${issue.docsPath ? ` (docs path: continue direct on ${CFG.trunk})` : ' on the SAME branch (do not recreate it)'}:\n${fixNotes}`
    : `Fresh pickup: if the issue file is still in progress/todo/, move it todo → in_progress via ./scripts/move-issue.sh ${issue.id} in_progress --role Dev --note "picked up"; if a stopped earlier attempt already moved it, skip the move. ${workMode}${restart}`
  return `Wear the **Dev hat** per .claude/roles/dev.md for issue ${issue.id} (${issue.title}).
${COMMON}${wt}
${chain}
${resume}
Requirements:
- ${issue.docsPath ? 'Docs work: no TDD cycle — each AC still needs its own evidence pointer (file:line or command + result).' : 'TDD per the test-driven-development skill: failing test first, no exceptions.'}
- ${CFG.gateCmd} green before handoff; paste the observed result line into test_evidence.
- Every AC has a passing test or a documented progress.md justification.
- ${issue.docsPath ? `Ensure all commits are pushed to ${CFG.trunk}. THEN the board move:` : 'Push the work branch. THEN the board move:'} ./scripts/move-issue.sh ${issue.id} dev_complete --role Dev --note "..." — the dev_complete move IS part of done-ness.
- Append your session summary to progress.md per your role doc.
${issue.extraDev || ''}
Return the structured result only.`
}

function qaPrompt(issue) {
  const wt = issue.worktreeMode ? WORKTREE_MODE : ''
  const driftStep = CFG.goldenPaths && !issue.docsPath
    ? `\n5. ZERO-DRIFT check: git diff ${CFG.trunk}...${issue.branch} -- ${CFG.goldenPaths} must show no output changes.`
    : ''
  return `Wear the **QA hat** per .claude/roles/qa.md for issue ${issue.id} (${issue.title}). You are the fresh-eyes reviewer; judge only the AC and the gates.
${COMMON}${wt}
Procedure (the Dev → QA boundary, code-work flavor):
1. Read the issue file in progress/dev_complete/ (its AC is the contract) and the linked PRD story.
2. ${issue.docsPath ? `DOCS PATH: there is NO branch — the work is already committed direct on ${CFG.trunk}. git pull and review the [Dev] commits cited in the issue Activity/handoff.` : `Check out the branch ${issue.branch}${issue.worktreeMode ? ' in YOUR OWN worktree (see WORKTREE MODE)' : ' (git fetch, then git switch)'} and run ${CFG.gateCmd} — anything red that is not pre-existing on ${CFG.trunk} → FAIL outright.`}
3. Walk the AC line by line; record PASS/FAIL per bullet with concrete evidence.
4. Binding cross-cut gates for this issue: ${issue.gates}. A green suite alone is NOT a PASS where a binding gate applies.${driftStep}
6. Verdict: PASS (all AC + gates) → ${issue.docsPath ? `land it — ./scripts/move-issue.sh ${issue.id} qa_complete --role QA --note "<verdict summary>" (docs path: nothing to squash-merge).` : `land via ./scripts/finish-pr.sh ${issue.id} FROM THE MAIN REPO DIR.`} Append the progress.md QA line; ${issue.docsPath ? 'set landed=true — for a docs-path PASS that means "closed via the board move", not "the landing script ran" (there is nothing to squash-merge).' : 'landed=true only if the landing script completed.'} FAIL → ./scripts/move-issue.sh ${issue.id} in_progress --role QA --note "<unmet AC>" and return verdict=FAIL. Do NOT fix code yourself.
${issue.extraQA || ''}
Return the structured result only.`
}

function parkPrompt(issue) {
  return `Wear the **QA hat** per .claude/roles/qa.md. Issue ${issue.id} was PARKED by its Dev (status=blocked). Verify THE PARK, not the feature: the issue sits in blocked/ with findings; the findings are evidence-backed and honestly scoped; the tree shows no half-landed residue (clean status, no stray branch); nothing in the park's claims is contradicted by the repo. Do not re-litigate whether parking was right — that is the PM's call. ${COMMON}
Return the structured result only: verdict PASS if the park is TRUE and clean, FAIL otherwise; landed is ALWAYS false for a park.`
}

const results = []
async function runIssue(issue) {
  log(`${issue.id}: Dev starting (${issue.worktreeMode ? 'worktree leg' : 'main-checkout leg'})`)
  let dev = await agent(devPrompt(issue, null), provision(`dev:${issue.id}`, issue.phase, issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
  if (!dev || dev.status !== 'dev_complete') {
    if (issue.parkable && dev && dev.status === 'blocked') {
      const park = await agent(parkPrompt(issue), provision(`park-qa:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, PARK_SCHEMA))
      if (park && park.verdict === 'PASS') { log(`${issue.id}: PARKED and verified`); return { id: issue.id, outcome: 'PARKED_OK', dev, park } }
      return { id: issue.id, outcome: 'PARK_UNVERIFIED', dev, park }
    }
    return { id: issue.id, outcome: 'BLOCKED_DEV', dev }
  }
  log(`${issue.id}: QA starting`)
  let qa = await agent(qaPrompt(issue), provision(`qa:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
  if (qa && qa.verdict === 'FAIL') {
    log(`${issue.id}: QA FAIL — one bounded fix round`)
    const notes = `${(qa.unmet_ac || []).join('\n')}\n${qa.notes || ''}`
    dev = await agent(devPrompt(issue, notes), provision(`dev-fix:${issue.id}`, issue.phase, issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
    if (dev && dev.status === 'dev_complete') {
      qa = await agent(qaPrompt(issue), provision(`qa2:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
    }
  }
  // `landed` keeps its meaning and is NOT loosened: for a branch-path issue, landed:false on
  // a PASS is still a failure and still halts the wave — the `!qa.landed` check below still
  // fires for it. What changes is that `landed` is not consulted the SAME WAY when there is
  // nothing to land: on the docs path there is no landing script to run, so qaPrompt tells
  // the QA leg to set landed=true meaning "closed via the board move" — but even if a
  // docs-path QA leg still returns the schema-literal landed:false on an honest PASS, that
  // must not read as a failure. It is exactly the distinction PARK_SCHEMA above already draws
  // for a park's `landed` ("ALWAYS false for a park — never a failure signal"). Both wave
  // phases share this one runIssue() call site, so the rule applies to wave1 and wave2 alike.
  if (!qa || qa.verdict !== 'PASS' || (!issue.docsPath && !qa.landed)) {
    return { id: issue.id, outcome: 'FAILED_AFTER_FIX_ROUND', dev, qa }
  }
  log(`${issue.id}: LANDED`)
  return { id: issue.id, outcome: 'LANDED', qa_evidence: qa.ac_walk, gates: qa.gate_evidence }
}

phase('Wave1')
const wave1 = await parallel((ARGS.wave1 || []).map(i => () => runIssue(i)))
results.push(...wave1.filter(Boolean))
const w1ok = wave1.filter(Boolean).every(r => r.outcome === 'LANDED' || r.outcome === 'PARKED_OK')
if (!w1ok) return { halted: 'wave1', results }

phase('Wave2')
const wave2 = await parallel((ARGS.wave2 || []).map(i => () => runIssue(i)))
results.push(...wave2.filter(Boolean))
const w2ok = wave2.filter(Boolean).every(r => r.outcome === 'LANDED' || r.outcome === 'PARKED_OK')
return { halted: w2ok ? null : 'wave2', results }
