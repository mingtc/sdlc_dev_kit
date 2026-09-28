// KIT-CLASS: KIT — the serial tranche runner. Everything project-specific is in CFG below.
export const meta = {
  name: 'tranche-runner',
  description: 'Run a minted issue tranche serially: per issue one implementer-hat agent (Dev/Refactorer, code or docs path) then a fresh-eyes QA agent; one bounded fix round on FAIL. EVERY close is reviewed, including a park: a parkable issue that comes back blocked goes through a park-QA leg that verifies the park is TRUE (findings evidence-backed, issue in blocked/, no half-landed residue) — PARKED_OK means "parked AND verified", and a park QA that still FAILS the park after one bounded fix round halts the tranche as PARK_UNVERIFIED. Each leg is explicitly provisioned — per-issue model (devModel/qaModel) and effort (devEffort/qaEffort, never undefined for an untyped leg; the frontmatter pin of a leaf worker type governs what the issue leaves unset) at every call site including the fix round and the second QA pass — and may name a .claude/agents/ leaf worker type via devAgentType/qaAgentType.',
  phases: [
    { title: 'Dev', detail: 'one Dev-hat agent per issue, TDD on a work branch (or direct-to-trunk on the docs path); per-issue devModel + devEffort override', model: 'opus' },
    { title: 'QA', detail: 'separate fresh-eyes QA-hat agent per issue; lands via the landing script; a park takes the same seam as a park-QA leg (the ratified verdict set, landing always not_applicable) instead of closing unreviewed; per-issue qaModel + qaEffort override', model: 'opus' },
  ],
}

// args: { repo, trunk?, remote?, gateCmd?, codePaths?, goldenPaths?, liveRules?, driftRule?,
//         defaultModel?, defaultEffort?,
//         issues: [{id, branch, title, devModel, devEffort, qaModel, qaEffort,
//                   devAgentType?, qaAgentType?, gates?, depends_on?, extraDev?, extraQA?,
//                   role?, docsPath?, parkable?}] }
//
// There is no `slug` field, deliberately: the mover resolves the card path from the id.
//
// `parkable: true` means a Dev status=blocked MAY close the issue, never unreviewed: a park is a
// CLOSE, and every close gets fresh eyes. A park-QA leg verifies the park is TRUE. PASS →
// PARKED_OK; still failing after one bounded fix round → PARK_UNVERIFIED, which halts; no
// verdict → NO_VERDICT, which halts with no fix round.

// The parse is guarded so a non-JSON payload is refused naming this runner, at 0 agents. The
// message names the required top-level keys only; the per-issue shape stays in the args comment.
let ARGS
try {
  ARGS = typeof args === 'string' ? JSON.parse(args) : args
} catch (e) {
  throw new Error(`tranche-runner: args must be a JSON object, not prose. Got: ${String(args).slice(0, 60)}\nExpected: { repo, issues: [{id, branch, ...}] } — the full shape is in the "// args:" comment at the top of this file\nUnderlying parse error: ${e.message}`)
}

