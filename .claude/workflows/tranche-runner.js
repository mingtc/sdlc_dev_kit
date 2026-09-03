// KIT-CLASS: KIT — the serial tranche runner. Everything project-specific is in CFG below.
export const meta = {
  name: 'tranche-runner',
  description: 'Run a minted issue tranche serially: per issue one implementer-hat agent (Dev/Refactorer, code or docs path) then a fresh-eyes QA agent; one bounded fix round on FAIL. EVERY close is reviewed, including a park: a parkable issue that comes back blocked goes through a park-QA leg that verifies the park is TRUE (findings evidence-backed, issue in blocked/, no half-landed residue) — PARKED_OK means "parked AND verified", and a park QA that cannot verify halts the tranche as PARK_UNVERIFIED. Each leg is explicitly provisioned — per-issue model (devModel/qaModel) and effort (devEffort/qaEffort, never undefined) at every call site including the fix round and the second QA pass — and may name a .claude/agents/ leaf worker type via devAgentType/qaAgentType.',
  phases: [
    { title: 'Dev', detail: 'one Dev-hat agent per issue, TDD on a work branch (or direct-to-trunk on the docs path); per-issue devModel + devEffort override', model: 'opus' },
    { title: 'QA', detail: 'separate fresh-eyes QA-hat agent per issue; lands via the landing script; a park takes the same seam as a park-QA leg (the ratified verdict set, landing always not_applicable) instead of closing unreviewed; per-issue qaModel + qaEffort override', model: 'opus' },
  ],
}

// args: { repo, trunk?, remote?, gateCmd?, codePaths?, goldenPaths?, liveRules?,
//         issues: [{id, branch, title, devModel, devEffort, qaModel, qaEffort,
//                   devAgentType?, qaAgentType?, gates?, depends_on?, extraDev?, extraQA?,
//                   role?, docsPath?, parkable?}] }
//
// THE `?` IS ON THE PER-ISSUE KEYS TOO, AND THAT IS THE FIX FOR A REAL DISPATCH LOSS. This list
// carried no optionality marks at all while the top-level keys above carried `?`, and it showed
// `depends_on: []` — which reads as "here is the shape and its default", not "required". A caller
// omitted it on four of five issues and the run died in 33ms on `issue.depends_on.length`, before
// any agent started. The documentation was the half that caused it (reported by an adopter who lost a five-issue dispatch to it).
//
// THERE IS NO `slug` FIELD, AND THAT IS DELIBERATE — do not re-add one. It was documented here
// and echoed in two refusal messages while NOTHING in either runner read it, so a caller was
// asked for a value that could not affect the run. It has no use to invent, either: every board
// operation this file emits goes through `./scripts/move-issue.sh <id>`, which takes the id and
// resolves the card path itself. The mover owning that lookup is exactly why the runner does not
// need the other half of the filename.
//
// `parkable: true` means a Dev status=blocked MAY close this issue — it does NOT mean it
// closes unreviewed. The park then takes a park-QA leg (PARK_SCHEMA, the same provision()
// seam and the issue's own qaModel/qaEffort/qaAgentType) that verifies the park is TRUE; only
// a park-QA PASS records PARKED_OK, and a park still unverified after one bounded fix round
// records PARK_UNVERIFIED and HALTS the tranche.
//   WHY this exists (keep the reason, it cost a tranche to learn): an unreviewed park was
//   treated as a clean close, and its findings turned out to be wrong — while four
//   downstream issues had already been gated on them. A park is a CLOSE, and every close in
//   a tranche gets fresh eyes.
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
  throw new Error(`tranche-runner: args must be a JSON object, not prose. Got: ${String(args).slice(0, 60)}\nExpected: { repo, issues: [{id, branch, ...}] } — the full shape is in the "// args:" comment at the top of this file\nUnderlying parse error: ${e.message}`)
}

