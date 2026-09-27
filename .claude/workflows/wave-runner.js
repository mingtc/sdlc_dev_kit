// KIT-CLASS: KIT — the two-wave parallel runner. Everything project-specific is in CFG below.
export const meta = {
  name: 'wave-runner',
  description: 'Run two waves of zero-overlap issues in parallel (args: {repo, wave1:[...], wave2:[...]}, same per-issue fields as tranche-runner plus the wave-only ones (worktreeMode, phase, restartNote), including docsPath for the direct-to-trunk lite variant). One leg of each pair runs in a self-created worktree so pairs never contend for the main checkout; the board mover and the landing script serialize via the kanban worktree lock. Prompts, schemas and provisioning mirror tranche-runner.js; the park-QA discipline mirrors it EXCEPT that a park this runner cannot verify halts the wave immediately, where tranche-runner grants one bounded fix round first — stated because a claim of mirroring is read as total. The price of the parallelism: merge-conflict bounces are possible — assign zero-overlap surfaces per pair and SAY them in extraDev. NOTE that zero file overlap is NOT isolation: HEAD, the current branch of the shared checkout, the index, a gitignored build tree and the next free id are shared and cannot be assigned to an issue; the leaf brief says what a leg must do about that.',
  phases: [
    { title: 'Wave1', detail: 'first parallel pair' },
    { title: 'Wave2', detail: 'second parallel pair' },
  ],
}

// args: { repo, trunk?, remote?, gateCmd?, setupCmd?, codePaths?, goldenPaths?, secretsFile?,
//         liveRules?, driftRule?, defaultModel?, defaultEffort?, wave1: [...], wave2: [...] }
// Each issue takes tranche-runner.js's per-issue fields plus worktreeMode, phase, restartNote.
// The parse error below points at meta.description, which names only the waves; this is the full shape.

// issue.docsPath — as in tranche-runner.js: true for a docs/process-lite issue with no work
// branch (direct-to-trunk). Such an issue reports `landing: not_applicable`.

// The parse is guarded so a non-JSON payload is refused naming this runner, at 0 agents. The
// message names the required top-level keys only; the per-issue shape stays in meta.description.
let ARGS
try {
  ARGS = typeof args === 'string' ? JSON.parse(args) : args
} catch (e) {
  throw new Error(`wave-runner: args must be a JSON object, not prose. Got: ${String(args).slice(0, 60)}\nExpected: { repo, wave1: [...], wave2: [...] } — the full shape is in this file's meta.description and the per-issue fields mirror tranche-runner.js\nUnderlying parse error: ${e.message}`)
}

// ---------------------------------------------------------------------------
// CFG — the only project-specific values in this file. Override any of them per
// run via args; the defaults are the kit's, not any one project's. Keep them in
// sync with the project adapter (CLAUDE.md), scripts/verify.sh and KWT_REMOTE.
// ---------------------------------------------------------------------------
const CFG = {
  repo:        ARGS.repo,                                   // REQUIRED: absolute path to the main repo
  trunk:       ARGS.trunk       || 'main',
  // The runners do not read KWT_REMOTE: pass `remote` to match it on a fork.
  remote:      ARGS.remote      || 'origin',
  gateCmd:     ARGS.gateCmd     || './scripts/verify.sh',
  setupCmd:    ARGS.setupCmd    || './setup.sh',            // worktree bootstrap, if the project has one
  codePaths:   ARGS.codePaths   || 'src/**, tests/**, and the build/dependency manifest',
  // Pinned-output paths a behavior-preserving change must not move. '' skips the zero-drift
  // diff (a project with no goldens should pass ''). `??` NOT `||`: with `||`, '' restores the
  // default. The self-test asserts the `??` in both runners.
  goldenPaths: ARGS.goldenPaths ?? 'tests/fixtures tests/golden*',
  secretsFile: ARGS.secretsFile || '.env',                  // gitignored credentials file, if any
  liveRules:   ARGS.liveRules   || '',
  // The pin in prose, for a project whose pinned output is DERIVED (a count, a generated
  // manifest) and so has no goldenPaths to name. Prose, not a command: the brief must not tell
  // an agent to execute project-supplied text.
  driftRule:   ARGS.driftRule   || '',
  // Provisioning defaults: the kit's seed, matching the .claude/agents/ pins; replace with your
  // ratified ladder (process/doctrine/model-provisioning.md § B.2).
  defaultModel:  ARGS.defaultModel  || 'opus',
  defaultEffort: ARGS.defaultEffort || 'medium',
}
if (!CFG.repo) throw new Error('wave-runner: args.repo is required (absolute path to the main repo)')