// ---------------------------------------------------------------------------
// CFG — the only project-specific values in this file. Override any of them per
// run via args; the defaults are the kit's, not any one project's. Keep them in
// sync with the project adapter (CLAUDE.md), scripts/verify.sh and KWT_REMOTE.
// ---------------------------------------------------------------------------
const CFG = {
  repo:        ARGS.repo,                                  // REQUIRED: absolute path to the repo
  trunk:       ARGS.trunk       || 'main',                  // the single trunk branch
  // Branches are cut from <remote>/<trunk>, never the local trunk, which may be stale.
  // The runners do not read KWT_REMOTE: pass `remote` to match it on a fork.
  remote:      ARGS.remote      || 'origin',                // the remote whose trunk a branch is cut from
  gateCmd:     ARGS.gateCmd     || './scripts/verify.sh',   // the one-shot gate runner
  // The paths that count as CODE (must go through a work branch). Prose, not globs —
  // it is injected into agent prompts. Mirror the adapter's own definition.
  codePaths:   ARGS.codePaths   || 'src/**, tests/**, and the build/dependency manifest',
  // Pinned-output paths a behavior-preserving change must not move. '' skips the zero-drift
  // diff (a project with no goldens should pass ''). `??` NOT `||`: with `||`, '' restores the
  // default. The self-test asserts the `??` in both runners.
  goldenPaths: ARGS.goldenPaths ?? 'tests/fixtures tests/golden*',
  // Optional extra ground rule injected verbatim into every prompt: the project's
  // live/destructive-resource rules. See process/doctrine/live-resources.md.
  liveRules:   ARGS.liveRules   || '',
  // The pin in prose, for a project whose pinned output is DERIVED (a count, a generated
  // manifest) and so has no goldenPaths to name. Prose, not a command: the brief must not tell
  // an agent to execute project-supplied text.
  driftRule:   ARGS.driftRule   || '',
  // Provisioning defaults for an UNTYPED leg (a typed leg takes its .claude/agents/ frontmatter pin):
  // the kit's seed; replace with your ratified ladder (process/doctrine/model-provisioning.md § B.2).
  defaultModel:  ARGS.defaultModel  || 'opus',
  defaultEffort: ARGS.defaultEffort || 'medium',
}
if (!CFG.repo) throw new Error('tranche-runner: args.repo is required (absolute path to the repo)')

// An omitted issue list is refused by name, at 0 agents. A misspelled per-issue key is refused by
// name too: `depends_on` defaults to [], so a typo (`depends_ons`) would otherwise run the issue
// solo.
const ISSUE_KEYS = new Set(['id', 'branch', 'title', 'devModel', 'devEffort', 'qaModel', 'qaEffort',
  'devAgentType', 'qaAgentType', 'gates', 'depends_on', 'extraDev', 'extraQA', 'role', 'docsPath',
  'parkable'])
if (Array.isArray(ARGS.issues)) {
  const strays = []
  for (const it of ARGS.issues) {
    if (!it || typeof it !== 'object') continue
    for (const k of Object.keys(it)) if (!ISSUE_KEYS.has(k)) strays.push(`${it.id || '<no id>'}.${k}`)
  }
  if (strays.length) {
    throw new Error(`tranche-runner: unrecognised per-issue key(s): ${strays.join(', ')}. ` +
      `Known keys: ${[...ISSUE_KEYS].join(', ')}. A misspelled key would otherwise be silently ` +
      `ignored — which for depends_on means a solo run where you declared a dependency.`)
  }
}

if (!Array.isArray(ARGS.issues) || ARGS.issues.length === 0) {
  throw new Error('tranche-runner: args.issues is required and must be a NON-EMPTY array of issue objects. Got: ' + JSON.stringify(ARGS.issues) + '. Expected: { repo, issues: [{id, branch, ...}] }')
}

const DEFAULT_MODEL = CFG.defaultModel
const DEFAULT_EFFORT = CFG.defaultEffort
// An untyped leg's omitted effort MUST resolve to a real value: undefined inherits the session
// default, the biggest burn lever (process/doctrine/model-provisioning.md). The lowest tier and `max`
// are never used here. opts.agentType names a .claude/agents/ leaf worker (`ls .claude/agents/`); its
// frontmatter carries the model/effort/tools contract, so a typed leg sends only the model/effort the
// issue names, as the caller's override — a default sent here would override the pin (§ B.1).
// No agentType ⇒ no key, and behaviour is as if types did not exist.
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