// ---------------------------------------------------------------------------
// CFG — the only project-specific values in this file. Override any of them per
// run via args; the defaults are the kit's, not any one project's. Keep them in
// sync with scripts/config.sh and the project adapter (CLAUDE.md).
// ---------------------------------------------------------------------------
const CFG = {
  repo:        ARGS.repo,                                  // REQUIRED: absolute path to the repo
  trunk:       ARGS.trunk       || 'main',                  // the single trunk branch
  // THE BRANCH BASE IS THE REMOTE'S TRUNK, NOT THE LOCAL ONE, and that is the whole reason this
  // key exists. The Dev brief used to say 'create branch <b> from a fresh <trunk>' — the LOCAL
  // ref — while wave-runner's identical instruction said '<remote>/<trunk>'. One instruction, two
  // bases, and nothing in this file tells Dev to pull first, so 'fresh' meant 'as stale as this
  // checkout happens to be'. In a tranche that lands issues to the trunk as it runs, that is the
  // second issue branching off a trunk missing the first.
  remote:      ARGS.remote      || 'origin',                // the remote whose trunk a branch is cut from
  gateCmd:     ARGS.gateCmd     || './scripts/verify.sh',   // the one-shot gate runner
  // The paths that count as CODE (must go through a work branch). Prose, not globs —
  // it is injected into agent prompts. Mirror the adapter's own definition.
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
  // Optional extra ground rule injected verbatim into every prompt: the project's
  // live/destructive-resource rules. See process/doctrine/live-resources.md.
  liveRules:   ARGS.liveRules   || '',
  // THE PIN, IN PROSE, for a project whose pinned output is DERIVED rather than stored.
  // goldenPaths above expresses the pin as a PATH SHAPE, which presumes a golden-FILE
  // convention: bytes on disk, drift is a git diff. A project whose pinned output is
  // computed — a derived count, a generated manifest, a checksum of something assembled at
  // build time — has nothing to name there, gets an empty goldenPaths, and the drift step
  // correctly reports NOT RUN on every run forever. Correct, and useless.
  //
  // WHY PROSE AND NOT A COMMAND. A command pin would be more expressive, and it would make
  // this brief tell an agent to execute project-supplied text — a posture the kit should
  // adopt deliberately if ever, not inherit from a convenience. And these files can run
  // NOTHING themselves: the workflow runtime grants them no filesystem and no process
  // access, so anything executable would have to be executed by the agent anyway. Prose
  // injected verbatim is the shape liveRules already uses; it is weaker, and it is honest
  // about being weaker.
  driftRule:   ARGS.driftRule   || '',
}
if (!CFG.repo) throw new Error('tranche-runner: args.repo is required (absolute path to the repo)')

// AN OMITTED ISSUE LIST IS A NAMED REFUSAL — same shape as the line above and as the guarded
// parse above that: the reader gets the field name and what it should hold. Without this the
// loop below threw JS's own words, `ARGS.issues is not iterable`, which names neither the
// runner nor the field and reads like a bug in the tool rather than a malformed call.
// Checked HERE rather than at the loop so the run dies at 0 agents, which is this file's posture.
// AND A TYPO IN A PER-ISSUE KEY IS LOUD, because defaulting it silently would be worse than the
// crash it replaced. `depends_on` now defaults to [] where it is read — but a caller who MEANT to
// declare a dependency and wrote `depends_ons` would then get a silent solo run, and a broken
// dependency chain is exactly what that field exists to prevent. A bare default converts an
// immediate, self-naming failure into the reassuring kind. So: honest omission is fine, an
// unrecognised key is refused by name, before any agent starts (reported by an adopter who lost a five-issue dispatch to it).
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