// An omitted wave is refused by name: [].every() is vacuously true, so a run over zero issues
// would report success. One wave is legitimate; neither is not.
for (const k of ['wave1', 'wave2']) {
  if (ARGS[k] !== undefined && ARGS[k] !== null && !Array.isArray(ARGS[k])) {
    throw new Error('wave-runner: args.' + k + ' must be an array of issue objects when present. Got: ' + JSON.stringify(ARGS[k]))
  }
}
// A misspelled per-issue key is refused by name: `depends_on` defaults to [], so a typo
// (`depends_ons`) would otherwise run the issue solo. Derive this set from the fields this file
// reads, not from tranche-runner's (this runner also reads worktreeMode, phase, restartNote):
//   grep -oE 'issue\.[a-zA-Z_]+' .claude/workflows/wave-runner.js | sort -u | grep -v '^issue\.sh$'
const ISSUE_KEYS = new Set(['id', 'branch', 'title', 'devModel', 'devEffort', 'qaModel', 'qaEffort',
  'devAgentType', 'qaAgentType', 'gates', 'depends_on', 'extraDev', 'extraQA', 'role', 'docsPath',
  'parkable', 'worktreeMode', 'phase', 'restartNote'])
{
  const strays = []
  for (const w of ['wave1', 'wave2']) {
    for (const it of (ARGS[w] ?? [])) {
      if (!it || typeof it !== 'object') continue
      for (const k of Object.keys(it)) if (!ISSUE_KEYS.has(k)) strays.push(`${w}:${it.id || '<no id>'}.${k}`)
    }
  }
  if (strays.length) {
    throw new Error(`wave-runner: unrecognised per-issue key(s): ${strays.join(', ')}. ` +
      `Known keys: ${[...ISSUE_KEYS].join(', ')}. A misspelled key would otherwise be silently ignored.`)
  }
}

if ((ARGS.wave1 ?? []).length === 0 && (ARGS.wave2 ?? []).length === 0) {
  throw new Error('wave-runner: at least one of args.wave1 / args.wave2 must be a NON-EMPTY array of issue objects — a run over zero issues would otherwise report a clean success. Expected: { repo, wave1: [{id, branch, ...}], wave2: [...] }')
}

const DEFAULT_MODEL = CFG.defaultModel
const DEFAULT_EFFORT = CFG.defaultEffort
// See tranche-runner.js for why an untyped leg's omitted effort must resolve to a real value, and
// why a typed leg sends only what the issue names.
function provision(label, phase, model, effort, agentType, schema) {
  const opts = { label, phase, schema }
  if (agentType) opts.agentType = agentType
  if (model || !agentType) opts.model = model || DEFAULT_MODEL
  if (effort || !agentType) opts.effort = effort || DEFAULT_EFFORT
  return opts
}

// agent() throws for run-level reasons (budget ceiling, refused call): those are LEG_ABORTED. A
// throw from the runner's own code is a bug and must stay loud. leg() marks what it rethrows with
// the leg's label, and the catch sites act only on marked errors.
const LEG_THREW = 'legThrew'
async function leg(prompt, opts) {
  let reply
  try {
    reply = await agent(prompt, opts)
  } catch (e) {
    const err = e instanceof Error ? e : new Error(String(e))
    err[LEG_THREW] = (opts && opts.label) || 'unlabelled leg'
    throw err
  }
  // OUTSIDE the try on purpose: recordLeg is the runner's own code, and a bug in it must fail the
  // run loudly — inside the try it would be marked as a leg throw and filed LEG_ABORTED.
  recordLeg(opts && opts.label, reply)
  return reply
}