// Own COMMON lines (the rest must match wave-runner.js): 'Repository (' '- Board moves'
const COMMON = `
Repository (work here, absolute path): ${CFG.repo}
Trunk branch: ${CFG.trunk}

HARD CAP — YOU ARE A LEAF WORKER: do NOT spawn subagents, and do not run workflows. Do all of
this work yourself, in this context. Fan-out is the coordinator's decision, never yours.

Ground rules (non-negotiable):
- Read PROJECT.md first, then CLAUDE.md, then your role doc, then the issue file. The issue's AC is the contract.
- QUOTA-LEAN: targeted reads only; NEVER Read an image or a binary file and never screenshot (verify an artifact by hash / size / listing); no full-suite or repeated-build runs beyond the gates named below.
- OUTPUT LENGTH: lead with the outcome; final report <= ~30 lines; commit subjects compact (what+why, no transcripts); Activity and progress.md notes carry evidence POINTERS (file:line, command + its result line), not pasted output.
- No AI co-author trailers in commits. Never commit a secrets file. Role-prefixed commit subjects.
- ZERO-DRIFT discipline unless the issue explicitly consents otherwise: NO change to the project's pinned output. Any golden/snapshot/fixture diff caused by your change is a bug in your change, not a fixture to update.
- Board moves only via ./scripts/move-issue.sh (never move files by hand). The scripts commit+push via the kanban worktree.${CFG.liveRules ? `
- ${CFG.liveRules}` : ''}
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
  FAILED_AFTER_FIX_ROUND: 'FAILED_AFTER_FIX_ROUND',  // QA FAIL, and the fix round brought no PASS (a second FAIL, or the fix Dev did not complete)
  BLOCKED_DEV:            'BLOCKED_DEV',             // Dev could not proceed and the issue is not parkable
  NO_VERDICT:             'NO_VERDICT',              // a QA leg formed no ratified verdict — a precondition failure, NOT a FAIL
  LEG_ABORTED:            'LEG_ABORTED',             // a leg's agent() THREW (budget ceiling, refused call) — state unknown, NOT a FAIL
})
const LANDING = ['landed', 'deferred', 'not_applicable']
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

// PARK_SCHEMA — the park-QA leg's contract. Not QA_SCHEMA: the evidence fields differ. A park
// lands nothing, so `not_applicable` is the true value of `landing`.
const PARK_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    // `verdict` is not required: on a precondition failure (MANUAL step 6) the reviewer sends
    // precondition_failure instead, filed as NO_VERDICT. A separate field keeps VERDICTS at the
    // four ratified tokens.
    precondition_failure: { type: 'string', description: 'OPTIONAL. Set ONLY when no verdict can be formed (MANUAL step 6): a gate that could not run, or an AC naming a gate this tree does not hold. Name it. When set, omit verdict and send landing=not_applicable; the run files it as NO_VERDICT, never as a failure. Otherwise OMIT this field — never an empty string, and never a filler such as "N/A" or "none": ANY non-empty value halts the run.' },
    landing: { enum: LANDING, description: 'ALWAYS not_applicable for a park — nothing is merged and the issue stays in blocked/' },
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
  const role = issue.role || 'Dev'
  const roleDoc = role === 'Refactorer' ? '.claude/roles/refactorer.md' : '.claude/roles/dev.md'
  // Optional fields are defaulted, never assumed: `.length` on an absent `depends_on` throws. The
  // FAIL bullets in the briefs name tokens derived from VERDICTS, never a bare `FAIL`, which the
  // schema rejects.
  const deps = Array.isArray(issue.depends_on) ? issue.depends_on : []
  const chain = deps.length
    ? `DEPENDENCY CHAIN — VERIFY FIRST: this issue depends on ${deps.join(', ')} being LANDED on ${CFG.trunk}. Before any work: git log --oneline --grep to confirm each predecessor's "→ qa_complete" landing commit exists on ${CFG.trunk} AND its issue file sits in progress/qa_complete/ or progress/done/. If any link is missing, STOP immediately: return status=blocked with the evidence. Never work past a missing chain.`
    : `This issue has no dependencies inside the tranche.`
  const workMode = issue.docsPath
    ? `DOCS/PROCESS PATH (the direct-to-trunk lite variant per CLAUDE.md — this issue touches NONE of ${CFG.codePaths}): there is NO work branch. Work directly on a fresh-pulled ${CFG.trunk}; commit each logical change straight to ${CFG.trunk} with a [${role}]-prefixed subject and push. If you find yourself needing to touch a code path, STOP and return blocked — that would be mis-scoped.`
    : `CODE PATH: create branch ${issue.branch} from a fresh ${CFG.remote}/${CFG.trunk} and work there.`
  const resume = fixNotes
    ? `THIS IS A FIX ROUND: QA bounced the issue back to in_progress with these unmet AC / notes — address exactly these${issue.docsPath ? ` (docs path: continue direct on ${CFG.trunk})` : ` on the SAME branch (git switch ${issue.branch}, do not recreate it)`}:\n${fixNotes}`
    : `Fresh pickup: move the issue todo → in_progress via ./scripts/move-issue.sh ${issue.id} in_progress --role ${role} --note "picked up". ${workMode}`
  return `Wear the **${role} hat** per ${roleDoc} for issue ${issue.id} (${issue.title}).
${COMMON}
${chain}
${resume}
Requirements:
- ${issue.docsPath ? 'Docs work: no TDD cycle — each AC still needs its own evidence pointer (file:line or command + result).' : 'TDD per the test-driven-development skill: failing test first, no exceptions.'}
- ${CFG.gateCmd} green before handoff; paste the observed result line into test_evidence.
- Every AC has a passing test, or a documented justification in progress.md for why it cannot be automated. For an AC whose deliverable is prose describing code behaviour, being a description is NOT that justification: each behavioural claim needs a test or a file:line QA can check it against.
- ${issue.docsPath ? `Ensure all commits are pushed to ${CFG.trunk}. THEN the board move:` : 'Push the work branch. THEN the board move:'} ./scripts/move-issue.sh ${issue.id} dev_complete --role ${role} --note "..." — the dev_complete move IS part of done-ness; the issue is not done until the board says so.
- Append your session summary to progress.md per your role doc (a [${role}]-prefixed metadata commit to ${CFG.trunk}; code itself stays on the work branch, committed with the [${role}] prefix).
${issue.extraDev || ''}
Return the structured result only.`
}