const DEFAULT_MODEL = 'opus'
const DEFAULT_EFFORT = 'medium'
// Provisioning defaults come from the project's ratified ladder
// (process/doctrine/model-provisioning.md). An omitted effort MUST resolve to a real value —
// passing undefined silently inherits the session default, which is the single biggest burn
// lever in the whole system. The lowest tier and `max` are never used here.
//
// opts.agentType names a .claude/agents/ leaf worker definition (dev-worker, qa-worker,
// pm-mint, refactorer-worker, spike-worker, cleanup-worker). Its own frontmatter carries the
// model/effort/tools contract — including a tools list with no spawn tool — so when a type is
// named it is passed through and the explicit model/effort below act as the caller's override.
// Omitted ⇒ the key is absent and behaviour is exactly as if this file never knew about types.
function provision(label, phase, model, effort, agentType, schema) {
  const opts = { label, phase, model: model || DEFAULT_MODEL, effort: effort || DEFAULT_EFFORT, schema }
  if (agentType) opts.agentType = agentType
  return opts
}

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
// Authoring site: `process/MANUAL.md` § The Dev → QA handoff, step 6. If these
// constants disagree with that list, the list wins and these are the defect.
//
// WHY. These schemas used to read `verdict: PASS|FAIL` plus `landed: boolean` —
// two members against the four MANUAL ratifies, and a boolean where the ratified
// vocabulary has three states. A reviewer returning the ratified "pass, every gate
// green, landing deferred" had nowhere to put it, and the halt below read the
// flattened value as a failure and STOPPED A RUN THAT HAD SUCCEEDED. The check was
// correct about what it was given; the vocabulary it was given was too small. That
// is `process/doctrine/instruments.md` § A.9 — a read-time defect, not a misaimed
// guard.
const VERDICTS = ['PASS', 'PASS_AC_CORRECTED', 'FAIL_AC', 'FAIL_REGRESSION']

// THE RUN-OUTCOME VOCABULARY, ONE AUTHORING SITE PER RUNNER. These six tokens were bare string
// literals at six `return { outcome: '…' }` sites in each runner — twelve copies across the pair,
// held together by nothing. VERDICTS above has a named declaration AND a harness case pinning it to
// the ratified table in process/MANUAL.md; this vocabulary had neither.
//
// WHAT IT IS: the RUNNER's summary of one issue's leg, composed from the QA verdict and the
// separate `landing` field rather than replacing either. LANDED and LAND_READY are both verdict
// PASS — they differ only in whether the landing happened — which is why the wave gate treats both
// as success. Keep that composition in mind before adding a member: a new outcome that encodes a
// verdict the ratified table does not have is a second verdict vocabulary wearing another name.
//
// RATIFIED IN process/MANUAL.md § The RUN-OUTCOME vocabulary, which is the AUTHORING SITE: this
// declaration PROJECTS that table and does not re-enumerate it. The copies here are unavoidable —
// the workflow runtime grants these files no imports, so a shared module cannot exist — so the
// self-test holds each runner to the ratified table AND to its twin. Both arms are needed: an
// authority does not make two hand-copied projections agree with each other, and two projections
// agreeing does not make either right.
const OUTCOME = Object.freeze({
  LANDED:                 'LANDED',                  // verdict PASS, landing landed / not_applicable
  LAND_READY:             'LAND_READY',              // verdict PASS, landing deferred — a SUCCESS
  PARKED_OK:              'PARKED_OK',               // parked AND the park verified
  PARK_UNVERIFIED:        'PARK_UNVERIFIED',         // parked, park not verifiable as written
  FAILED_AFTER_FIX_ROUND: 'FAILED_AFTER_FIX_ROUND',  // QA failed again after the fix round
  BLOCKED_DEV:            'BLOCKED_DEV',             // Dev could not proceed and the issue is not parkable
})
const LANDING = ['landed', 'deferred', 'not_applicable']
const isPass = v => v === 'PASS' || v === 'PASS_AC_CORRECTED'