// Every record the runner returns carries each leg's free text as `leg_notes`, on EVERY outcome,
// a success included: one entry per leg that replied, in call order, { leg: <label prefix>,
// ...the non-empty LEG_TEXT fields }. process/MANUAL.md § The RUN-OUTCOME vocabulary.
const LEG_TEXT = ['summary', 'deviations', 'notes', 'premise_refuted', 'precondition_failure']
const legTrail = Object.create(null)   // no prototype: an issue id like `constructor` must not collide
function recordLeg(label, reply) {
  if (!label || !reply || typeof reply !== 'object') return
  const at = String(label).indexOf(':')
  if (at < 0) return
  const entry = { leg: String(label).slice(0, at) }
  for (const k of LEG_TEXT) if (typeof reply[k] === 'string' && reply[k].trim() !== '') entry[k] = reply[k]
  if (Object.keys(entry).length > 1) (legTrail[String(label).slice(at + 1)] ||= []).push(entry)
}
const legNotes = id => (legTrail[id] || []).slice()

// Own COMMON lines (the rest must match tranche-runner.js): 'Repository (' '- Board moves' '- A PARALLEL' '- FILE DISJOINTNESS'
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
- A PARALLEL leg is working the same repo on a DIFFERENT issue with ZERO file overlap with yours. If you find yourself needing to edit a file the other leg owns (its issue names its surfaces), STOP and return blocked with the evidence instead of creating a conflict.
- FILE DISJOINTNESS IS NOT ISOLATION, and do not read the line above as if it were. These are SHARED and cannot be assigned to an issue: HEAD · the current branch of the shared checkout · the git index · a gitignored build or cache tree · the next free id in any sequence. A peer can move HEAD, switch the branch under you, stage into the index, write the build tree, or take the id you were about to mint — with zero file overlap the whole time. So: work only in the checkout your brief gives you — a WORKTREE MODE leg never runs git checkout or git switch in the main checkout, which is the other leg's — never git-add a path you do not own, re-read anything you derived from HEAD after any pause, and treat a minted id as taken only once it is committed.${CFG.liveRules ? `
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
// Authoring site: process/MANUAL.md § The Dev → QA handoff, step 6. If these disagree with that
// list, the list wins. The verdict (did the review pass) and `landing` (did the change reach the
// trunk) are separate axes: collapsing them halts runs that succeeded.
const VERDICTS = ['PASS', 'PASS_AC_CORRECTED', 'FAIL_AC', 'FAIL_REGRESSION']

// THE RUN-OUTCOME VOCABULARY: the runner's summary of one issue, composed from the QA verdict and
// `landing` (LANDED and LAND_READY are both PASS). It projects process/MANUAL.md § The RUN-OUTCOME
// vocabulary; the self-test holds each runner to that table and to its twin (no imports; a shared
// child workflow carries data only and was declined, so each keeps its copy). A new member must not encode a verdict the ratified table lacks.
const OUTCOME = Object.freeze({
  LANDED:                 'LANDED',                  // verdict PASS, landing landed / not_applicable
  LAND_READY:             'LAND_READY',              // verdict PASS, landing deferred — a SUCCESS
  PARKED_OK:              'PARKED_OK',               // parked AND the park verified
  PARK_UNVERIFIED:        'PARK_UNVERIFIED',         // parked, park not verifiable as written
  FAILED_AFTER_FIX_ROUND: 'FAILED_AFTER_FIX_ROUND',  // QA failed again after the fix round
  BLOCKED_DEV:            'BLOCKED_DEV',             // Dev could not proceed and the issue is not parkable
  NO_VERDICT:             'NO_VERDICT',              // a QA leg formed no ratified verdict — a precondition failure, NOT a FAIL
  LEG_ABORTED:            'LEG_ABORTED',             // a leg's agent() THREW (budget ceiling, refused call) — state unknown, NOT a FAIL
})
const LANDING = ['landed', 'deferred', 'not_applicable']
// A verdict that means the review passed. PASS_AC_CORRECTED: MANUAL step 6's third verdict.
const isPass = v => v === 'PASS' || v === 'PASS_AC_CORRECTED'
// A verdict at all: one of the ratified tokens. Anything else, or nothing, is no verdict (MANUAL
// step 6's precondition failure): neither pass nor FAIL, for the issue and the park review alike.
const isVerdict = v => VERDICTS.includes(v)
// A verdict FORMED: a ratified token AND no precondition_failure; a token sent beside a reported
// precondition failure is not a verdict. Only a NON-EMPTY string counts: models often fill an
// optional string with "".
const preconditionFailed = r => !!r && typeof r.precondition_failure === 'string' && r.precondition_failure.trim() !== ''
const formedVerdict = r => !!r && !preconditionFailed(r) && isVerdict(r.verdict)
// Why a review leg formed no verdict, for the log and the record.
const noVerdictWhy = r => preconditionFailed(r)
  ? `the reviewer reported a precondition failure (${r.precondition_failure.trim()})`
  : 'the review leg returned no ratified verdict'