// The park-QA brief judges THE PARK, not the parking decision: whether the park is TRUE. Whether
// parking was the right call is the PM's question, never this leg's.
//
// Maintainer notes go in `//` comments, never inside a prompt literal: the agent reads the literal
// as instructions, and a backtick in it ends the literal.
// THE PARK WALK AND ITS VERDICTS, shared with wave-runner.js and held identical by the self-test:
// what makes a park true does not depend on which runner asked.
function parkWalk(issue) {
  return `NOT in scope: whether parking was the right call, or whether the work should be re-planned — that is the PM's decision, and a park you dislike but which is honest is a PASS.
Walk these, each with concrete evidence (file:line, a command + its result line):
1. **Placement** — the issue file sits in progress/blocked/ and its Activity log records the move (./scripts/check-board.sh clean; the move-issue.sh commit exists on ${CFG.trunk}).
2. **Findings** — the write-up's verdict is evidence-backed and honestly scoped: every load-bearing claim is reproducible (re-run the cheap ones yourself), and what is UNMET is stated as unmet rather than smoothed over. A park that overclaims is a FAIL.
3. **Residue** — nothing half-landed: git status clean, no stray branch left behind${issue.docsPath ? '' : ` (${issue.branch} must not exist unmerged unless the write-up says why)`}, no partial edit to a code path that the park does not own.
4. **Contradiction** — nothing the park claims is contradicted by the tree as it stands.
5. **Gates** — ${CFG.gateCmd} green (nothing should have moved), and this issue's binding gates where they apply: ${gatesOf(issue)}.
Verdict:
- **PASS** — the park is true. Leave the issue in blocked/ (do NOT move it, do NOT land anything). Append the progress.md QA line recording the park review. Set landing=not_applicable — a park lands nothing, so that is simply the true value, not an exception you are being granted.
- **NO VERDICT** — a check you must run COULD NOT RUN: set precondition_failure to name it and omit verdict. That is not a FAIL, and the park is not judged.
- **A FAILING VERDICT** — ${VERDICTS.filter(v => v.startsWith('FAIL')).join(' or ')}. The park is not verifiable as written. Move the issue back: ./scripts/move-issue.sh ${issue.id} in_progress --role QA --note "<what makes the park unverifiable>", and return the unmet list. Do NOT fix it yourself, and do NOT re-park it yourself.`
}