const QA_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    landing: { enum: LANDING, description: 'landed = the landing script completed; deferred = verified but deliberately not landed (blocked-push regime) — a SUCCESS, not a failure; not_applicable = there was nothing to land (docs path)' },
    // A THIRD AXIS, orthogonal to both above, and nullable BY DESIGN. An issue can be
    // implemented exactly as written, land green, and have its own PREMISE refuted by the
    // measurement it produced — the most valuable thing a run can produce, and until this
    // field existed it had nowhere to go but a commit subject. It is NOT a verdict (the
    // work was correct) and NOT a landing (it landed); making it either would re-merge the
    // split process/MANUAL.md § Dev → QA step 6 made on purpose. Leave it absent when the
    // premise stood — an empty string is a claim that something was refuted and named nothing.
    premise_refuted: { type: 'string', description: 'OPTIONAL. Omit unless the stated premise OF THIS ISSUE was refuted by what this work measured. When present: what the issue assumed, what was measured instead, and where that measurement is recorded. A PASS/landed issue can carry this and it is not a defect — it is the run learning something.' },
    ac_walk: { type: 'string', description: 'per-AC PASS/FAIL with concrete evidence' },
    unmet_ac: { type: 'array', items: { type: 'string' } },
    gate_evidence: { type: 'string', description: 'gate-runner + binding gate outputs observed' },
    notes: { type: 'string' },
  },
  required: ['verdict', 'landing', 'ac_walk', 'gate_evidence'],
}

// PARK_SCHEMA — the park-QA leg's contract. Still deliberately NOT QA_SCHEMA (the
// evidence fields differ), but it no longer needs a hand-written exemption for the
// landing field. The old note read "ALWAYS false for a park — false is the CORRECT
// value here and is never a failure signal"; that reasoning was right and is now
// carried by the VALUE rather than by a carve-out: a park lands nothing, so
// `not_applicable` is simply true. An exemption retired by making the vocabulary
// able to say the thing it was exempting.
const PARK_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { enum: VERDICTS },
    landing: { enum: LANDING, description: 'ALWAYS not_applicable for a park — nothing is merged and the issue stays in blocked/' },
    park_walk: { type: 'string', description: 'per-check PASS/FAIL with concrete evidence: issue sits in blocked/; findings/verdict evidence-backed and honestly scoped; no half-landed residue (clean tree, no stray branch, board move committed); no claim contradicted by the tree' },
    unmet: { type: 'array', items: { type: 'string' }, description: 'what makes the park unverifiable — the fix-round brief' },
    gate_evidence: { type: 'string', description: 'gate runner / check-board.sh / git state observed' },
    notes: { type: 'string' },
  },
  // `landing`, not `landed`: an earlier rename changed this field in the properties above
  // and did not follow it into `required` here, so the schema demanded a property it
  // no longer defines — the validator would have asked every park leg for a field the
  // brief never mentions. Wave's two `required` arrays were updated; this one was missed.
  required: ['verdict', 'landing', 'park_walk', 'gate_evidence'],
}

// A brief that interpolates an absent field prints the literal string "undefined" as
// if it were an instruction. Where there is no binding gate, SAY there is none — an
// agent reading "binding gates: undefined" cannot tell a missing field from a real one.
function gatesOf(issue) {
  return issue.gates ? String(issue.gates) : 'none declared for this issue — the suite alone is the bar here'
}