// A Dev leg that returned no DEV_SCHEMA status produced nothing, and its tree state is unknown:
// LEG_ABORTED, not BLOCKED_DEV (a status Dev reports).
const devAnswered = d => !!d && DEV_SCHEMA.properties.status.enum.includes(d.status)

const QA_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    // `verdict` is not required: on a precondition failure (MANUAL step 6) the reviewer sends
    // precondition_failure instead, filed as NO_VERDICT. A separate field keeps VERDICTS at the
    // four ratified tokens.
    precondition_failure: { type: 'string', description: 'OPTIONAL. Set ONLY when no verdict can be formed (MANUAL step 6): a gate that could not run, or an AC naming a gate this tree does not hold. Name it. When set, omit verdict and send landing=not_applicable; the run files it as NO_VERDICT, never as a failure. Otherwise OMIT this field — never an empty string, and never a filler such as "N/A" or "none": ANY non-empty value halts the run.' },
    landing: { enum: LANDING, description: 'landed = the landing script completed; deferred = verified but deliberately not landed (blocked-push regime) — a SUCCESS, not a failure; not_applicable = there was nothing to land (docs path)' },
    // A third axis, neither verdict nor landing: the issue's own premise, refuted by what it
    // measured. Omit it when the premise stood; an empty string claims a refutation and names none.
    premise_refuted: { type: 'string', description: 'OPTIONAL. Omit unless the stated premise OF THIS ISSUE was refuted by what this work measured. When present: what the issue assumed, what was measured instead, and where that measurement is recorded. A PASS/landed issue can carry this and it is not a defect — it is the run learning something.' },
    ac_walk: { type: 'string', description: 'per-AC PASS/FAIL with concrete evidence' },
    unmet_ac: { type: 'array', items: { type: 'string' } },
    gate_evidence: { type: 'string', description: 'gate-runner + binding gate outputs observed' },
    notes: { type: 'string' },
  },
  required: ['landing', 'ac_walk', 'gate_evidence'],
}
const PARK_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    // `verdict` is not required: on a precondition failure (MANUAL step 6) the reviewer sends
    // precondition_failure instead, filed as NO_VERDICT. A separate field keeps VERDICTS at the
    // four ratified tokens.
    precondition_failure: { type: 'string', description: 'OPTIONAL. Set ONLY when no verdict can be formed (MANUAL step 6): a gate that could not run, or an AC naming a gate this tree does not hold. Name it. When set, omit verdict and send landing=not_applicable; the run files it as NO_VERDICT, never as a failure. Otherwise OMIT this field — never an empty string, and never a filler such as "N/A" or "none": ANY non-empty value halts the run.' },
    // A park lands nothing, so `not_applicable` is the true value.
    landing: { enum: LANDING, description: 'ALWAYS not_applicable for a park — nothing is merged and the issue stays in blocked/' },
    // `park_walk` / `unmet`, matching tranche-runner.js: a park review is not an AC walk.
    park_walk: { type: 'string', description: 'per-check PASS/FAIL with concrete evidence: issue sits in blocked/; findings/verdict evidence-backed and honestly scoped; no half-landed residue (clean tree, no stray branch, board move committed); no claim contradicted by the tree' },
    unmet: { type: 'array', items: { type: 'string' }, description: 'what makes the park unverifiable — the fix-round brief' },
    gate_evidence: { type: 'string', description: 'gate runner / check-board.sh / git state observed' },
    notes: { type: 'string' },
  },
  required: ['landing', 'park_walk', 'gate_evidence'],
}