function parkPrompt(issue, fixNotes) {
  const round = fixNotes
    ? `THIS IS THE SECOND park-QA pass — the first FAILed and Dev was given one bounded fix round on exactly these findings:\n${fixNotes}\nRe-check them first, then the full walk below.`
    : `This is the first park-QA pass.`
  return `Wear the **QA hat** per .claude/roles/qa.md for issue ${issue.id} (${issue.title}). Dev PARKED this issue: it returned status=blocked and moved the issue to progress/blocked/ with a findings write-up. You are the fresh-eyes reviewer of THE PARK ITSELF.
${COMMON}
${round}
A park is a CLOSE, and every close in this tranche is reviewed. Your question is narrow: **is the park TRUE?**
${parkWalk(issue)}
${issue.extraQA || ''}
Return the structured result only.`
}

// The zero-drift check is an unnumbered continuation of the gates step, deliberately: it is
// conditional, and a conditional item in a hand-numbered list skips a number when absent.
function qaPrompt(issue) {
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
${COMMON}
Procedure (the Dev → QA boundary, code-work flavor):
1. Read the issue file in progress/dev_complete/ (its AC is the contract) and the linked PRD story.
2. ${issue.docsPath ? `DOCS PATH: there is NO branch — the work is already committed direct on ${CFG.trunk}. git pull and review the role-prefixed commits cited in the issue Activity/handoff.` : `git fetch, then git switch ${issue.branch} (from the issue's branch frontmatter).`}
3. Run ${CFG.gateCmd} — anything red that is not pre-existing on ${CFG.trunk} → FAIL outright.
4. Walk the AC line by line; record PASS/FAIL per bullet with concrete evidence (test name, diff, output). An AC whose deliverable is prose describing code behaviour is graded claim by claim: each behavioural claim tied to a falsifier the suite resolves (name the test) or checked by you at a named file:line. A claim you cannot tie to a test or locate at a file:line leaves the bullet unmet — FAIL_AC, naming the claim; "it is a description" does not excuse it (.claude/roles/qa.md step 4).
5. Binding cross-cut gates for this issue: ${gatesOf(issue)}. A green suite alone is NOT a PASS where a binding gate applies.${driftStep}
6. Verdict:
   - The four ratified verdicts, from process/MANUAL.md § The Dev → QA handoff step 6 — their one authoring site: PASS · PASS_AC_CORRECTED (implementation right, the AC's own illustration wrong; correct it with the issue — only when you checked the fact yourself against a citable source; the amendment carries the corrected illustration AND its source) · FAIL_AC · FAIL_REGRESSION. Report the verdict and the landing SEPARATELY: they are two different facts.
   - On a pass (all AC pass w/ evidence, gates green, no Blocker/Critical): ${issue.docsPath ? 'close it — ./scripts/move-issue.sh ' + issue.id + ' qa_complete --role QA --note "<verdict summary>", then set landing=not_applicable: a docs path has NOTHING to land, which is true rather than a workaround.' : 'land it — ./scripts/finish-pr.sh ' + issue.id + ' (squash-merge into ' + CFG.trunk + ', deletes the branch, advances the board). Set landing=landed only if that script COMPLETED. If you verified the change and deliberately did not land it — a blocked-push regime, a held trunk — that is landing=deferred and it is a SUCCESS: report it, and do not downgrade the verdict to make the outcome look consistent.'} Append the progress.md QA line.
   - If ${CFG.gateCmd} reports a gate that COULD NOT RUN — or an AC names a gate this tree does not hold — you have no evidence about the implementation and so no verdict to issue: stop, set precondition_failure to name it, OMIT verdict, and send landing=not_applicable. Neither FAIL token fits — both assert something false about the code.
   - On a fail: ./scripts/move-issue.sh ${issue.id} in_progress --role QA --note "<unmet AC list>" and return the unmet_ac list with whichever FAILING verdict of ${VERDICTS.filter(v => v.startsWith('FAIL')).join(' / ')} fits — an unmet acceptance criterion vs. a previously-green test this broke (at any severity) or uncovered behaviour it broke at Blocker/Critical severity; a Major/Minor break there is filed and does not fail the review. Do NOT fix code yourself.
${issue.extraQA || ''}
Return the structured result only.`
}

const results = []
let halted = null
// Two ways a leg can end with nothing to act on, named — never re-labelled as a verdict or a status
// the leg did not report. Each records the outcome and halts the tranche at this issue.
function devReturnedNothing(issue, label, dev) {
  halted = issue.id
  const error = `${label}:${issue.id}: the Dev leg returned nothing`
  log(`${issue.id}: LEG_ABORTED — ${error}; state unknown, tranche HALTS here`)
  results.push({ id: issue.id, outcome: OUTCOME.LEG_ABORTED, error, dev })
}
function parkReturnedNoVerdict(issue, dev, park) {
  halted = issue.id
  log(`${issue.id}: NO_VERDICT — park review: ${noVerdictWhy(park)}; the park is unreviewed; tranche HALTS here`)
  results.push({ id: issue.id, outcome: OUTCOME.NO_VERDICT, dev, park })
}

for (const issue of ARGS.issues) {
  if (halted) { results.push({ id: issue.id, skipped: true, reason: `tranche halted at ${halted}` }); continue }
  // A throwing leg must not take the run with it: the issue in flight is LEG_ABORTED, the tranche
  // halts, and earlier outcomes are kept. Only a throw leg() marked is caught; the runner's own bug
  // is re-thrown. process/MANUAL.md § The RUN-OUTCOME vocabulary.
  try {

    // No per-issue phase(): provision()'s `phase` argument assigns each agent to a group that
    // meta.phases declares, and a global phase() here would add undeclared ones.
    log(`${issue.id}: Dev round starting`)
    let dev = await leg(devPrompt(issue, null), provision(`dev:${issue.id}`, 'Dev', issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
    if (!devAnswered(dev)) { devReturnedNothing(issue, 'dev', dev); continue }
    if (dev.status !== 'dev_complete') {
      if (!(issue.parkable && dev.status === 'blocked')) {
        halted = issue.id
        results.push({ id: issue.id, outcome: OUTCOME.BLOCKED_DEV, dev })
        continue
      }
      // A park closes the issue ONLY once park-QA has verified it: PARKED_OK is unreachable
      // without a park-QA PASS.
      log(`${issue.id}: Dev PARKED the issue — park-QA round starting (no close without review)`)
      // Park-QA uses the issue's own qaModel/qaEffort/qaAgentType: a park review must not
      // silently escalate or degrade.
      let park = await leg(parkPrompt(issue, null), provision(`park-qa:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, PARK_SCHEMA))
      // Only a ratified FAIL spends the park fix round; no verdict is NO_VERDICT, and halts.
      if (!formedVerdict(park)) { parkReturnedNoVerdict(issue, dev, park); continue }
      if (!isPass(park.verdict)) {
        log(`${issue.id}: park-QA ${park.verdict} — one bounded fix round`)
        const parkNotes = `${(((park && park.unmet) || []).join('\n'))}\n${(park && park.notes) || ''}`
        dev = await leg(devPrompt(issue, parkNotes), provision(`dev-park-fix:${issue.id}`, 'Dev', issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
        if (!devAnswered(dev)) { devReturnedNothing(issue, 'dev-park-fix', dev); continue }
        if (dev.status === 'dev_complete') {
          // The fix round withdrew the park and finished the work — it is no longer a park,
          // so it takes the ordinary QA leg below rather than a second park-QA.
          log(`${issue.id}: park withdrawn by the fix round — falling through to the ordinary QA leg`)
        } else {
          park = await leg(parkPrompt(issue, parkNotes), provision(`park-qa2:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, PARK_SCHEMA))
          if (!formedVerdict(park)) { parkReturnedNoVerdict(issue, dev, park); continue }
        }
      }
      if (dev.status !== 'dev_complete') {
        // The verdict alone decides a park's close; no halt keys on the landing field.
        if (park && isPass(park.verdict)) {
          results.push({ id: issue.id, outcome: OUTCOME.PARKED_OK, dev, park })
          log(`${issue.id}: PARKED and VERIFIED by park-QA (tranche continues)`)
        } else {
          halted = issue.id
          results.push({ id: issue.id, outcome: OUTCOME.PARK_UNVERIFIED, dev, park })
          log(`${issue.id}: PARK_UNVERIFIED — the park could not be verified; tranche HALTS here`)
        }
        continue
      }
    }

    log(`${issue.id}: QA round starting`)
    let qa = await leg(qaPrompt(issue), provision(`qa:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))

    // Only a ratified FAIL spends the fix round (formedVerdict reads VERDICTS, so a new token still
    // reaches here); no verdict is NO_VERDICT, below.
    if (formedVerdict(qa) && !isPass(qa.verdict)) {
      log(`${issue.id}: QA ${qa.verdict} — one bounded fix round`)
      const notes = `${(qa.unmet_ac || []).join('\n')}\n${qa.notes || ''}`
      // Same provisioning as the fresh pickup: a bounce must not silently escalate the model or
      // the effort. There is no third round: a second FAIL calls for a different approach or
      // author (process/doctrine/fix-execution.md § A.5c).
      dev = await leg(devPrompt(issue, notes), provision(`dev-fix:${issue.id}`, 'Dev', issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
      if (!devAnswered(dev)) { devReturnedNothing(issue, 'dev-fix', dev); continue }
      if (dev.status === 'dev_complete') {
        qa = await leg(qaPrompt(issue), provision(`qa2:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
      }
    }

    // The halt keys on the VERDICT, never on the landing: a deferred landing is a success. No
    // verdict is not a FAIL: it is NO_VERDICT (process/MANUAL.md § The RUN-OUTCOME vocabulary), and
    // it halts because the issue is unreviewed.
    if (!formedVerdict(qa)) {
      halted = issue.id
      log(`${issue.id}: NO_VERDICT — ${noVerdictWhy(qa)}; the issue is unreviewed; tranche HALTS here`)
      results.push({ id: issue.id, outcome: OUTCOME.NO_VERDICT, dev, qa })
      continue
    }
    if (!isPass(qa.verdict)) {
      halted = issue.id
      // FAILED, not PARKED: the issue is left in in_progress/.
      results.push({ id: issue.id, outcome: OUTCOME.FAILED_AFTER_FIX_ROUND, dev, qa })
      continue
    }
    // A PASS that did not land is LAND_READY: still a success, and named as such.
    if (qa.landing === 'landed' || qa.landing === 'not_applicable') {
      log(`${issue.id}: LANDED`)
      results.push({ id: issue.id, outcome: OUTCOME.LANDED, qa_evidence: qa.ac_walk, gates: qa.gate_evidence })
    } else {
      log(`${issue.id}: LAND_READY (verified; landing deferred) — tranche continues`)
      results.push({ id: issue.id, outcome: OUTCOME.LAND_READY, qa_evidence: qa.ac_walk, gates: qa.gate_evidence })
    }
  } catch (e) {
    if (!(e && e[LEG_THREW])) throw e   // the runner's own bug: stays loud, never an outcome
    halted = issue.id
    const error = `${e[LEG_THREW]}: ${e.message}`
    log(`${issue.id}: LEG_ABORTED — ${error}; state unknown, tranche HALTS here`)
    results.push({ id: issue.id, outcome: OUTCOME.LEG_ABORTED, error })
  }
}

for (const r of results) if (r.outcome) r.leg_notes = legNotes(r.id)
return { halted, results }