function devPrompt(issue, fixNotes) {
  const role = issue.role || 'Dev'
  const roleDoc = role === 'Refactorer' ? '.claude/roles/refactorer.md' : '.claude/roles/dev.md'
  // OPTIONAL FIELDS ARE DEFAULTED, NEVER ASSUMED. `depends_on` is documented optional
  // in the args comment above, and `.length` on an absent one throws — which kills the
  // whole run at the first issue that omits it, before any work happens.
  // THE FAIL BULLETS IN BOTH BRIEFS BELOW NAME THE ENUM, NEVER A BARE `FAIL`. Both were
  // labelled with one, which the StructuredOutput schema rejects, so a QA leg that failed an
  // issue errored instead of reporting the failure. Derived from VERDICTS so the two cannot part.
  // The reason lives HERE and not in the brief: a prompt literal is shipped to an agent as
  // instructions, and maintainer changelog narration inside one is text the agent must read and
  // discard. Caught by a fresh-context checker that rendered the brief with a stub harness.
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
- Every AC has a passing test or a documented progress.md justification.
- ${issue.docsPath ? `Ensure all commits are pushed to ${CFG.trunk}. THEN the board move:` : 'Push the work branch. THEN the board move:'} ./scripts/move-issue.sh ${issue.id} dev_complete --role ${role} --note "..." — the dev_complete move IS part of done-ness; the issue is not done until the board says so.
- Append your session summary to progress.md per your role doc (a [${role}]-prefixed metadata commit to ${CFG.trunk}; code itself stays on the work branch, committed with the [${role}] prefix).
${issue.extraDev || ''}
Return the structured result only.`
}

// The park-QA brief. It judges THE PARK, not the parking decision: whether the park is TRUE.
// Whether parking was the right call is the PM's question, never this leg's.
function parkPrompt(issue, fixNotes) {
  const round = fixNotes
    ? `THIS IS THE SECOND park-QA pass — the first FAILed and Dev was given one bounded fix round on exactly these findings:\n${fixNotes}\nRe-check them first, then the full walk below.`
    : `This is the first park-QA pass.`
  return `Wear the **QA hat** per .claude/roles/qa.md for issue ${issue.id} (${issue.title}). Dev PARKED this issue: it returned status=blocked and moved the issue to progress/blocked/ with a findings write-up. You are the fresh-eyes reviewer of THE PARK ITSELF.
${COMMON}
${round}
A park is a CLOSE, and every close in this tranche is reviewed. Your question is narrow: **is the park TRUE?**
NOT in scope: whether parking was the right call, or whether the work should be re-planned — that is the PM's decision, and a park you dislike but which is honest is a PASS.
Walk these, each with concrete evidence (file:line, a command + its result line):
1. **Placement** — the issue file sits in progress/blocked/ and its Activity log records the move (./scripts/check-board.sh clean; the move-issue.sh commit exists on ${CFG.trunk}).
2. **Findings** — the write-up's verdict is evidence-backed and honestly scoped: every load-bearing claim is reproducible (re-run the cheap ones yourself), and what is UNMET is stated as unmet rather than smoothed over. A park that overclaims is a FAIL.
3. **Residue** — nothing half-landed: git status clean, no stray branch left behind${issue.docsPath ? '' : ` (${issue.branch} must not exist unmerged unless the write-up says why)`}, no partial edit to a code path that the park does not own.
4. **Contradiction** — nothing the park claims is contradicted by the tree as it stands.
5. **Gates** — ${CFG.gateCmd} green (nothing should have moved), and this issue's binding gates where they apply: ${gatesOf(issue)}.
Verdict:
- **PASS** — the park is true. Leave the issue in blocked/ (do NOT move it, do NOT land anything). Append the progress.md QA line recording the park review. Set landing=not_applicable — a park lands nothing, so that is simply the true value, not an exception you are being granted.
- **A FAILING VERDICT** — ${VERDICTS.filter(v => v.startsWith('FAIL')).join(' or ')}. The park is not verifiable as written. Move the issue back: ./scripts/move-issue.sh ${issue.id} in_progress --role QA --note "<what makes the park unverifiable>", and return the unmet list. Do NOT fix it yourself, and do NOT re-park it yourself.
${issue.extraQA || ''}
Return the structured result only.`
}

// THE ZERO-DRIFT CHECK IS AN UNNUMBERED CONTINUATION OF THE GATES STEP, DELIBERATELY. It used to
// be numbered, and because it is CONDITIONAL the list then skipped a number whenever it was absent
// — a reader of a docsPath brief saw steps 1-5 and then 7, which reads as a step that was dropped
// on the way to them. Attaching it to the gates step also says what it is: a binding gate for this
// issue, not a separate phase of the review. Do not re-number it; a conditional item inside a
// hand-numbered list has to carry arithmetic that nothing checks.
function qaPrompt(issue) {
  // THE PATH FORM STILL WINS WHERE IT APPLIES — it is right for the projects that have
  // golden FILES, which is most of them. driftRule is the fallback for the projects it
  // cannot serve, and a project may legitimately have both.
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
4. Walk the AC line by line; record PASS/FAIL per bullet with concrete evidence (test name, diff, output).
5. Binding cross-cut gates for this issue: ${gatesOf(issue)}. A green suite alone is NOT a PASS where a binding gate applies.${driftStep}
6. Verdict:
   - The four ratified verdicts, from process/MANUAL.md § The Dev → QA handoff step 6 — their one authoring site: PASS · PASS_AC_CORRECTED (implementation right, the AC's own illustration wrong; correct it with the issue) · FAIL_AC · FAIL_REGRESSION. Report the verdict and the landing SEPARATELY: they are two different facts.
   - On a pass (all AC pass w/ evidence, gates green, no Blocker/Critical): ${issue.docsPath ? 'close it — ./scripts/move-issue.sh ' + issue.id + ' qa_complete --role QA --note "<verdict summary>", then set landing=not_applicable: a docs path has NOTHING to land, which is true rather than a workaround.' : 'land it — ./scripts/finish-pr.sh ' + issue.id + ' (squash-merge into ' + CFG.trunk + ', deletes the branch, advances the board). Set landing=landed only if that script COMPLETED. If you verified the change and deliberately did not land it — a blocked-push regime, a held trunk — that is landing=deferred and it is a SUCCESS: report it, and do not downgrade the verdict to make the outcome look consistent.'} Append the progress.md QA line.
   - If ${CFG.gateCmd} reports a gate that COULD NOT RUN, you have no evidence about the implementation and so no verdict to issue: stop and report the precondition failure. Neither FAIL token fits — both assert something false about the code.
   - On a fail: ./scripts/move-issue.sh ${issue.id} in_progress --role QA --note "<unmet AC list>" and return the unmet_ac list with whichever FAILING verdict of ${VERDICTS.filter(v => v.startsWith('FAIL')).join(' / ')} fits — an unmet acceptance criterion vs. a green thing this made red. Do NOT fix code yourself.
${issue.extraQA || ''}
Return the structured result only.`
}