// An absent field interpolates as "undefined", which reads as an instruction. Where there is no
// binding gate, say so.
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
  // `role` is read here, as in tranche-runner's devPrompt. It drives the hat, the role doc, the
  // board moves and the docs-path commit prefix.
  const role = issue.role || 'Dev'
  const roleDoc = role === 'Refactorer' ? '.claude/roles/refactorer.md' : '.claude/roles/dev.md'
  const workMode = issue.docsPath
    ? `DOCS/PROCESS PATH (the direct-to-trunk lite variant per CLAUDE.md — this issue touches NONE of ${CFG.codePaths}): there is NO work branch. Work directly on a fresh-pulled ${CFG.trunk}; commit each logical change straight to ${CFG.trunk} with a [${role}]-prefixed subject and push. If you find yourself needing to touch a code path, STOP and return blocked — that would be mis-scoped.`
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
- Every AC has a passing test, or a documented justification in progress.md for why it cannot be automated. For an AC whose deliverable is prose describing code behaviour, being a description is NOT that justification: each behavioural claim needs a test or a file:line QA can check it against.
- ${issue.docsPath ? `Ensure all commits are pushed to ${CFG.trunk}. THEN the board move:` : 'Push the work branch. THEN the board move:'} ./scripts/move-issue.sh ${issue.id} dev_complete --role ${role} --note "..." — the dev_complete move IS part of done-ness.
- Append your session summary to progress.md per your role doc.
${issue.extraDev || ''}
Return the structured result only.`
}

// The zero-drift check is an unnumbered continuation of the gates step, deliberately: it is
// conditional, and a conditional item in a hand-numbered list skips a number when absent.
function qaPrompt(issue) {
  const wt = issue.worktreeMode ? WORKTREE_MODE : ''
  // The path form wins where it applies (golden FILES); driftRule is the fallback for a derived
  // pin. A project may have both.
  const driftStep = issue.docsPath
    ? ''
    : CFG.goldenPaths
      ? `\n   ZERO-DRIFT check (a binding gate for this issue, not a separate step): git diff ${CFG.trunk}...${issue.branch} -- ${CFG.goldenPaths} must show no output changes; byte-drift in pinned output → FAIL. REPORT THE PATHS THIS ACTUALLY MATCHED in gate_evidence. If it matched NOTHING, say so loudly and treat the zero-drift step as NOT RUN — an empty match means this project's pinned output does not live at '${CFG.goldenPaths}', and a diff over nothing reads exactly like a clean diff.`
      : CFG.driftRule
        ? `\n   ZERO-DRIFT check (a binding gate for this issue, not a separate step) — this project's pinned output is DERIVED, not stored, so it is stated in words rather than as paths: ${CFG.driftRule}\n   Check it on BOTH sides of the change and report what you observed, not that you checked.`
        : ''
  return `Wear the **QA hat** per .claude/roles/qa.md for issue ${issue.id} (${issue.title}). You are the fresh-eyes reviewer; judge only the AC and the gates.
${COMMON}${wt}
Procedure (the Dev → QA boundary, code-work flavor):
1. Read the issue file in progress/dev_complete/ (its AC is the contract) and the linked PRD story.
2. ${issue.docsPath ? `DOCS PATH: there is NO branch — the work is already committed direct on ${CFG.trunk}. git pull and review the role-prefixed commits cited in the issue Activity/handoff.` : `Check out the branch ${issue.branch}${issue.worktreeMode ? ' in YOUR OWN worktree (see WORKTREE MODE)' : ' (git fetch, then git switch)'}.`}
3. Run ${CFG.gateCmd} — anything red that is not pre-existing on ${CFG.trunk} → FAIL outright. This step is UNCONDITIONAL: a docs-path issue has no branch, and it still has a gate.
4. Walk the AC line by line; record PASS/FAIL per bullet with concrete evidence. An AC whose deliverable is prose describing code behaviour is graded claim by claim: each behavioural claim tied to a falsifier the suite resolves (name the test) or checked by you at a named file:line. A claim you cannot tie to a test or locate at a file:line leaves the bullet unmet — FAIL_AC, naming the claim; "it is a description" does not excuse it (.claude/roles/qa.md step 4).
5. Binding cross-cut gates for this issue: ${gatesOf(issue)}. A green suite alone is NOT a PASS where a binding gate applies.${driftStep}
6. Verdict — the four ratified tokens, from process/MANUAL.md § The Dev → QA handoff step 6, which is their one authoring site: PASS · PASS_AC_CORRECTED (the implementation is right and the AC's own illustration was wrong; correct it with the issue — only when you checked the fact yourself against a citable source; the amendment carries the corrected illustration AND its source) · FAIL_AC · FAIL_REGRESSION. Report the verdict and the landing SEPARATELY — they are two different facts and this schema keeps them apart.
   On a pass (all AC + gates) → ${issue.docsPath ? `close it — ./scripts/move-issue.sh ${issue.id} qa_complete --role QA --note "<verdict summary>", then set landing=not_applicable: a docs path has NOTHING to land, which is a true statement rather than a workaround.` : `land via ./scripts/finish-pr.sh ${issue.id} FROM THE MAIN REPO DIR, then set landing=landed only if that script COMPLETED. If you verified the change but deliberately did not land it — a blocked-push regime, a held trunk — that is landing=deferred, and it is a SUCCESS: report it and do not downgrade the verdict to make it look like one.`}
   Append the progress.md QA line. On a fail → ./scripts/move-issue.sh ${issue.id} in_progress --role QA --note "<unmet AC>" and return FAIL_AC (an AC bullet is unmet) or FAIL_REGRESSION (previously-green behaviour broke). Do NOT fix code yourself.
   If ${CFG.gateCmd} reports a gate that COULD NOT RUN — or an AC names a gate this tree does not hold — you have no evidence about the implementation and therefore no verdict to issue: stop, set precondition_failure to name it, OMIT verdict, and send landing=not_applicable. Do not spend FAIL_AC or FAIL_REGRESSION on it — both assert something false about the code.
${issue.extraQA || ''}
Return the structured result only.`
}

// QA's gate step is unconditional, as in tranche-runner: a docs-path issue has no branch and still
// has a gate. A difference between the twins' briefs needs its reason written beside it.
//
// Maintainer notes go in `//` comments, never inside a prompt literal: the agent reads the literal
// as instructions, and a backtick in it ends the literal.
function parkPrompt(issue) {
  return `Wear the **QA hat** per .claude/roles/qa.md. Issue ${issue.id} was PARKED by its Dev (status=blocked). Verify THE PARK, not the feature: the issue sits in blocked/ with findings; the findings are evidence-backed and honestly scoped; the tree shows no half-landed residue (clean status, no stray branch); nothing in the park's claims is contradicted by the repo. Do not re-litigate whether parking was right — that is the PM's call. ${COMMON}
If a check you must run COULD NOT RUN, there is no verdict to give: set precondition_failure to name it and omit verdict.
Return the structured result only: the ratified verdict for whether the PARK is true, and landing=not_applicable — a park lands nothing, so that is the true value rather than an exception you are being granted.`
}

const results = []
// A Dev leg that returned nothing: named, never re-labelled as a status Dev did not report.
function devReturnedNothing(issue, label, dev) {
  const error = `${label}:${issue.id}: the Dev leg returned nothing`
  log(`${issue.id}: LEG_ABORTED — ${error}; state unknown, the wave HALTS`)
  return { id: issue.id, outcome: OUTCOME.LEG_ABORTED, error, dev }
}
async function runIssue(issue) {
  log(`${issue.id}: Dev starting (${issue.worktreeMode ? 'worktree leg' : 'main-checkout leg'})`)
  let dev = await leg(devPrompt(issue, null), provision(`dev:${issue.id}`, issue.phase, issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
  if (!devAnswered(dev)) return devReturnedNothing(issue, 'dev', dev)
  if (dev.status !== 'dev_complete') {
    if (issue.parkable && dev.status === 'blocked') {
      const park = await leg(parkPrompt(issue), provision(`park-qa:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, PARK_SCHEMA))
      if (!formedVerdict(park)) {
        log(`${issue.id}: NO_VERDICT — park review: ${noVerdictWhy(park)}; the park is unreviewed`)
        return { id: issue.id, outcome: OUTCOME.NO_VERDICT, dev, park }
      }
      if (isPass(park.verdict)) { log(`${issue.id}: PARKED and verified`); return { id: issue.id, outcome: OUTCOME.PARKED_OK, dev, park } }
      return { id: issue.id, outcome: OUTCOME.PARK_UNVERIFIED, dev, park }
    }
    return { id: issue.id, outcome: OUTCOME.BLOCKED_DEV, dev }
  }
  log(`${issue.id}: QA starting`)
  let qa = await leg(qaPrompt(issue), provision(`qa:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
  // Only a ratified FAIL spends the one bounded fix round (formedVerdict reads VERDICTS, so a new
  // token still reaches here); no verdict is NO_VERDICT, below. There is no third round: a second
  // FAIL calls for a different approach or author (process/doctrine/fix-execution.md § A.5c).
  if (formedVerdict(qa) && !isPass(qa.verdict)) {
    log(`${issue.id}: QA ${qa.verdict} — one bounded fix round`)
    const notes = `${(qa.unmet_ac || []).join('\n')}\n${qa.notes || ''}`
    dev = await leg(devPrompt(issue, notes), provision(`dev-fix:${issue.id}`, issue.phase, issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
    if (!devAnswered(dev)) return devReturnedNothing(issue, 'dev-fix', dev)
    if (dev.status === 'dev_complete') {
      qa = await leg(qaPrompt(issue), provision(`qa2:${issue.id}`, issue.phase, issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
    }
  }
  // The halt keys on the VERDICT, never on the landing: a deferred landing is a success. No
  // verdict is not a FAIL: it is NO_VERDICT (process/MANUAL.md § The RUN-OUTCOME vocabulary), and
  // it halts because the issue is unreviewed.
  if (!formedVerdict(qa)) {
    log(`${issue.id}: NO_VERDICT — ${noVerdictWhy(qa)}; the issue is unreviewed`)
    return { id: issue.id, outcome: OUTCOME.NO_VERDICT, dev, qa }
  }
  if (!isPass(qa.verdict)) {
    return { id: issue.id, outcome: OUTCOME.FAILED_AFTER_FIX_ROUND, dev, qa }
  }
  // A PASS that did not land is LAND_READY: still a success, and named as such.
  if (qa.landing === 'landed' || qa.landing === 'not_applicable') {
    log(`${issue.id}: LANDED`)
    return { id: issue.id, outcome: OUTCOME.LANDED, qa_evidence: qa.ac_walk, gates: qa.gate_evidence }
  }
  log(`${issue.id}: LAND-READY (verified; landing deferred)`)
  return { id: issue.id, outcome: OUTCOME.LAND_READY, qa_evidence: qa.ac_walk, gates: qa.gate_evidence }
}

// The wave success predicate, in one place. LAND_READY does not halt (the halt keys on the
// verdict). One outcome per dispatched issue, or the wave is not ok: every() is true of [].
const waveOk = (rs, dispatched) => rs.length === dispatched && rs.every(r => r.outcome === OUTCOME.LANDED || r.outcome === OUTCOME.LAND_READY || r.outcome === OUTCOME.PARKED_OK)

// The waves are a table: a new wave is one row here plus its meta.phases entry (the harness reads
// meta.phases before this code runs). Both phases are announced even when a wave is empty, because
// meta.phases declares both.
const WAVES = [
  { phase: 'Wave1', halt: 'wave1', issues: ARGS.wave1 ?? [] },
  { phase: 'Wave2', halt: 'wave2', issues: ARGS.wave2 ?? [] },
]

for (const w of WAVES) {
  phase(w.phase)
  // NEVER DROP AN ISSUE. parallel() resolves a thunk whose agent() threw to null, and dropping the
  // nulls would let the wave pass over unfinished work. A throw leg() marked is LEG_ABORTED, a stray
  // null is named the same way, and an unmarked throw (the runner's own bug) is re-thrown.
  const out = (await parallel(w.issues.map(i => () => runIssue(i).catch(e =>
    (e && e[LEG_THREW])
      ? { id: i.id, outcome: OUTCOME.LEG_ABORTED, error: `${e[LEG_THREW]}: ${e.message}` }
      : { id: i.id, runnerBug: e }))))
    .map((r, k) => r || { id: w.issues[k].id, outcome: OUTCOME.LEG_ABORTED, error: 'the leg resolved to null' })
  const bug = out.find(r => r.runnerBug)
  if (bug) throw bug.runnerBug
  for (const r of out) if (r.outcome === OUTCOME.LEG_ABORTED) log(`${r.id}: LEG_ABORTED — ${r.error}; state unknown, the wave HALTS`)
  for (const r of out) r.leg_notes = legNotes(r.id)
  results.push(...out)
  if (!waveOk(out, w.issues.length)) return { halted: w.halt, results }
}
return { halted: null, results }