const results = []
let halted = null

for (const issue of ARGS.issues) {
  if (halted) { results.push({ id: issue.id, skipped: true, reason: `tranche halted at ${halted}` }); continue }

  // NO per-issue phase() here. Every agent below is already assigned to a DECLARED
  // group by provision()'s `phase` argument ('Dev' / 'QA'), which is what meta.phases
  // names. The global phase() call that used to sit here created one undeclared group
  // per issue on top of that, so meta.phases described a shape the run never had —
  // and a global phase inside a loop is the state opts.phase exists to avoid touching.
  log(`${issue.id}: Dev round starting`)
  // Call site 1 of 7 — Dev, fresh pickup.
  let dev = await agent(devPrompt(issue, null), provision(`dev:${issue.id}`, 'Dev', issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
  if (!dev || dev.status !== 'dev_complete') {
    if (!(issue.parkable && dev && dev.status === 'blocked')) {
      halted = issue.id
      results.push({ id: issue.id, outcome: OUTCOME.BLOCKED_DEV, dev })
      continue
    }
    // A PM-sanctioned park (issue moved to blocked/ with a findings write-up) is a
    // valid close for this issue ONLY once fresh eyes have verified the park is TRUE.
    // PARKED_OK is unreachable from here without a park-QA PASS.
    log(`${issue.id}: Dev PARKED the issue — park-QA round starting (no close without review)`)
    // Call site 2 of 7 — park-QA, first review. Same provision() seam and the issue's own
    // qaModel/qaEffort/qaAgentType: a park review must not silently escalate or degrade.
    let park = await agent(parkPrompt(issue, null), provision(`park-qa:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, PARK_SCHEMA))
    if (!park || !isPass(park.verdict)) {
      log(`${issue.id}: park-QA ${(park && park.verdict) || 'no verdict'} — one bounded fix round`)
      const parkNotes = `${(((park && park.unmet) || []).join('\n'))}\n${(park && park.notes) || ''}`
      // Call site 3 of 7 — Dev, park fix round. Same provisioning as the fresh pickup.
      dev = await agent(devPrompt(issue, parkNotes), provision(`dev-park-fix:${issue.id}`, 'Dev', issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
      if (dev && dev.status === 'dev_complete') {
        // The fix round withdrew the park and finished the work — it is no longer a park,
        // so it takes the ordinary QA leg below rather than a second park-QA.
        log(`${issue.id}: park withdrawn by the fix round — falling through to the ordinary QA leg`)
      } else {
        // Call site 4 of 7 — park-QA, second review. Same provisioning as the first.
        park = await agent(parkPrompt(issue, parkNotes), provision(`park-qa2:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, PARK_SCHEMA))
      }
    }
    if (!dev || dev.status !== 'dev_complete') {
      // The verdict alone decides a park's close, as before — but that is now the
      // GENERAL rule rather than a park-shaped exemption: no halt anywhere in this
      // runner keys on the landing field. A park reports landing=not_applicable
      // because it lands nothing, which is a true statement rather than a value the
      // caller has to know to ignore.
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
  // Call site 5 of 7 — QA, first review.
  let qa = await agent(qaPrompt(issue), provision(`qa:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))

  if (qa && !isPass(qa.verdict)) {
    log(`${issue.id}: QA ${qa.verdict} — one bounded fix round`)
    const notes = `${(qa.unmet_ac || []).join('\n')}\n${qa.notes || ''}`
    // Call site 6 of 7 — Dev, fix round. Same provisioning as the fresh pickup:
    // a bounce must not silently escalate the model or the effort.
    //
    // AND IF THE SECOND QA FAILS IN THE CURE'S OWN BLIND SPOT, THE ANSWER IS NOT A THIRD
    // ROUND — there is no third round here, and there must not be one added. A defect that
    // lives where the FIRST fix's assumptions do not look is evidence about the approach,
    // not about effort: the cure did not miss it, the cure produced the place where it
    // could hide. The terminating move is a change of SHAPE or of AUTHOR — a different
    // approach, or different eyes. See process/doctrine/fix-execution.md § A.5c, which
    // also says why "try again, harder" is the wrong reading: capability is not what is
    // missing when the search is pointed at the wrong place.
    dev = await agent(devPrompt(issue, notes), provision(`dev-fix:${issue.id}`, 'Dev', issue.devModel, issue.devEffort, issue.devAgentType, DEV_SCHEMA))
    if (dev && dev.status === 'dev_complete') {
      // Call site 7 of 7 — QA, second review. Same provisioning as the first.
      qa = await agent(qaPrompt(issue), provision(`qa2:${issue.id}`, 'QA', issue.qaModel, issue.qaEffort, issue.qaAgentType, QA_SCHEMA))
    }
  }

  // THE HALT KEYS ON THE VERDICT, NEVER ON THE LANDING — this is the line that
  // stopped a successful run. `!qa.landed` halted the tranche and skipped every
  // remaining issue on a review that had passed with its landing correctly
  // deferred. A deferred landing is continue-and-defer; only a failed REVIEW halts.
  if (!qa || !isPass(qa.verdict)) {
    halted = issue.id
    // FAILED, not PARKED. A QA failure after the bounded fix round leaves the issue in
    // in_progress/ — it is not parked, and calling it PARKED made a run summary report a
    // sanctioned close where there was an unfinished issue. wave-runner.js has always
    // used the honest name; this is the two runners agreeing rather than a new word.
    results.push({ id: issue.id, outcome: OUTCOME.FAILED_AFTER_FIX_ROUND, dev, qa })
    continue
  }
  // A pass that did not land is still a pass, and the tranche continues — but the
  // outcome NAMES it, or the report re-merges downstream the two axes the schema
  // just separated.
  if (qa.landing === 'landed' || qa.landing === 'not_applicable') {
    log(`${issue.id}: LANDED`)
    results.push({ id: issue.id, outcome: OUTCOME.LANDED, qa_evidence: qa.ac_walk, gates: qa.gate_evidence })
  } else {
    log(`${issue.id}: LAND-READY (verified; landing deferred) — tranche continues`)
    results.push({ id: issue.id, outcome: OUTCOME.LAND_READY, qa_evidence: qa.ac_walk, gates: qa.gate_evidence })
  }
}

return { halted, results }
