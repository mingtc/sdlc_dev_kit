# KIT-CLASS: MIXED — self-test harness, shipped-set conformance cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/shipped-tree.sh — sourced by scripts/test/run.sh, never run on its own.
# Conformance over the shipped set: skills, CLI shape, help windows, the floor, doctrine,
# template links, travelling sheets, hygiene, exit codes, seam shape, scaffolding, the manifest.
# =============================================================================

# =============================================================================
# NO SHIPPED SKILL REFERENCES A FOREIGN PLUGIN NAMESPACE
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE (the raising leg's § A.5b argument, kept because
# it is the whole reason this is a case): the population of bad references GROWS
# MONOTONICALLY with every plan a project writes, and those documents OUTLIVE any later
# kit fix — `writing-plans/SKILL.md` says "Every plan MUST start with this header", and
# the header carried the namespace. A sentence fixes the kit; it does not fix the plans
# already written from it, and it does not stop the next one.
#
# THE PATTERN IS `<ns>:<skill>` WITH NO SPACES, not the word. `using-skills/` is a
# legitimate shipped skill directory, so a word match would fire on the fix itself.
# (It was `using-superpowers/` when this was written; the rename does not change the
# argument, only the example.)
# Scoped to markdown and excluding URL schemes and inline CSS (`display:flex`,
# `.card:hover` live in this tree and are not references) — measured, not assumed: the
# unscoped form matched four CSS declarations in brainstorming/.
#
# AND IT FOUND ONE THE DE-NAMESPACING MISSED. The de-namespacing change closed the
# foreign `<ns>:<skill>` form and left
# `elements-of-style:writing-clearly-and-concisely` in brainstorming/SKILL.md, hedged
# with "if available" — which is exactly the softening that survives review. Fixed with
# the intent preserved rather than the line deleted; the reference had no subject in this
# kit, so by that change's own precedent for its one subject-less row it could not stay.
_foreign_ns_hits() {  # <dir> — prints "file:line:reference" per hit
  grep -rnE '\b[a-z][a-z0-9-]*:[a-z][a-z0-9-]+\b' --include='*.md' "$1" 2>/dev/null \
    | grep -vE 'https?:|file:|mailto:|style="' || true
}

case_skills_carry_no_foreign_namespace() {
  cf_reset
  make_sandbox

  # DUAL-SPELLING, and the reason belongs here rather than in the reader's memory: the
  # maintainer repository stores the kit disarmed (`_claude/`), a built kit ships it
  # armed (`.claude/`). Reading whichever exists lets this case still find the real
  # shipped tree in place. It does NOT make an in-place run a witness — see the header.
  local skills="" d
  for d in "$REAL_REPO_ROOT/_claude/skills" "$REAL_REPO_ROOT/.claude/skills"; do
    [ -d "$d" ] && skills="$d"
  done
  if [ -z "$skills" ]; then
    cf "no shipped skills directory found under either _claude/ or .claude/ — the check has no operand"
    finish "shipped skills: no foreign plugin namespace"; teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero files scanned finds zero hits and
  # "passes". A skills tree with no markdown in it means the extractor lost its subject.
  local nfiles; nfiles="$(find "$skills" -name '*.md' -type f | wc -l | tr -d ' ')"
  [ "$nfiles" -ge 5 ] \
    || cf "only $nfiles markdown file(s) under $skills — too few to be the shipped skill set; the scan lost its operand rather than finding a clean tree"

  local hits; hits="$(_foreign_ns_hits "$skills")"
  [ -z "$hits" ] || cf "a shipped skill references a foreign plugin namespace (the kit ships no such namespace, so it cannot resolve):
$(printf '%s' "$hits" | sed 's/^/      /')"

  # ── THE REDDENING CONTROL, on a COPY — never the live tree (instruments.md § A.2).
  local probe="$SB_TMP/nsprobe"; mkdir -p "$probe"
  cp "$skills"/*/SKILL.md "$probe/" 2>/dev/null || true
  local victim; victim="$(probe_pick "$probe" -name '*.md' -type f)"
  if [ -z "$victim" ]; then
    _control_did_not_run "copy a SKILL.md to plant into"
  else
    printf '\n- Use superpowers:executing-plans skill if available\n' >> "$victim"
    local planted; planted="$(_foreign_ns_hits "$probe")"
    printf '%s' "$planted" | grep 'superpowers:executing-plans' >/dev/null \
      || cf "(control) the check did NOT find a planted foreign reference — it cannot see the defect it is named after"
    printf '%s' "$planted" | grep "$(basename "$victim")" >/dev/null \
      || cf "(control) the finding does not name the file it is in: $planted"
  fi

  finish "shipped skills: no foreign plugin namespace ($nfiles md files scanned), and a planted one is found and named"
  teardown
}

# =============================================================================
# THE ORDER OF THE THREE CASES BELOW IS DECIDED, NOT ACCIDENTAL. Each was authored
# separately and each said "beside case_skills_carry_no_foreign_namespace"; all
# three cannot be literal neighbours. Ordered by SUBJECT ADJACENCY: the two that
# read the same operand as the case above (the shipped skills corpus — what those
# skills SAY) sit with it first, and the dev/ index case, whose corpus is a
# different tree entirely, follows them.
#   1. no foreign plugin namespace   (above)   — what a skill NAMES
#   2. no unconditional forge command          — what a skill INSTRUCTS
#   3. upstream product name only where kept   — what a skill CALLS things
#   4. the dev/ index names its subdirectories — a different corpus
# =============================================================================

# =============================================================================
# no shipped skill states a FORGE COMMAND as an instruction
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE: the return path is an UPSTREAM RE-COPY. These
# skills are vendored; updating one is "copy the folder over and diff", and the rule
# that says which way the merge goes lives in skills/README.md — prose, in the file a
# diff-reader skims. A re-copy that restores a single forge's command has not updated
# the skill, it has re-narrowed it, and the adopter who cannot run that command is the
# one who finds out.
#
# WHY PARAGRAPHS AND NOT LINES (instruments.md § A.7.1): line breaks are an artifact of
# the authoring tool. MEASURED: a correctly-marked paragraph whose "example" wraps onto
# a line other than the command is a FALSE POSITIVE under grep -n and clean under this.
# The second control below is that measurement, kept executable.
#
# THE LEXICON IS AN ENUMERATION AND SAYS SO (§ A.7.4/5): gh|glab|hub|tea × subcommand,
# marker set example|illustrative|not exhaustive. Measured cost of the forge list on the
# shipped tree: zero false positives. "adapter" and "your forge" are DELIBERATELY NOT
# enrolled — they would suppress a line that gives a live forge instruction while
# gesturing at the adapter.
#
# ADOPTER-SPECIFIC FACT, DECLARED: this pins a KIT property. An adopter who adopts the
# optional forge flavor and writes its command into their own skill copy should mark it
# as their project's declared example, or drop this case.
_forge_cmd_paras() {   # <file> — "<file>:<first-line>:<paragraph>" per PARAGRAPH naming a forge CLI
  awk -v f="$1" '
    function flush() {
      if (p != "" && p ~ /(^|[^A-Za-z])(gh|glab|hub|tea) (pr|issue|repo|api|release|auth|workflow|mr|merge-request) /)
        print f ":" start ":" p
      p=""; start=0
    }
    /^[[:space:]]*$/ { flush(); next }
    { if (p == "") { start=NR; p=$0 } else { p = p " " $0 } }
    END { flush() }
  ' "$1"
}

_forge_paras_all() {   # <dir> — every forge-command paragraph under it, marked or not
  find "$1" -name '*.md' -type f -print0 2>/dev/null \
    | while IFS= read -r -d '' f; do _forge_cmd_paras "$f"; done
}

_forge_paras_unmarked() {   # <dir> — the ones that do NOT declare themselves an example
  _forge_paras_all "$1" | grep -viE 'example|illustrative|not exhaustive' || true
}

_forge_unmarked_n() {  # <dir> — how many
  _forge_paras_unmarked "$1" | grep -c . || true
}

case_skills_name_no_forge_unconditionally() {
  cf_reset
  make_sandbox

  # DUAL-SPELLING, and the reason belongs here rather than in the reader's memory: the
  # maintainer repository stores the kit disarmed (`_claude/`), a built kit ships it
  # armed (`.claude/`). Reading whichever exists lets this case still find the real
  # shipped tree in place. It does NOT make an in-place run a witness — see the header.
  local skills="" d
  for d in "$REAL_REPO_ROOT/_claude/skills" "$REAL_REPO_ROOT/.claude/skills"; do
    [ -d "$d" ] && skills="$d"
  done
  if [ -z "$skills" ]; then
    cf "no shipped skills directory found under either _claude/ or .claude/ — the check has no operand"
    finish "shipped skills: no unconditional forge command"; teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero files scanned finds zero hits and
  # "passes" (the sibling namespace case's rule, reused).
  local nfiles; nfiles="$(find "$skills" -name '*.md' -type f | wc -l | tr -d ' ')"
  [ "$nfiles" -ge 5 ] \
    || cf "only $nfiles markdown file(s) under $skills — too few to be the shipped skill set; the scan lost its operand rather than finding a clean tree"

  local total; total="$(_forge_paras_all "$skills" | grep -c . || true)"
  local unmarked; unmarked="$(_forge_paras_unmarked "$skills")"
  [ -z "$unmarked" ] || cf "a shipped skill gives a forge command as an instruction, not as an example (the kit is forge-agnostic: an adopter on another forge cannot run it):
$(printf '%s' "$unmarked" | sed "s|^$skills/||" | cut -c1-200 | sed 's/^/      /')"

  # ── THE REDDENING CONTROLS, on a COPY — never the live tree (instruments.md § A.2).
  # Both are DELTAS against a baseline taken on the copy, so neither depends on the live
  # tree being clean: a real defect above must not be able to satisfy a control below.
  local probe="$SB_TMP/forgeprobe"; rm -rf "$probe"; mkdir -p "$probe"
  local src; src="$(probe_pick "$skills" -name 'SKILL.md' -type f)"
  [ -n "$src" ] && cp "$src" "$probe/victim.md"
  if [ ! -f "$probe/victim.md" ]; then
    _control_did_not_run "copy a SKILL.md to plant into (NEITHER control ran)"
  else
    local base; base="$(_forge_unmarked_n "$probe")"

    # CONTROL 1 — an unmarked instruction is FOUND and NAMED.
    printf '\nRun `gh pr create --fill` to open the review.\n' >> "$probe/victim.md"
    local planted; planted="$(_forge_paras_unmarked "$probe")"
    printf '%s' "$planted" | grep 'gh pr create' >/dev/null \
      || cf "(control) the check did NOT find a planted unconditional forge command — the pattern set no longer matches the case it was built for"
    printf '%s' "$planted" | grep 'victim.md' >/dev/null \
      || cf "(control) the finding does not name the file it is in: $planted"
    local after; after="$(_forge_unmarked_n "$probe")"
    [ "$after" -eq $(( base + 1 )) ] \
      || cf "(control) planting one instruction moved the count from $base to $after, not to $(( base + 1 ))"

    # CONTROL 2 — a MARKED instruction whose marker wrapped onto another line is NOT a
    # finding. This is the § A.7.1 measurement, kept executable: under a raw-line check
    # this plant is a false positive.
    printf '\nGitHub the CLI, as one example, is\nnot the requirement: run `gh pr create --fill` here.\n' >> "$probe/victim.md"
    local wrapped; wrapped="$(_forge_unmarked_n "$probe")"
    [ "$wrapped" -eq "$after" ] \
      || cf "(control) a WRAPPED paragraph whose example marker sits on a line other than the command was counted as unmarked ($wrapped, expected $after) — the guard is reading raw lines, not normalised paragraphs"
  fi

  finish "shipped skills: every forge command is a named example ($total forge-command paragraph(s) across $nfiles md files under the skills tree; span = markdown under the skills tree, lexicon = gh/glab/hub/tea), and a planted instruction is found and named"
  teardown
}

# =============================================================================
# the UPSTREAM PRODUCT NAME survives only where a rename would make a true
# statement FALSE — and the allowance is a PATTERN, not a file list
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE: the de-namespacing change closed the `<ns>:<skill>`
# form (the case above) and then stated, in prose, that the only residue left was
# directory and file names. It was not — instruction prose, a path in executing code and
# a rendered page title also carried it — and three of those files were missing from the
# first hand enumeration of them. A prose enumeration of residue is stale the day a line
# is added; this makes it executable, so the NEXT mention has to argue for itself.
#
# THE ALLOWED SHAPES, each with the reason it is allowed. There were three; the second
# was `using-superpowers`, the shipped skill directory's own name, allowed only because
# the rename was link-breaking and deferred. THE RENAME LANDED — the directory is
# `using-skills` — SO THAT ALLOWANCE IS DELETED AND THIS CASE IS NOW THE RENAME'S OWN
# GATE, exactly as the allowance instructed. Do not restore it: a re-appearance of the
# old directory name is a finding, which is the whole point of removing the carve-out.
# The remaining shapes:
#   1. `~/.config/superpowers/…` — an EXTERNAL tool's real directory. The skills ADOPT that
#      directory where it already exists — they never create it — and add a worktree inside
#      it, so renaming it in our copy would send a correct instruction looking for a
#      directory nothing creates.
#   2. A line carrying the upstream repository URL — provenance. A skill whose origin
#      nobody can name is a skill nobody can safely update, so the citation stays.
# Patterns, not paths: a residue site that moves to another file is still caught and no
# file list has to be maintained. Line granularity is the known limit — prose sharing a
# line with an allowed shape rides through, which is why the shapes are narrow.
#
# SCOPE, stated rather than implied: the shipped agent surface only (`_claude/` before
# init, `.claude/` after). NOT the adopter's own tree, which has its own vocabulary and
# would inherit findings it cannot interpret; NOT this harness, which names the word in
# comments and plants it in three controls, so scanning it would fire on the instruments
# instead of the subject.
_upstream_name_hits() {  # <dir> — prints "file:line:text" per DISALLOWED mention
  grep -rn -i 'superpowers' "$1" 2>/dev/null \
    | grep -vE '\.config/superpowers/' \
    | grep -vE 'github\.com/[^ ]*/superpowers' || true
}

case_upstream_name_only_where_kept() {
  cf_reset
  make_sandbox

  # DUAL-SPELLING, and the reason belongs here rather than in the reader's memory: the
  # maintainer repository stores the kit disarmed (`_claude/`), a built kit ships it
  # armed (`.claude/`). Reading whichever exists lets this case still find the real
  # shipped tree in place. It does NOT make an in-place run a witness — see the header.
  local agent="" d
  for d in "$REAL_REPO_ROOT/_claude" "$REAL_REPO_ROOT/.claude"; do
    [ -d "$d" ] && agent="$d"
  done
  if [ -z "$agent" ]; then
    cf "no shipped agent directory found under either _claude/ or .claude/ — the check has no operand"
    finish "shipped skills: upstream name only where a rename would falsify"; teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero files scanned finds zero mentions
  # and "passes".
  local nfiles
  nfiles="$(find "$agent" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.html' \) | wc -l | tr -d ' ')"
  [ "$nfiles" -ge 20 ] \
    || cf "only $nfiles scannable file(s) under $agent — too few to be the shipped agent surface; the scan lost its subject rather than finding a clean tree"

  local hits; hits="$(_upstream_name_hits "$agent")"
  [ -z "$hits" ] || cf "the upstream product name is used where nothing depends on it — allowed only as the external \`~/.config/superpowers/\` path or a line carrying the upstream repository URL:
$(printf '%s' "$hits" | sed 's/^/      /')"

  # ── THE REDDENING CONTROL, on a COPY — never the live tree (instruments.md § A.2).
  # BOTH DIRECTIONS IN ONE PLANT: a bare product-name mention must be FOUND and named,
  # and the kept external path planted beside it must NOT be — an allowance that has
  # stopped working would redden this case on correct content, which is the failure a
  # one-directional control cannot see.
  local probe="$SB_TMP/upstreamprobe"; mkdir -p "$probe"
  local victim="$probe/planted-SKILL.md"
  local src; src="$(probe_pick "$agent" -name 'SKILL.md' -type f)"
  [ -n "$src" ] && cp "$src" "$victim"
  if [ ! -f "$victim" ]; then
    _control_did_not_run "copy a SKILL.md to plant into"
  else
    printf '\n**Note:** Superpowers works much better with access to subagents.\n' >> "$victim"
    printf '\n   ls -d ~/.config/superpowers/worktrees/$project\n' >> "$victim"
    local planted; planted="$(_upstream_name_hits "$probe")"
    printf '%s' "$planted" | grep -i 'Superpowers works much better' >/dev/null \
      || cf "(control) the check did NOT find a planted product-name mention — it cannot see the defect it is named after"
    printf '%s' "$planted" | grep 'planted-SKILL.md' >/dev/null \
      || cf "(control) the finding does not name the file it is in: $planted"
    printf '%s' "$planted" | grep '\.config/superpowers/worktrees' >/dev/null \
      && cf "(control) the kept external path was reported as a finding — the allowance for it has stopped working, and this case would redden on correct content"
  fi

  finish "shipped skills: upstream name only where a rename would falsify ($nfiles files scanned), and a planted mention is found and named"
  teardown
}

# =============================================================================
# THE dev/ INDEX NAMES every subdirectory that carries its own README
# =============================================================================
# WHY A MECHANISM AND NOT A SENTENCE: dev/README.md states its index rule as
# BIDIRECTIONAL and warns that a rule enforced in one direction rots in the other. It
# then rotted in exactly that direction — a subdirectory was added with a substantive
# README and two templates pointing into it, and a grep for its name in dev/README.md
# matched nothing for the whole life of the directory. The sentence was there; the miss
# happens in the change that CREATES the directory, where the reviewer reads the new
# README and not the old index.
#
# SCOPE IS THE SPLIT-OUT SUBDIRECTORY, and that is the file's own rule: "split it out
# into its own dev/<dir>/README.md and leave a one-line row here" means a subdirectory
# holding a README has a row owed. Dated snapshots are NOT asserted — they arrive
# constantly in a live project, and a case that reddened on each unindexed one would be
# switched off in a week. An abandoned case guards nothing.
_dev_unindexed_subdirs() {  # <dev-dir> — prints the basename of each subdirectory
  local dev="$1" idx="$1/README.md" d n   # that holds a README.md and is named nowhere in dev/README.md
  [ -f "$idx" ] || return 0
  while IFS= read -r d; do
    [ -f "$d/README.md" ] || continue
    n="$(basename "$d")"
    grep -qF -- "$n/" "$idx" || printf '%s\n' "$n"
  done < <(find "$dev" -mindepth 1 -maxdepth 1 -type d | sort)
}

case_dev_index_names_its_subdirs() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; this case reads the REAL shipped tree

  local dev="$REAL_REPO_ROOT/dev"
  if [ ! -f "$dev/README.md" ]; then
    skp "dev/ index names every subdirectory that carries its own README" "dev/README.md absent"
    teardown; return
  fi

  # ASSERT THE OPERAND, not only the comparison: zero subdirectories scanned finds zero
  # misses and "passes". A dev/ with no split-out directory means the scan lost its subject.
  local nsub; nsub="$(find "$dev" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/README.md' \; -print | wc -l | tr -d ' ')"
  [ "$nsub" -ge 1 ] \
    || cf "no subdirectory under dev/ carries a README.md — the scan lost its operand rather than finding a complete index"

  local missing; missing="$(_dev_unindexed_subdirs "$dev")"
  [ -z "$missing" ] || cf "a dev/ subdirectory with its own README is named nowhere in dev/README.md — unindexed, against that file's own first rule:
$(printf '%s' "$missing" | sed 's|^|      dev/|;s|$|/|')"

  # ── THE REDDENING CONTROL, on a COPY — never the live tree (instruments.md § A.2).
  local probe="$SB_TMP/devprobe"; rm -rf "$probe"; mkdir -p "$probe/zz-planted"
  cp "$dev/README.md" "$probe/README.md" 2>/dev/null || true
  printf '# a planted subdirectory nobody indexed\n' > "$probe/zz-planted/README.md"
  if [ ! -f "$probe/README.md" ]; then
    _control_did_not_run "copy dev/README.md to plant against"
  else
    _dev_unindexed_subdirs "$probe" | grep -x 'zz-planted' >/dev/null \
      || cf "(control) the check did NOT flag a planted unindexed subdirectory — it cannot see the defect it is named after"
  fi

  finish "dev/ index names every subdirectory that carries its own README ($nsub scanned), and a planted one is flagged"
  teardown
}

# =============================================================================
# CASE — THE CLI SHAPE HOLDS ACROSS THE WHOLE SHIPPED SET, DERIVED NOT LISTED.
#
# contracts/issue-creation.md § 3 binds every command-line tool the kit ships: a usage
# request is always legal and always succeeds; an unrecognised option refuses, non-zero,
# NAMING it, with ONE status across the set — and § 3 now names that status as 2.
#
# THE SUBJECT SET IS DERIVED FROM THE SANDBOX, and that is the whole design. The change
# file that raised this carried a hand-assembled list, and the list was wrong in both
# directions — it named two scripts that already conformed and missed the two dangerous
# ones, where a REFUSAL READ AS SUCCESS: `next-id.sh --help` printed a mintable
# identifier and exited 0, and `notify.sh` warned about a stray flag, delivered the
# message anyway, and exited 0. A control that restated that list would have inherited
# its blind spots; this one goes blind only if the glob does.
#
# `</dev/null` IS LOAD-BEARING on every invocation: an enumeration that reaches a
# stdin-reading tool without it hangs the whole suite rather than failing it.
# =============================================================================
# =============================================================================
# CASE — EACH HELP WINDOW ENDS WHERE ITS OWN RULE SAYS, AND THERE ARE TWO RULES.
#
# Most shipped tools render `--help` from their own header comment block, ending at the
# LAST COMMENT LINE. `release.sh` ends at its LAST USAGE EXAMPLE instead, deliberately —
# its header carries operator notes below the examples that are not help text. Measured:
# putting release.sh on the header-block rule takes its --help from its SYNOPSIS length to the whole
# header block — measure both rather than quoting figures here (`./scripts/release.sh --help | wc -l`
# against `bash -c '. scripts/lib/usage.sh; kit_usage scripts/release.sh' | wc -l`); this said 63 and
# the second measure is now 66.
#
# WHY A CONTROL AT ALL. Nothing asserted --help CONTENT for any tool — the existing
# coverage checks rc=0 and non-emptiness. A hard-coded window is a census in disguise,
# and this repository has paid for that class twice: a control that came back green
# because the paragraph it was checking had landed OUTSIDE the window it checked.
#
# THE CORPUS IS DERIVED, and by BEHAVIOUR rather than by a list of filenames, so it
# survives the renderer being lifted into a library: a script is a header renderer iff
# its --help succeeds and its first output line is its own line 3, de-hashed.
# =============================================================================
# =============================================================================
# CASE — THE HEADER-BLOCK --help RENDERER HAS ONE AUTHORING SITE.
#
# "It sources lib/usage.sh" is a LABEL, satisfied by a script that sources the file and
# then goes on using its own inline copy. Nothing below asserts it. What cannot be faked:
# make the LIBRARY emit an extra line and every consumer must show it.
#
# ARM 2 IS THE ONE THAT CATCHES THE TRAP, and arm 1 cannot see it. Inside a SOURCED
# function `${BASH_SOURCE[0]}` names THE LIBRARY — so a naive lift makes every caller's
# --help print lib/usage.sh's own header. The sentinel is IN the library, so arm 1 stays
# green while every tool prints the wrong document. Arm 2 asserts each consumer still
# renders ITS OWN header, which is the only thing that distinguishes the two.
# =============================================================================
case_usage_renderer_has_one_authoring_site() {
  cf_reset
  make_sandbox
  publish_sandbox

  local lib="$SB_WORK/scripts/lib/usage.sh" tok='USAGERENDER-ONE-HOST-SENTINEL'
  [ -f "$lib" ] \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: no scripts/lib/usage.sh in the sandbox — there is no shared host to mutate."
  [ -z "$( { find "$SB_WORK/scripts" -type f ! -path '*/test/*' -exec grep -lF "$tok" {} + 2>/dev/null || true; } )" ] \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: the sentinel already occurs under scripts/ — the plant would prove nothing."

  # THE CONSUMER SET IS DERIVED, never listed — a literal list in a guard goes blind the
  # first time a script joins or leaves.
  local consumers f base out n=0
  # Matched WITHOUT a line anchor on purpose: verify.sh sources the library inside a
  # guard (it runs `set -uo pipefail` and not `set -e`, so an unguarded load would fail
  # silently and take --help down with rc=127). An anchored pattern would leave the one
  # consumer with the most fragile load out of the very case that checks the load.
  consumers="$( { grep -lF '. "$SCRIPT_DIR/lib/usage.sh"' "$SB_WORK"/scripts/*.sh 2>/dev/null || true; } )"
  [ -n "$consumers" ] \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: no script sources lib/usage.sh — the per-consumer loop below would run zero times and report PASS."

  # PRE-PLANT: every consumer's --help must already work, or the post-plant grep fails
  # for a reason that has nothing to do with the library.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )" \
      || _fixture_die "case_usage_renderer_has_one_authoring_site: $base --help already fails BEFORE the plant."
    [ -n "$out" ] \
      || _fixture_die "case_usage_renderer_has_one_authoring_site: $base --help prints nothing before the plant."
  done <<PRE_EOF
$consumers
PRE_EOF

  # THE PLANT — one extra emitted line, in the LIBRARY only.
  _plant_in_function "$lib" kit_usage "  echo '$tok'" \
    "case_usage_renderer_has_one_authoring_site"

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"; n=$((n+1))
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )"
    # ARM 1 — the plant reaches this consumer.
    printf '%s\n' "$out" | grep -F "$tok" >/dev/null \
      || cf "(1) $base --help does not carry a line added to lib/usage.sh — it sources the library and then renders with its own inline copy"
    # ARM 2 — …and it still renders ITS OWN header, not the library's.
    printf '%s\n' "$out" | grep -F "$(sed -n '3p' "$f" | sed 's|^# \{0,1\}||')" >/dev/null \
      || cf "(2) $base --help no longer contains its OWN line 3 — the renderer is reading \${BASH_SOURCE[0]}, which inside a sourced function names the LIBRARY, so every tool is printing lib/usage.sh's header"
  done <<POST_EOF
$consumers
POST_EOF

  # ARM 3 — no second authoring site survives under scripts/.
  #
  # THE EXPRESSION IS DERIVED OUT OF THE LIBRARY, NOT RETYPED HERE, and this arm is the reason the
  # rule exists. It used to grep for the literal `awk 'NR>2 && !/^#/{print NR; exit}'`. The library
  # was later reworded to `awk -v s="$start" 'NR>=s && !/^#/{print NR; exit}'` — so the literal
  # matched NOTHING in the shipped tree, the census returned empty, and this arm reported "one
  # authoring site" while measuring nothing at all. Found by adding the control below, which is the
  # only reason it was ever visible: the arm passes on an empty result, and an empty result from a
  # blind search looks exactly like a clean tree.
  #
  # What is derived is the STABLE HALF of the idiom — finding the first non-comment line — rather
  # than the whole statement, whose prefix legitimately changes when the library's floor logic does.
  local ren_expr ren_all second
  ren_expr="$(grep -oF '!/^#/{print NR; exit}' "$lib" | head -1)"
  [ -n "$ren_expr" ] \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: could not derive the renderer's line-finding expression out of scripts/lib/usage.sh, which authors it. A census with nothing to search for returns empty and reports ONE authoring site forever."
  # INSTRUMENT: the derived expression must find the library itself. If it cannot, the search is
  # blind and every result below is about nothing. (The sandbox has no scripts/test/, which
  # make_sandbox removes, so this file's own copy of the idiom cannot satisfy the control.)
  ren_all="$( { grep -rlF -- "$ren_expr" "$SB_WORK/scripts" 2>/dev/null || true; } )"
  printf '%s\n' "$ren_all" | grep '/lib/usage\.sh' >/dev/null \
    || _fixture_die "case_usage_renderer_has_one_authoring_site: the derived renderer expression was not found even in scripts/lib/usage.sh, which authors it — so this census matches nothing and would report ONE authoring site whatever the tree contains."
  second="$(printf '%s\n' "$ren_all" | grep -v '/lib/usage\.sh' | grep -v '^$' || true)"
  [ -z "$second" ] \
    || cf "(3) the header-block renderer is still authored in: $(printf '%s' "$second" | tr '\n' ' ') — one rule, more than one place to change it, and the two will disagree"

  finish "the header-block --help renderer has ONE authoring site: a line added to scripts/lib/usage.sh reaches all $n consumer(s), each still renders its OWN header rather than the library's, and no second implementation survives under scripts/ — with the search EXPRESSION derived out of the library rather than retyped here, and asserted to find the library itself first, because this arm passes on an empty result and a search that stopped matching returns empty too. NOT LOOKED AT, and the exclusion is deliberate rather than an oversight: scripts/test/, which make_sandbox removes. The harness derives the same boundary twice on its own account — once to render its own --help and twice inside the case that checks where a header window ends — and that second derivation MUST stay independent, because a harness that asked the subject where its header ends would agree with it by construction. Measured: those independent floors cannot disagree with the library on any file whose header is contiguous comments from line 3, which is every file the renderer can serve"
  teardown
}

case_help_window_ends_where_its_rule_says() {
  cf_reset
  make_sandbox
  publish_sandbox

  local tokA='HELPWINDOW-TAIL-SENTINEL' tokIn='HELPWINDOW-EXAMPLE-SENTINEL' tokOut='HELPWINDOW-BELOW-SENTINEL'
  [ -z "$( { find "$SB_WORK/scripts" -type f ! -path '*/test/*' -exec grep -lF "$tokA" {} + 2>/dev/null || true; } )" ] \
    || _fixture_die "case_help_window_ends_where_its_rule_says: the sentinel already occurs under scripts/ — every assertion would be satisfiable without the plant."

  # ── derive the corpus by BEHAVIOUR.
  local f base line3 out corpus="" n=0
  for f in "$SB_WORK"/scripts/*.sh; do
    [ -e "$f" ] || continue
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )" || continue
    line3="$(sed -n '3p' "$f" | sed 's|^# \{0,1\}||')"
    [ -n "$line3" ] || continue
    [ "$(printf '%s\n' "$out" | sed -n '1p')" = "$line3" ] || continue
    corpus="${corpus}${f}\n"; n=$((n+1))
  done
  [ "$n" -gt 1 ] \
    || _fixture_die "case_help_window_ends_where_its_rule_says: the derived corpus holds $n script(s) — the probe lost its subject and every arm below would be vacuous."

  # ── (a) THE HEADER-BLOCK RULE: a comment on the LAST line of the header must appear.
  #    The insert point is computed HERE, never asked of the script — a harness that
  #    asked the subject where its header ends would agree with it by construction.
  local first ins seen_release=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"
    if [ "$base" = "release.sh" ]; then seen_release=1; continue; fi
    first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$f")"
    [ -n "$first" ] && [ "$first" -gt 3 ] \
      || _fixture_die "case_help_window_ends_where_its_rule_says: $base has no header block to plant into (first non-comment line: ${first:-none})."
    ins=$((first-1))
    TOK="$tokA" LN="$ins" awk -v tok="$tokA" -v ln="$ins" 'NR==ln{print; print "# " tok; next} {print}' "$f" > "$f.new" && mv "$f.new" "$f"
    chmod +x "$f"
    grep -qF "$tokA" "$f" || _fixture_die "case_help_window_ends_where_its_rule_says: the tail sentinel did not land in $base."
    bash -n "$f" || _fixture_die "case_help_window_ends_where_its_rule_says: $base no longer parses after the plant."
    out="$( cd "$SB_WORK" && "$f" --help </dev/null 2>&1 )"
    printf '%s\n' "$out" | grep -F "$tokA" >/dev/null \
      || cf "(a) $base --help does not print the LAST line of its own header — its window is truncated, which is the hard-coded-range defect this class has already been paid for twice"
  done <<CORPUS_EOF
$(printf '%b' "$corpus")
CORPUS_EOF

  # ── (b) THE SYNOPSIS RULE: release.sh ends at its last usage EXAMPLE, both directions.
  if [ "$seen_release" -eq 1 ]; then
    local r="$SB_WORK/scripts/release.sh" lastex
    lastex="$(grep -n '^#[[:space:]]\{1,\}\./scripts/release\.sh[[:space:]]' "$r" | tail -1 | cut -d: -f1)"
    [ -n "$lastex" ] \
      || _fixture_die "case_help_window_ends_where_its_rule_says: no usage-example line in release.sh's header — its window rule has no anchor and arm (b) measures nothing."
    awk -v ln="$lastex" -v tok="$tokIn" 'NR==ln{print; print "#   ./scripts/release.sh 9.9.9   " tok; next} {print}' "$r" > "$r.new" && mv "$r.new" "$r"
    first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$r")"
    awk -v ln=$((first-1)) -v tok="$tokOut" 'NR==ln{print; print "# " tok; next} {print}' "$r" > "$r.new" && mv "$r.new" "$r"
    chmod +x "$r"
    grep -qF "$tokIn" "$r" && grep -qF "$tokOut" "$r" \
      || _fixture_die "case_help_window_ends_where_its_rule_says: one of release.sh's two sentinels did not land."
    bash -n "$r" || _fixture_die "case_help_window_ends_where_its_rule_says: release.sh no longer parses after the plant."
    out="$( cd "$SB_WORK" && "$r" --help </dev/null 2>&1 )"
    printf '%s\n' "$out" | grep -F "$tokIn" >/dev/null \
      || cf "(b) release.sh --help dropped a usage example added at the END of its examples — its window is not tracking the last example: $out"
    printf '%s\n' "$out" | grep -F "$tokOut" >/dev/null \
      && cf "(b) release.sh --help printed a header line BELOW its last usage example — it has been put on the header-block rule, which floods its help with operator notes that are not help text"
  fi

  finish "each --help window ends where its own rule says: the header-block renderers print to the LAST line of their header (a tail sentinel proves it), and release.sh prints to its LAST USAGE EXAMPLE and no further — both directions asserted, corpus derived by behaviour over $n tool(s)"
  teardown
}

# =============================================================================
# CASE — NO DOCTRINE SHEET WRITES A COUNT OF ITS OWN RULE SET.
#
# Three sheets opened with a bare count of their own § A rules, and two siblings already
# carried the repair with its reason. A fourth site was worse: "Two rules keep it honest"
# over FOUR bullets, in shipped prose, false since the sheet was written and false in
# every release. The § A headings are the list; a number written above them is a census
# that goes stale the first time the sheet grows.
#
# THIS ASSERTS THE SHAPE, NOT THE TRUTH, and the difference is the whole design. Grading
# whether a count is CORRECT means deciding which lists are growable — natural-language
# semantics no repository can parse, which this kit's own doctrine says outright. The
# absence of the shape is mechanical, and it is what the siblings already committed to.
#
# SCOPED TO CLASS LINES AND ADOPT LINES, because a wider pattern fires on legitimate
# prose: a single NAMED rule ("One rule that looks like it belongs here and does not"), a
# RATIO ("One check per invariant"), and a historical quote of a count that was removed.
# All three are in the corpus and none is a defect. The uncovered subset is printed on
# green rather than left implied.
# =============================================================================
case_doctrine_states_no_rule_count() {
  cf_reset
  make_sandbox
  local dd="$REAL_REPO_ROOT/process/doctrine"
  if [ ! -d "$dd" ]; then skp "no doctrine sheet writes a count of its own rule set" "process/doctrine/ absent"; teardown; return; fi

  local n; n="$(ls "$dd"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -ge 2 ] \
    || _fixture_die "case_doctrine_states_no_rule_count: only ${n:-0} doctrine sheet(s) scanned — the operand was lost, which is not the same as a clean corpus."

  local pat='^\*\*KIT-CLASS.*\b(one|two|three|four|five|six|seven|eight|nine|ten) (rules?|points?|checks?|invariants?)\b|^\*\*How to adopt:\*\*.*\b(one|two|three|four|five|six|seven|eight|nine|ten) (rules?|points?)\b'

  # INSTRUMENT: the pattern must MATCH a known-bad line, or every green below is vacuous.
  printf '%s\n' '**KIT-CLASS: KIT.** Seven rules for the case where your project is not the end of the line:' > "$SB_TMP/known-bad.md"
  grep -qiE "$pat" "$SB_TMP/known-bad.md" \
    || _fixture_die "case_doctrine_states_no_rule_count: the pattern does not match a known-bad line, so it would report a clean corpus whatever the sheets said."

  local bad
  bad="$( { grep -rniE "$pat" "$dd" 2>/dev/null || true; } )"
  [ -z "$bad" ] \
    || cf "a doctrine sheet writes a count of its own rule set — the § A headings ARE the list, and the sheets that already carry this repair say why: $(printf '%s' "$bad" | tr '\n' '|')"

  finish "no doctrine sheet's class line or adopt line writes a count of its own rule set ($n sheets scanned; MID-SECTION introducers like 'What keeps it honest:' are NOT covered by this pattern — a wider one fires on a named single rule and on a ratio, both legitimate and both present)"
  teardown
}

# ── THE CLI-SHAPE EXEMPT CLASSES, derived ONCE. ──────────────────────────────
# Two cases need to know which shipped programs the CLI shape does not bind, and two copies of a
# derivation is the defect both of them exist to catch. The classes and their admission tests are
# authored in process/contracts/issue-creation.md § 3, between markers rather than anchored on
# prose — contracts/README.md's block carries the note explaining why, and it was paid for there.
# Prints one prefix per line; empty output is the caller's problem to refuse, loudly, because with
# none derived every hook reads as a violation and with the wrong block read every tool reads as
# exempt. Both are silent.
_cli_exempt_prefixes() {
  local sheet="$REAL_REPO_ROOT/process/contracts/issue-creation.md"
  [ -f "$sheet" ] || return 0
  awk '/CLI-SHAPE-EXEMPT-CLASSES:BEGIN/,/CLI-SHAPE-EXEMPT-CLASSES:END/' "$sheet" \
    | grep -oE '`[.a-z][a-z._/-]*`' | tr -d '`' | sort -u
}

# ── WHAT COUNTS AS A SHIPPED PROGRAM, and HOW IT IS INVOKED. ─────────────────
# ONE derivation, because the case below needs the answer TWICE — once to walk the population and
# once to make the balance accounting add up — and two copies of a predicate is how a widening
# lands at one site and not the other. This function is the single place the shape is decided.
#
# THE PREDICATE WAS `^#!.*sh$` AND THAT IS SHELL-SHAPED. The five Python tools under
# scripts/hygiene/ open `#!/usr/bin/env python3`, so they matched no population AND no exempt
# class: not bound, not exempt, not disclosed, and invisible to the coverage-shrink assertion
# above, which only watches the exemptions for rot and cannot see the population under-reach.
# They are BOUND by issue-creation.md's own admission test — "could this program ever receive an
# option from a human or from a script a human wrote?" — and all five parse flags with argparse.
#
# AND A WIDENED MATCH ALONE IS NOT THE FIX; IT IS FIVE FALSE REDS. The case executes its operands
# DIRECTLY. Those five carry a shebang and are deliberately NOT executable — that half was measured
# separately and the mode stays off, with the reason recorded at build-kit.sh's bit guard — so
# running them directly exits 126 and the case reports "--help exited 126" over five tools that in
# fact comply. **The widening therefore owes an INVOCATION FORM DERIVED FROM THE SHEBANG**, which
# is what this returns: a non-executable shebang file is run through its interpreter.
#
# Prints the argv prefix to invoke <file> with, or nothing if <file> is not a shipped program.
_cli_invocation() {  # <abs-path-in-real-tree> — echoes the command prefix, or nothing
  local sb; sb="$(head -1 "$1" 2>/dev/null)"
  case "$sb" in
    '#!'*sh)      echo "SHELL" ;;        # a POSIX-shell program — executed directly
    '#!'*python3*) echo "python3" ;;     # run through its interpreter; the mode bit stays off
    '#!'*python*)  echo "python" ;;
    *)            : ;;                   # not a program at all
  esac
}

case_cli_shape_across_the_shipped_set() {
  cf_reset
  make_sandbox
  publish_sandbox

  # ── THE POPULATION IS THE MANIFEST, AND THE EXEMPTIONS ARE THE CONTRACT'S OWN. ──────────────
  #
  # This walked `scripts/*.sh` with two exemptions TYPED HERE — config.sh and notify-hook.sh. Both
  # halves were wrong in ways that only showed on a tree that had lived:
  #
  #   * the glob is the adopter's directory, so on an adopted tree it judged the gate runner SEED
  #     told them to write against the kit's CLI contract, and reported the kit's own contract
  #     violated by a file the kit does not ship;
  #   * the glob never saw scripts/hooks/, scripts/notify/, consumers/ or setup.sh, so seven
  #     shipped programs were outside a case whose finish line said "across the shipped set";
  #   * and the exemption was a NAME LIST in the test, which is the shape this workstream exists
  #     to remove. A name list in a test is a place where "not covered" and "not applicable" are
  #     spelled the same.
  #
  # So: the population is derived from process/KIT-MANIFEST, and what the shape does NOT bind is
  # derived from issue-creation.md's own CLI-SHAPE-EXEMPT-CLASSES block — the contract that states
  # the rule is where its boundary belongs, and contracts/README.md's equivalent block is the
  # precedent this copies, markers and all.
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  local sheet="$REAL_REPO_ROOT/process/contracts/issue-creation.md"
  [ -f "$man" ] \
    || _fixture_die "case_cli_shape_across_the_shipped_set: process/KIT-MANIFEST is absent, which the startup guard should already have refused."
  [ -f "$sheet" ] \
    || _fixture_die "case_cli_shape_across_the_shipped_set: process/contracts/issue-creation.md is absent — with no exempt classes derived, every hook and library would look like a contract violation."

  local exempt
  exempt="$(_cli_exempt_prefixes)"
  [ -n "$exempt" ] \
    || _fixture_die "case_cli_shape_across_the_shipped_set: could not derive the exempt classes out of issue-creation.md's CLI-SHAPE-EXEMPT-CLASSES block. With none derived every hook and library reads as a violation; with the derivation reading the wrong block every tool reads as exempt. Both are silent."

  # ── AN OVER-BROAD PREFIX EXEMPTS THE WHOLE TREE, AND EVERY OTHER ARM HERE READS IT AS HEALTH.
  #    The derivation harvests BACKTICKED PATHS out of the block, so a backticked NON-path in that
  #    prose is collected as one. That happened: class 2 wrote the shell's sourcing operator as a
  #    backticked single dot, the derived set gained a bare `.`, and a `.` prefix matches every
  #    shipped file — so every tool was exempt and this case still reported a healthy population.
  #    Note which way the failure points: the stale-prefix arm below cannot see it, because an
  #    over-broad prefix matches MORE than something, and the population arm cannot see it either,
  #    because exempting everything leaves no violations to find. A defect that silences two checks
  #    by satisfying both needs its own.
  local e
  for e in $exempt; do
    case "$e" in
      */) : ;;                       # a directory prefix is the normal shape
      *.sh|*.md|*/*) : ;;            # a specific file, or any path with a separator
      *) cf "issue-creation.md's CLI-SHAPE-EXEMPT-CLASSES block yields the exempt prefix '$e', which names no directory and no file — a prefix this broad matches most of the tree and silently exempts it from the CLI shape. Almost certainly a backticked NON-path in that block's prose (the sourcing operator, a flag, a bare extension) being harvested as a path: spell it as a word instead of in backticks. Nothing between those markers may put a non-path in backticks." ;;
    esac
  done

  # ── THE SECOND DIRECTION, and it is why an exemption cannot rot here: every prefix the contract
  #    declares must still match something the kit ships. A class that quietly matches nothing is
  #    coverage shrinking with nothing red to show it.
  local stale=""
  for e in $exempt; do
    grep -v '^#' "$man" | awk '{print $2}' | grep "^${e}" >/dev/null \
      || stale="$stale $e"
  done
  [ -z "$stale" ] \
    || cf "issue-creation.md exempts path prefix(es) the kit no longer ships —$stale. An exemption naming nothing is coverage shrinking silently; delete the class deliberately or restore the file"

  local rel f base out rc n=0 skipped=0 skiplist="" unreached=0 unreachedlist=""
  # ── THE DISCLOSURE OPERANDS, and this is the half the population attack asked for. The
  #    coverage-shrink assertion above watches the EXEMPTIONS for rot; nothing watched the
  #    POPULATION for under-reach, which is how five shipped programs sat in no class at all.
  #    So the finish line now says which invocation shapes were walked and, by name, every
  #    shebang-carrying manifest entry this predicate does NOT know how to invoke. A program
  #    added in a sixth language becomes a NAMED outspan instead of a silent absence.
  local shapes="" outspan=""
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    # THE SHEBANG IS READ FROM THE REAL TREE, the execution happens in the SANDBOX. Reading it
    # from the sandbox would make a file the sandbox does not carry indistinguishable from a file
    # that is not a program — and that is how a third of this case's population went missing
    # without a word: `[ -f "$SB_WORK/$rel" ] || continue` silently dropped consumers/, setup.sh
    # and the skill helpers while the finish line went on saying "across the shipped set".
    # THE SHEBANG IS READ FROM THE REAL TREE (see above), and it decides BOTH membership and the
    # invocation form. `_cli_invocation` is the one place that mapping lives.
    local interp; interp="$(_cli_invocation "$REAL_REPO_ROOT/$rel")"
    if [ -z "$interp" ]; then
      # NOT A PROGRAM, or a program in a language this predicate does not know. The two are
      # distinguished by the shebang, and only the second is disclosed — silence is what this
      # attack was about.
      case "$(head -1 "$REAL_REPO_ROOT/$rel" 2>/dev/null)" in
        '#!'*) outspan="$outspan ${rel}" ;;
      esac
      continue
    fi
    case " $shapes " in *" $interp "*) : ;; *) shapes="$shapes $interp" ;; esac

    local skip=0
    for e in $exempt; do case "$rel" in "$e"*) skip=1 ;; esac; done
    if [ "$skip" -eq 1 ]; then skipped=$(( skipped + 1 )); skiplist="$skiplist $rel"; continue; fi

    # BOUND, but is it REACHABLE? These tools are EXECUTED, so they run in the sandbox rather than
    # in the real tree — a usage request is contracted not to do work, but a tool that VIOLATES the
    # contract is exactly what this case looks for, and running one for real is how a test mutates
    # the tree it is judging. The sandbox does not carry the whole shipped set, so some bound tools
    # cannot be reached. They are COUNTED AND NAMED rather than skipped: an unreachable operand is
    # a hole in the coverage, and the difference between naming it and dropping it is the whole
    # subject of this workstream.
    f="$SB_WORK/$rel"
    if [ ! -f "$f" ]; then
      unreached=$(( unreached + 1 )); unreachedlist="$unreachedlist $rel"; continue
    fi

    base="$(basename "$f")"
    n=$((n+1))

    # INVOKED BY THE FORM ITS OWN SHEBANG DECLARES. A shell program runs directly; an
    # interpreted one that is deliberately non-executable runs through its interpreter, which
    # is how the kit invokes it everywhere. Executing the latter directly exits 126 — a false
    # red against a tool that complies, which is the trap this split exists to avoid.
    #    Held as two explicit words rather than an argv array: this harness is POSIX sh, which
    #    has no arrays, and reusing the positional parameters here would be a trap for the next
    #    edit that gives this case an argument.
    local iv_cmd iv_arg
    if [ "$interp" = "SHELL" ]; then iv_cmd="$f"; iv_arg=""; else iv_cmd="$interp"; iv_arg="$f"; fi
    if [ -n "$iv_arg" ]; then
      out="$( cd "$SB_WORK" && PYTHONDONTWRITEBYTECODE=1 "$iv_cmd" "$iv_arg" --help </dev/null 2>&1 )"; rc=$?
    else
      out="$( cd "$SB_WORK" && "$iv_cmd" --help </dev/null 2>&1 )"; rc=$?
    fi
    [ "$rc" -eq 0 ] || cf "$rel --help exited $rc — a usage request must ALWAYS succeed (§ 3)"
    # NAMING ITSELF IS THE EFFECT ASSERTION. An rc-only check passes vacuously on a tool
    # that has no --help arm at all and simply does its job: that is exactly how
    # next-id.sh answered a usage request with a mintable id and looked fine.
    printf '%s\n' "$out" | grep -F "$base" >/dev/null \
      || cf "$rel --help exited 0 but its output never names $base — this is satisfied by a tool with no usage handler that just ran: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"

    if [ -n "$iv_arg" ]; then
      out="$( cd "$SB_WORK" && PYTHONDONTWRITEBYTECODE=1 "$iv_cmd" "$iv_arg" --not-a-real-flag </dev/null 2>&1 )"; rc=$?
    else
      out="$( cd "$SB_WORK" && "$iv_cmd" --not-a-real-flag </dev/null 2>&1 )"; rc=$?
    fi
    [ "$rc" -eq 2 ] \
      || cf "$rel: an unrecognised option exited $rc, want 2 — § 3 names ONE status across the shipped set: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    printf '%s\n' "$out" | grep -F -- '--not-a-real-flag' >/dev/null \
      || cf "$rel: the refusal does not NAME the option it refused (§ 3), so the caller cannot tell which flag was wrong: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF

  # ── INSTRUMENT CHECKS. Neither is a typed floor: both are comparisons over the derived set.
  [ "$n" -gt 0 ] \
    || _fixture_die "case_cli_shape_across_the_shipped_set: not one bound tool was found in the manifest — the case would report PASS over an empty set."
  [ "$skipped" -gt 0 ] \
    || cf "(instrument) not one manifest path matched an exempt class, though the contract declares several — the prefix match stopped working, and every tool is now being judged including the ones the contract says are not bound"
  # ── THE ACCOUNTING IS DERIVED AND MUST BALANCE. Every shipped shell program is exactly one of:
  #    exempt by a declared class, exercised here, or bound-but-unreachable-in-the-sandbox. If the
  #    three do not sum to the population, a member fell out of the walk without a word, which is
  #    the failure mode this case has just been rewritten out of.
  #    THE SECOND DERIVATION SITE. It recomputes the population, so it must use the SAME
  #    predicate as the walk or the widening lands at one site and the balance reds for a
  #    reason having nothing to do with the tools. `_cli_invocation` is that predicate.
  local shellprogs=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -n "$(_cli_invocation "$REAL_REPO_ROOT/$rel")" ] && shellprogs=$(( shellprogs + 1 ))
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF
  [ "$(( n + skipped + unreached ))" -eq "$shellprogs" ] \
    || cf "(instrument) the population does not balance: $shellprogs shipped shell program(s), but $n exercised + $skipped exempt + $unreached unreachable = $(( n + skipped + unreached )). A member left the walk without being counted"

  # ── TWO TARGETED PROBES, because the generic one above CANNOT REACH THESE PATHS and a
  #    mutation test proved it: reverting either fix left the sweep green.
  #
  #    notify.sh dispatches on its first argument as a CLASS, so `--not-a-real-flag`
  #    alone is refused by the class arm and the OPTION LOOP is never entered. That loop
  #    is where a stray flag used to be warned about and IGNORED — the message delivered,
  #    exit 0. A refusal that reads as success needs a probe that gets that far.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/notify.sh" done "a message" --session s --not-a-real-flag </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] \
    || cf "notify.sh: a stray option AFTER a valid class exited $rc, want 2 — it is being ignored and the notification is delivered anyway, which is a refusal that reads as success: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  #    move-issue.sh takes positionals, so a dash-leading token is caught BEFORE the
  #    option loop or it becomes the issue id and dies on the arity check instead —
  #    refused with the status a MISSING ARGUMENT gets, never naming the flag.
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" --not-a-real-flag in_progress --role Dev </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] \
    || cf "move-issue.sh: a dash-leading FIRST token exited $rc, want 2 — it was taken as the issue id rather than refused as an option: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -F -- '--not-a-real-flag' >/dev/null \
    || cf "move-issue.sh: the refusal does not name the dash-leading token it refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── INSTRUMENT CHECK. Both probes above must be capable of FAILING. A script with no
  #    argument handling whatsoever must fail both — written OUTSIDE scripts/ so the
  #    glob above cannot pick it up and turn the control into a subject.
  local probe="$SB_TMP/no-handlers.sh"
  printf '#!/usr/bin/env bash\necho ok\n' > "$probe"; chmod +x "$probe"
  out="$( "$probe" --help </dev/null 2>&1 )"
  printf '%s\n' "$out" | grep -F 'no-handlers.sh' >/dev/null \
    && cf "(control) the --help probe PASSED a script with no usage handler — it is measuring nothing"
  out="$( "$probe" --not-a-real-flag </dev/null 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] \
    && cf "(control) the refusal probe PASSED a script with no argument handling — it is measuring nothing"

  finish "the CLI shape across the shipped set: every tool's usage request exits 0 and names the tool, and every unrecognised option exits 2 and names the option — asserted over $n tool(s) DERIVED FROM process/KIT-MANIFEST, so a file the adopter was told to add is not judged against our contract. NOT BOUND, and derived from issue-creation.md's own CLI-SHAPE-EXEMPT-CLASSES block rather than typed here — $skipped shipped program(s) in the declared classes (protocol-invoked, sourced, vendored):$skiplist. Every declared prefix was asserted to still match something. NOT EXERCISED, and this is a HOLE rather than an exemption — $unreached bound tool(s) the sandbox does not carry, so nothing here judged them:${unreachedlist:- (none)}. THE POPULATION IS EVERY MANIFEST ENTRY WHOSE SHEBANG NAMES AN INVOCATION FORM THIS CASE KNOWS, invoked by that form — shape(s) walked:${shapes:- (none)}; a shell program is executed directly, an interpreted one that is deliberately non-executable is run through its interpreter. NOT REACHED BY THE PREDICATE AT ALL, named rather than dropped, because a population that under-reaches is silent in a way an exemption never is — shebang-carrying manifest entr(ies) in a language this case cannot invoke:${outspan:- (none)}"
  teardown
}

# =============================================================================
# CASE — EVERY HYGIENE INSTRUMENT DECLARES ITS BLIND SPOTS, AND THE LIST IS NOT EMPTY
#
# THE CLAIM AN EMPTY LIST MAKES. `--json` emits `"blind_spots": [...]`, and a consumer
# reads `[]` as *this walk has no blind spots*. That has never been true of this walker:
# it skips symlinks and it prunes a directory set, and it does both in the very run that
# would print the empty list. **The human path degrades to silence; the machine path
# degrades to a false claim about the subject** — silence is a gap a reader may notice,
# `[]` is an answer they will not question.
#
# WHY ONE CASE COVERS EVERY INSTRUMENT, and why that is the point rather than a saving:
# the notice is derived from ONE authoring site, which is a property worth having — and
# the cost of it is that a single edit empties every consumer AT ONCE. This case is that
# cost's control: the ablation below must redden every instrument simultaneously, and if
# it ever reddens only some, the single authoring site has quietly become several.
#
# PYTHON IS THESE INSTRUMENTS' DECLARED CARVE-OUT, so an absent interpreter SKIPS with
# its reason and never fails — the kit assumes git and a POSIX shell, and these are
# advisory instruments that say so.
#
# PYTHONDONTWRITEBYTECODE, because a run that leaves __pycache__ behind mutates the tree
# it was measuring, and the isolation case would then report the harness as the mutator.
#
# --root IS PASSED EXPLICITLY, and that is not belt-and-braces. These instruments default
# their root to `Path(__file__).resolve().parents[2]` — the tree is inferred from where
# the FILE SITS, not from what is being measured. The ablation copy below deliberately
# sits somewhere else, and at that depth the default resolves to the whole scratch area:
# measured, a copy two directories shallower walked /private/tmp and had to be killed.
# Naming the root makes the operand a fact of the invocation instead of an accident of
# the path, and it is the difference between this case measuring the sandbox and this
# case hanging the suite.
# =============================================================================
case_hygiene_instruments_declare_blind_spots() {
  cf_reset
  if ! command -v python3 >/dev/null 2>&1; then
    skp "hygiene instruments declare their blind spots" "python3 absent — these are advisory instruments and Python is their declared carve-out"
    return
  fi
  make_sandbox
  seed_issue todo "$SB_PREFIX-310" hygiene chore "Hygiene blind-spot probe"
  publish_sandbox   # cold_signal reads git history, so the sandbox must have some

  local hy="$SB_WORK/scripts/hygiene" inst n_inst=0 empty="" missing="" broke=""
  if [ ! -d "$hy" ]; then
    skp "hygiene instruments declare their blind spots" "scripts/hygiene/ absent — this kit ships no advisory instruments"
    teardown; return
  fi

  # THE LIST IS DERIVED, never typed: a new instrument is covered the day it lands.
  local instruments; instruments="$(cd "$hy" && ls ./*.py 2>/dev/null | sed 's@^\./@@' | sort)"
  [ -n "$instruments" ] \
    || _fixture_die "case_hygiene_instruments_declare_blind_spots: scripts/hygiene/ contains no *.py — the scan lost its operand rather than finding a clean set."

  for inst in $instruments; do
    n_inst=$(( n_inst + 1 ))
    local out rc
    out="$( cd "$SB_WORK" && PYTHONDONTWRITEBYTECODE=1 python3 "$hy/$inst" --root "$SB_WORK" --json 2>&1 )"; rc=$?
    if [ "$rc" -ne 0 ]; then broke="$broke $inst"; continue; fi
    # The payload is an object, and it CARRIES the key — a missing key is a different
    # defect from an empty one and must not be reported as the same thing.
    if ! printf '%s' "$out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,dict) and "blind_spots" in d else 1)' 2>/dev/null; then
      missing="$missing $inst"; continue
    fi
    printf '%s' "$out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["blind_spots"] else 1)' 2>/dev/null \
      || empty="$empty $inst"
  done

  # WORDED FOR WHAT IT CATCHES, not for what was first imagined. This bucket was written
  # as "could not be read", which is now a FALSE sentence about the case it actually fires
  # on: measured with the walker ablated, every instrument exited non-zero while
  # emitting a clean, parseable JSON refusal. The payload was readable. What makes it
  # unusable here is that a refusal is not a blind-spot REPORT, and no declaration can be
  # read out of one — so the exit code, not the readability, is the whole of the finding.
  [ -z "$broke" ]   || cf "instrument(s) exited non-zero under --json:$broke — the payload may be perfectly readable; a non-zero exit makes it a REFUSAL rather than a blind-spot report, and a declaration cannot be read out of a refusal"
  [ -z "$missing" ] || cf "instrument(s) emitted a payload with no 'blind_spots' key:$missing — a missing key is not an empty list, and removing the key would turn a false claim into a missing one"
  [ -z "$empty" ]   || cf "instrument(s) reported \"blind_spots\": [] :$empty — that asserts THERE ARE NONE, and this walker skips symlinks and prunes a directory set in the very run that printed it"

  # ── THE ABLATION, on a COPY of the tree the instruments read — never the real one.
  # THE SINGLE-AUTHORING-SITE DERIVATION is what is under test here: one site means one
  # edit reaches every consumer, so the ablation must reach ALL of them, not some.
  local probe="$SB_TMP/hygiene-probe"; rm -rf "$probe"; mkdir -p "$probe"
  cp -R "$hy" "$probe/hygiene" 2>/dev/null
  local site="$probe/hygiene/citation_index.py"
  if [ ! -f "$site" ]; then
    _control_did_not_run "copy the derivation's authoring site"
  else
    # EMPTY THE DERIVATION, DO NOT BYPASS IT. Inserting `return []` at the top of the
    # function skips the refusal that an empty derivation is supposed to raise — so the
    # instruments went back to printing an empty list and NONE of them refused, which
    # this case then correctly reported as "0 of 5". The ablation has to leave the
    # emptiness check reachable and give it nothing to find.
    perl -0777 -i -pe 's{\n    lines = \[}{\n    lines = []\n    _ablated_unused = [}' "$site"
    if ! grep -qF '_ablated_unused' "$site"; then
      cf "(control) the ablation did not take on the copy — the anchor moved, so nothing below establishes that the assertion can fire"
    else
      # EVERY DERIVED INSTRUMENT LANDS IN EXACTLY ONE BUCKET, AND THE BUCKETS ARE
      # RECONCILED AGAINST THE COUNT. This loop used to `|| continue` on a non-zero exit,
      # which silently dropped that instrument from both buckets — so with one probe copy
      # made to fail, the case reported "empties all of them at once" over four of five
      # and stayed green. A control with a hole in its accounting is a green that could
      # not go red, inside the control written against exactly that.
      #
      # THE FLAT SIGNAL IS A REFUSAL, NOT AN EMPTY LIST. An empty derivation is the
      # INSTRUMENT failing, so it exits 2 and emits an object whose only top-level key is
      # the unrunnable one — the UNRUNNABLE vocabulary, not the report's. `blind_spots:
      # []` is a payload that can no longer occur, and an arm still hunting it would pass
      # by never finding what it was looking for.
      #
      # A CRASH IS ITS OWN BUCKET, named in its own word: a traceback or an unparseable
      # payload is neither a refusal nor a healthy report, and folding it into either
      # would let the loudest failure mode read as one of the quiet ones.
      local flat=0 still=0 crashed=0 a_out a_rc
      local still_names="" crash_names=""
      for inst in $instruments; do
        a_out="$( cd "$SB_WORK" && PYTHONDONTWRITEBYTECODE=1 python3 "$probe/hygiene/$inst" --root "$SB_WORK" --json 2>/dev/null )"; a_rc=$?
        if ! printf '%s' "$a_out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
          crashed=$(( crashed + 1 )); crash_names="$crash_names $inst"
        elif [ "$a_rc" -eq 2 ] && printf '%s' "$a_out" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json,sys
d = json.load(sys.stdin)
sys.exit(0 if isinstance(d, dict) and list(d) == ["unrunnable"] else 1)' 2>/dev/null; then
          flat=$(( flat + 1 ))
        else
          still=$(( still + 1 )); still_names="$still_names $inst"
        fi
      done

      # THE RECONCILIATION, and it is the assertion the old loop lacked entirely.
      [ $(( flat + still + crashed )) -eq "$n_inst" ] \
        || cf "(control) the ablation accounted for $(( flat + still + crashed )) instrument(s) of $n_inst — some landed in no bucket at all, so any claim below is about a subset nobody enumerated"
      [ "$crashed" -eq 0 ] \
        || cf "(control) ablating the derivation made instrument(s) CRASH rather than refuse:$crash_names — a traceback is the instrument failing in the wrong vocabulary, which is a different defect from the one this case asserts"
      [ "$flat" -gt 0 ] \
        || cf "(control) ablating the derivation made NO instrument refuse — the assertion above cannot fire and is a green that could not go red"
      # NAME THE INSTRUMENTS THAT DID NOT GO FLAT. A count tells the maintainer that the
      # single authoring site has split; only the names tell them which file drifted, and
      # that is the whole of what they need next.
      [ "$still" -eq 0 ] \
        || cf "(control) ablating the single authoring site did not reach:$still_names ($flat of $n_inst refused) — the derivation is no longer one site, which is the property this case exists to protect"
    fi
  fi

  finish "every hygiene instrument declares its blind spots and the list is NON-EMPTY ($n_inst instrument(s): $(printf '%s' "$instruments" | tr '\n' ' ')) — an empty list asserts THERE ARE NONE, which is a false claim about the subject — and ablating the single derivation empties all of them at once"
  teardown
}

# =============================================================================
# CASE — A NON-ASCII FILENAME SURVIVES THE COLD-SIGNAL HISTORY WALK.
#
# THIS ASSERTS BEHAVIOUR, NOT A MEASUREMENT, and the distinction is cold_signal.py's own
# header rule: "the line is between asserting what it MEASURED and asserting how it
# BEHAVES." Nothing here reads a commit count, a horizon or a suspicion set — it asks one
# question about the walk's KEYS: does the key for a file whose name carries a byte outside
# ASCII come back as the file's real name, the way `citation_index.iter_files()` spells it?
# That is a property of the instrument, deterministic on a seeded repository, and it is the
# only shape in which this defect is testable at all.
#
# WHAT IT GUARDS. `git log --name-only` under git's DEFAULT `core.quotePath=true` returns
# `café.md` as the C-quoted, DOUBLE-QUOTED string `"caf\303\251.md"` — the surrounding quotes
# are part of the key, which is why the lookup misses even after the escapes are decoded.
# `survey()` looks the walk's paths up in that dictionary, misses, and drops the file
# BEFORE any threshold runs. The instrument then prints a confident answer that is short by
# however many non-ASCII paths the tree holds. AN UNDER-COUNT THAT LOOKS LIKE AN ANSWER is
# the one failure mode this instrument's own header forbids it, and it left no trace: no
# warning, no non-zero exit, no UNRUNNABLE.
#
# WHY THE FIXTURE FILE IS SEEDED HERE AND NOT REUSED FROM THE BOARD. The sandbox's seeded
# cards are ASCII, and they should stay that way — a suite whose ordinary fixtures carry
# accents would be testing this everywhere and nowhere. The probe file is planted,
# committed and asserted present, so a failure names the fixture rather than the tool.
#
# THE ABLATION IS THE POINT. A guard is not armed until its ablation is an artifact: this
# case copies the instrument, strips the two `-c core.quotePath=false` arguments from the
# invocation, and requires the SAME probe to go red on the copy. Without that, a green here
# proves only that the harness can run python3. The real tree is never mutated.
#
# PYTHON IS THESE INSTRUMENTS' DECLARED CARVE-OUT, so an absent interpreter SKIPS with its
# reason — the kit's floor is git and a POSIX shell.
# =============================================================================
case_cold_signal_reads_non_ascii_paths() {
  cf_reset
  if ! command -v python3 >/dev/null 2>&1; then
    skp "the cold-signal walk keys a non-ASCII path by its real name" "python3 absent — these are advisory instruments and Python is their declared carve-out"
    return
  fi
  make_sandbox
  local hy="$SB_WORK/scripts/hygiene"
  if [ ! -f "$hy/cold_signal.py" ]; then
    skp "the cold-signal walk keys a non-ASCII path by its real name" "scripts/hygiene/cold_signal.py absent — this kit ships no cold-signal instrument"
    teardown; return
  fi

  # THE FIXTURE, and it is asserted rather than assumed. A filesystem that normalises or
  # rejects the name would otherwise make this case green by having no subject.
  local probe_name='café.md'
  printf 'seeded so the walk has a non-ASCII path to key\n' > "$SB_WORK/$probe_name"
  [ -f "$SB_WORK/$probe_name" ] \
    || _fixture_die "case_cold_signal_reads_non_ascii_paths: could not create '$probe_name' in the sandbox — this filesystem did not keep the name, so there is no subject to measure."
  publish_sandbox   # the walk reads git history, so the path must be COMMITTED, not just present
  git -C "$SB_WORK" log --name-only --format= -- "$probe_name" | /usr/bin/grep -q . \
    || _fixture_die "case_cold_signal_reads_non_ascii_paths: '$probe_name' is not in the sandbox's history after publish_sandbox — the walk would correctly report nothing and this case would assert it."

  # THE PROBE, written once and run against two trees: the shipped instrument and the
  # ablated copy. It prints one word — the key's fate — and asserts nothing itself, so the
  # shell below owns both the green and the red.
  local probe_py="$SB_TMP/non-ascii-probe.py"
  cat > "$probe_py" <<'PY'
import sys
from pathlib import Path
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from cold_signal import git_history
stats = git_history(Path(sys.argv[2]))
print("HIT" if sys.argv[3] in stats else "MISS")
PY

  local seen
  seen="$( PYTHONDONTWRITEBYTECODE=1 python3 "$probe_py" "$hy" "$SB_WORK" "$probe_name" 2>&1 )" || seen="probe failed: $seen"
  [ "$seen" = "HIT" ] \
    || cf "the shipped cold_signal.py keyed '$probe_name' as something other than its real name (probe said: $seen) — under git's default core.quotePath=true the key is the C-quoted \"caf\\303\\251.md\", survey() misses it, and the file is dropped before any threshold, so the instrument UNDER-COUNTS while printing a confident answer"

  # ── THE ABLATION, on a COPY. Strip the two `-c core.quotePath=false` arguments from the
  # invocation ONLY — the docstring that explains them is left alone, because removing the
  # explanation is not the defect and a copier who deleted the flag would not have deleted
  # the paragraph either.
  local ab="$SB_TMP/cold-signal-ablated"; rm -rf "$ab"; mkdir -p "$ab"
  cp -R "$hy/." "$ab/" 2>/dev/null
  if [ ! -f "$ab/cold_signal.py" ]; then
    _control_did_not_run "copy scripts/hygiene/ for the ablation"
  else
    perl -0777 -i -pe 's/"-c", "core\.quotePath=false",\n\s*//' "$ab/cold_signal.py"
    if /usr/bin/grep -q '"-c", "core.quotePath=false"' "$ab/cold_signal.py"; then
      cf "(control) the ablation did not take on the copy — the invocation's arguments did not match the anchor, so nothing above establishes that the assertion can fire"
    else
      local ab_seen
      ab_seen="$( PYTHONDONTWRITEBYTECODE=1 python3 "$probe_py" "$ab" "$SB_WORK" "$probe_name" 2>&1 )" || ab_seen="probe failed: $ab_seen"
      [ "$ab_seen" = "MISS" ] \
        || cf "(control) stripping -c core.quotePath=false from the copy did NOT lose '$probe_name' (probe said: $ab_seen) — the assertion above is a green that could not go red, so either git's default changed or the flag is no longer what carries the name"
    fi
  fi

  finish "the cold-signal history walk keys the non-ASCII path '$probe_name' by its real name, and stripping -c core.quotePath=false from a copy loses it"
  teardown
}

# =============================================================================
# CASE — EVERY TRAVELLING SCRIPT HAS A SHEET OR SITS IN A NAMED EXEMPT CLASS.
#
# contracts/README.md states the rule in both directions. THIS one — every travelling script has
# a sheet — was unguarded, and is what this case closes. The MIRROR direction (every path a sheet
# cites still exists) is STILL UNGUARDED: this comment claimed it was already covered, and no such
# case exists anywhere in the suite. contracts/README.md says the same, correctly.
# contracts/README.md said so in as many words: "nothing checks that a travelling script
# has a sheet… the guard is the PROJECT's, not the kit's… the contracts travel, a guard
# over them does not."
#
# THAT LAST CLAUSE IS SUPERSEDED BY THIS CASE, and the reason it was written is worth
# keeping: a guard needs the project's own file set, which the kit does not have. But this
# harness SHIPS and runs inside the project's tree, so it does have it — the obstacle was
# never that the guard could not travel, only that nothing carrying it did.
#
# THE EXEMPT CLASSES ARE DERIVED FROM THE RULE'S OWN TEXT, not listed here. A second
# hand-typed list of exemptions is the defect this whole directory is about.
# =============================================================================
case_travelling_scripts_have_a_sheet() {
  cf_reset
  make_sandbox
  # The REAL tree: make_sandbox does not copy process/, and a case that skips because its
  # own operand is absent from the fixture is a skip about the fixture, not the project.
  local readme="$REAL_REPO_ROOT/process/contracts/README.md"
  local cdir="$REAL_REPO_ROOT/process/contracts"
  [ -f "$readme" ] && [ -d "$cdir" ] \
    || { skp "every travelling script has a sheet or a named exemption" "process/contracts/ is absent — this project does not carry the contract set"; teardown; return; }

  # THE OPERAND IS EVERY TRAVELLING SCRIPT, NOT scripts/ ALONE, AND BOTH COMMENT SYNTAXES.
  # This walked $REAL_SCRIPTS with `^# KIT-CLASS:` only — narrower than the rule it enforces in
  # exactly the two ways contracts/README.md's own recipe warns about, so consumers/ was invisible
  # to the guard that claims to cover every travelling script.
  #
  # THE EXEMPT PREFIXES, derived from the rule's own bullet rather than retyped. Each class
  # is named there as a NUMBERED ITEM carrying a backticked path prefix.
  local exempt n=0 judged=0 skipped=0 miss="" f rel items=0
  # THE OPERAND IS THE NUMBERED ITEMS, NOT EVERY BACKTICK BETWEEN THE MARKERS.
  # It was every backtick, and that made the block's own PROSE an operand of the guard the
  # block constrains. Measured: one ordinary sentence inside the markers reading "a line
  # naming `scripts/` here would exempt everything" put `scripts/` into the derived class
  # list, which exempts the ENTIRE travelling population — and the case still finished
  # green, having judged one file of forty-six. The note WARNING about the hazard BECAME
  # the hazard. A class is now declared only by a numbered item, so prose between the
  # markers is inert and the hazard note lives outside them.
  exempt="$(awk '/EXEMPT-CLASSES:BEGIN/,/EXEMPT-CLASSES:END/' "$readme" \
            | grep -E '^[[:space:]]+[0-9]+\.[[:space:]]' \
            | grep -oE '`[a-z][a-z-]*/([a-z-]+/)?`' | tr -d '`' | sort -u)"
  items="$(awk '/EXEMPT-CLASSES:BEGIN/,/EXEMPT-CLASSES:END/' "$readme" \
            | grep -cE '^[[:space:]]+[0-9]+\.[[:space:]]' || true)"
  # ANY top-level prefix, not `scripts/…` alone: the pattern was written when both exempt classes
  # happened to live under scripts/, so adding a third (consumers/) left it invisible to the guard
  # that reads this list — the extractor silently declining to see a class nobody could tell it about.
  # That widening is kept; what changed is WHICH LINES it is applied to.
  [ -n "$exempt" ] \
    || _fixture_die "case_travelling_scripts_have_a_sheet: could not derive the exempt classes out of contracts/README.md — with none derived every travelling script would look owed, and with the derivation reading the wrong block every one would look exempt."

  # ── THE NUMBERED ITEMS AND THE DERIVED CLASSES MUST RECONCILE. An item whose path lost its
  #    backticks is a class the reader believes is declared and the guard cannot see — coverage
  #    shrinking with nothing red to show it. Counted, not assumed.
  local nclass; nclass="$(printf '%s\n' $exempt | grep -c . || true)"
  [ "$items" -eq "$nclass" ] \
    || cf "contracts/README.md's EXEMPT-CLASSES block holds $items numbered item(s) but yields $nclass derived class(es). An item that names its path prefix in anything but backticks is invisible to this derivation while reading, to a person, exactly like a declared exemption"

  # ── AN OVER-BROAD PREFIX EXEMPTS THE WHOLE POPULATION AND EVERY OTHER ARM READS IT AS HEALTH.
  #    The sibling reader of issue-creation.md's CLI-SHAPE-EXEMPT-CLASSES block carries this arm
  #    and this one never has. A prefix naming no directory matches most of the tree.
  local e
  for e in $exempt; do
    [ -e "$REAL_REPO_ROOT/$e" ] \
      || cf "contracts/README.md declares the exempt class '$e', which names nothing this kit ships. Either the class is stale — coverage shrinking silently — or the prefix is mistyped, and a mistyped prefix that happens to be broad exempts files nobody decided to exempt"
  done

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#$REAL_REPO_ROOT/}"
    n=$(( n + 1 ))
    # Exempt by class? COUNT THE TWO POPULATIONS SEPARATELY. `n` used to be the whole walk and
    # the floor below was asserted against it, so a mass exemption could not move the number the
    # instrument check reads: exempting everything left `n` unchanged and the floor quiet. The
    # floor now guards the JUDGED population, which is the one the finish line's claim is about.
    local e2 skip=0
    for e2 in $exempt; do case "$rel" in "$e2"*) skip=1 ;; esac; done
    if [ "$skip" -eq 1 ]; then skipped=$(( skipped + 1 )); continue; fi
    judged=$(( judged + 1 ))
    # Cited by some sheet — literally, or in the placeholder form a sheet may legitimately
    # use for an adopter-instance path (notification.md's scripts/notify/<channel>.sh).
    grep -rqF "$rel" "$cdir" 2>/dev/null && continue
    grep -rqE "$(printf '%s' "${rel%/*}" | sed 's/[.[\*^$]/\\&/g')/<[a-z-]+>\.(sh|py)" "$cdir" 2>/dev/null && continue
    miss="$miss $rel"
  done <<EOF
$(grep -rlE '^(#|<!--) KIT-CLASS: (KIT|MIXED)' "$REAL_REPO_ROOT/scripts" "$REAL_REPO_ROOT/consumers" "$REAL_REPO_ROOT/setup.sh" 2>/dev/null | sort)
EOF

  [ -z "$miss" ] \
    || cf "these travelling scripts are cited by no contract sheet and sit in no named exempt class —$miss. Either the sheet is owed or the exemption is, and contracts/README.md is where the exemption goes so the next sweep finds a decision rather than a violation"

  # ── INSTRUMENT CHECK: a sweep that JUDGED no travelling scripts reports full coverage.
  #    Asserted against the JUDGED count, not the walked one. Against the walk it could not
  #    see a mass exemption at all — exempting every file leaves the walk the same size.
  [ "$judged" -ge 12 ] \
    || cf "only $judged travelling script(s) were JUDGED (of $n walked, $skipped skipped as exempt) — expected at least 12 judged. Either the KIT-CLASS marker or the glob changed, or an exempt class has grown wide enough to swallow the population, and in both cases 'every one is covered' is true of almost nothing"

  finish "every travelling (KIT/MIXED) script is either cited by a contract sheet — literally, or in the placeholder form a sheet may use for an adopter-instance path — or sits in one of the exempt classes contracts/README.md names. THE TWO POPULATIONS ARE REPORTED SEPARATELY, because a single 'all N' over a walk that includes the exempt reads as a judged population and is not one: $n walked, $judged JUDGED against the sheets, $skipped SKIPPED by ${nclass} declared exempt class(es) — the class list DERIVED from that rule's NUMBERED ITEMS rather than retyped, reconciled against the item count, and every declared prefix asserted to still name something this kit ships"
  teardown
}

# =============================================================================
# CASE — A VALUE-TAKING OPTION GIVEN NO VALUE REFUSES, WITH STATUS 2, AND SAYS SO.
#
# THE DEFECT WAS SILENT AND IT WAS EVERYWHERE. An arm written
# `--x) VAR="${2:-}"; shift 2 ;;` reads as safe — `${2:-}` cannot be unbound. But
# `shift 2` with one argument left RETURNS NON-ZERO, and under `set -e` that aborts:
# **exit 1, no message, nothing done.** Measured across the shipped set before the fix:
# 26 arms in six scripts behaved that way. The three creation scripts already had the
# guard and had had it all along, which is what made the gap invisible — the family that
# gets read most was the family that was correct.
#
# THE CENSUS IS STATIC AND THE PROBES ARE EXECUTED, and it needs both. A static census
# cannot know that `need_val` does anything; an executed probe covers one script. So:
# every value-taking arm calls the guard, every definition of the guard is identical, and
# two scripts are actually run.
# =============================================================================
# =============================================================================
# CASE — A TEMPLATE'S LINKS RESOLVE FROM WHERE IT LANDS, NOT FROM WHERE IT SITS.
#
# THIS CLASS WAS FIXED THREE TIMES, ONE INSTANCE AT A TIME, BEFORE ANYONE COUNTED IT.
# PRD.template.md, launch-pack, round-pack, then round-report and run-report — five of the
# fourteen shipped templates, found across three sweep rounds because each round reported
# the ones its checker happened to open. **A census would have found all five on day one**,
# and that is the whole reason this case exists rather than a sixth careful fix.
#
# WHY A LINK CHECK RUN IN THE KIT CANNOT SEE IT: the template SITS in process/templates/ and
# is COPIED to dev/launch/, requirements/, progress/todo/ … A link written for where it sits
# resolves perfectly here and is dead in every copy an adopter makes. It passes the obvious
# test and fails the only one that matters.
#
# THE DESTINATION IS DECLARED BY EACH TEMPLATE, and this case reads it from a header line
# rather than a table here — a table would be a fifteenth thing to keep in step.
# =============================================================================
case_template_links_resolve_from_their_destination() {
  cf_reset
  make_sandbox
  local probe="$SB_TMP/tmpl" t base dest n=0 bad=0
  # COPY THE WHOLE TREE, not the directories this case thinks it needs. Measured while
  # writing it: hand-picking process/ and .claude/ left requirements/ out and the case
  # reported CLAUDE-adapter.template.md's link to requirements/DECISIONS.md as broken — a
  # file that ships. **The probe was the defect**, and a link census whose corpus is
  # hand-listed will keep inventing findings about whatever the list forgot.
  rm -rf "$probe"; mkdir -p "$probe"
  ( cd "$REAL_REPO_ROOT" && tar cf - . 2>/dev/null ) | ( cd "$probe" && tar xf - 2>/dev/null ) || true
  [ -d "$probe/process/templates" ] \
    || { skp "a template's links resolve from where it LANDS" "process/templates/ is absent"; teardown; return; }

  # The landing directories a template names may not exist on a fresh tree (dev/rounds/<name>/
  # is minted per round); create them so a CORRECT link is not reported as broken.
  ( cd "$probe" && mkdir -p requirements progress/todo dev/launch dev/rounds/X docs ) >/dev/null 2>&1

  for t in "$probe"/process/templates/*.md "$probe"/.claude/templates/*.md; do
    [ -f "$t" ] || continue
    base="$(basename "$t")"
    # THE DESTINATION IS THE TEMPLATE'S OWN CLAIM. Only files that state one are checked;
    # a template with no declared destination is a different (and reported) problem.
    dest="$(sed -n 's|.*RELATIVE TO WHERE IT LANDS — \([^ ]*\) .*|\1|p' "$t" | head -1)"
    [ -n "$dest" ] || dest="$(sed -n 's|.*[Cc]opy \(it \)\?to `\([^`]*\)/[^/`]*`.*|\2|p' "$t" | head -1)"
    [ -n "$dest" ] || continue
    dest="$(printf '%s' "$dest" | sed 's|<[^>]*>|X|g; s|/$||')"
    [ -d "$probe/$dest" ] || mkdir -p "$probe/$dest"
    n=$(( n + 1 ))
    local miss
    miss="$(awk -v d="$probe/$dest" '
      { while (match($0, /\]\([^)#<]+\)/)) {
          l = substr($0, RSTART+2, RLENGTH-3); $0 = substr($0, RSTART+RLENGTH)
          if (l ~ /^http/ || l ~ /</) continue
          cmd = "test -e \"" d "/" l "\""
          if (system(cmd) != 0) printf "%s:%s ", FNR, l
      } }' "$t")"
    [ -z "$miss" ] || { bad=$(( bad + 1 )); cf "$base declares it lands in '$dest' and these links do not resolve from there: $miss — they resolve from process/templates/ instead, which is where the file SITS, so they pass a link check run in the kit and are dead in every copy an adopter makes"; }

    # ── THE CLIMB CHECK, for the links the resolver above SKIPS ────────────────────
    # It skips any link containing `<`, because a placeholder cannot be resolved on
    # disk. That exemption hid a real defect: SUBTASK.template.md declared it lands in
    # progress/todo/ when subtask.sh puts it four segments deep, and its ONLY link
    # carries a <status> placeholder — so the one template with a wrong destination was
    # the one whose links were entirely exempt from the check.
    #
    # A placeholder blocks resolution, not arithmetic. A link may climb no further than
    # its destination is deep: from a 2-segment destination, `../../../` leaves the
    # repository, and that is wrong whatever the placeholder expands to.
    local depth climb over
    depth="$(printf '%s' "$dest" | awk -F/ '{print NF}')"
    over="$(awk -v d="$depth" -v D="$dest" '
      { while (match($0, /\]\([^)#]+\)/)) {
          l = substr($0, RSTART+2, RLENGTH-3); $0 = substr($0, RSTART+RLENGTH)
          if (l ~ /^http/ || l !~ /^\.\.\//) continue
          c = 0; t = l
          while (t ~ /^\.\.\//) { c++; sub(/^\.\.\//, "", t) }
          if (c > d) printf "%s:%s(climbs %d from a %d-deep destination) ", FNR, l, c, d
      } }' "$t")"
    [ -z "$over" ] || { bad=$(( bad + 1 )); cf "$base declares it lands in '$dest' and these links climb ABOVE the repository root from there: $over"; }
  done

  # ── INSTRUMENT CHECK: a loop that resolved no destinations reports every template clean.
  [ "$n" -ge 6 ] \
    || cf "only $n template(s) declared a destination this case could read — expected at least 6. The declaration wording changed, so 'every template's links resolve' is true of almost nothing"

  finish "all $n templates that declare where they land have links that resolve FROM THERE ($bad broken) — checked from the destination each template names, because a link written for where the template SITS passes every check run in the kit and is dead in every adopter's copy"
  teardown
}

case_missing_option_value_refuses() {
  cf_reset
  make_sandbox
  local f base arms=0 guarded=0 defs="" bad=""

  for f in "$REAL_SCRIPTS"/*.sh; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    # A value-taking arm is a case arm that shifts TWO. Derived, never listed.
    while IFS= read -r ln; do
      [ -n "$ln" ] || continue
      arms=$(( arms + 1 ))
      case "$ln" in
        *'need_val "$@"'*) guarded=$(( guarded + 1 )) ;;
        *) bad="$bad
    $base: $ln" ;;
      esac
    done <<EOF
$(awk '/^[[:space:]]*(-[a-zA-Z]\|)*--[a-z][a-z-]*\)/ && /shift 2/ { gsub(/^[[:space:]]+/,""); print }' "$f")
EOF
    grep -q '^need_val()' "$f" && defs="$defs $base"
  done

  [ -z "$bad" ] \
    || cf "these value-taking option arms do not call need_val — each exits 1 in silence when its value is missing, because \`shift 2\` with one argument left fails under set -e:$bad"

  # ── INSTRUMENT CHECK: the derivation still finds arms. A census that matched nothing
  #    would report "all guarded" forever.
  [ "$arms" -ge 20 ] \
    || cf "the census found only $arms value-taking arm(s) — expected at least 20. The arm shape changed, so 'every one is guarded' is true of almost nothing"

  # ONE GUARD, ONE SHAPE. Nine scripts each carry their own copy (several source nothing
  # from scripts/lib/), so the copies are held identical here rather than shared.
  local first="" body
  for base in $defs; do
    body="$(awk '/^need_val\(\)/{f=1} f{print} f&&/^}/{exit}' "$REAL_SCRIPTS/$base" | tr -d ' \n')"
    if [ -z "$first" ]; then first="$body"
    elif [ "$body" != "$first" ]; then
      cf "$base's need_val differs from the first definition — nine hand-kept copies of one guard, and a divergence here means one script refuses differently from its siblings for the same illegal invocation"
    fi
  done

  # ── EXECUTED, because a static census cannot know the guard does anything.
  local out rc
  rc=0; out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$SB_PREFIX-1" todo --note 2>&1 )" || rc=$?
  [ "$rc" -eq 2 ] \
    || cf "(executed) move-issue.sh with a valueless --note exited $rc, want 2: $(printf '%s' "$out" | head -1)"
  printf '%s' "$out" | grep 'requires a value' >/dev/null \
    || cf "(executed) move-issue.sh's refusal does not say the option requires a value: $(printf '%s' "$out" | head -1)"

  # A LEADING '-' IS NEVER A NAME — the same clause, on a POSITIONAL rather than an option.
  # notify.sh swallowed `--message` as its message BODY and exited 0, delivering a
  # notification that read "--message".
  rc=0; out="$( cd "$SB_WORK" && ./scripts/notify.sh attention --message 2>&1 )" || rc=$?
  [ "$rc" -eq 2 ] \
    || cf "(executed) notify.sh took '--message' as its message body and exited $rc — a leading '-' is never a name, and a delivered notification reading '--message' is quieter than a refusal"

  finish "every one of the $arms value-taking option arms across the shipped scripts calls need_val (${guarded} guarded), the guard's ${defs:+copies} are byte-identical, and two scripts prove it EXECUTED: a valueless --note exits 2 naming the option, and a leading '-' is refused as a positional rather than swallowed as one"
  teardown
}

# =============================================================================
# CASE — NO SHIPPED SCRIPT REACHES PAST THE DECLARED FLOOR.
#
# The kit REQUIRES git and a POSIX shell, and carves out its optional extras BY NAME —
# the hygiene scripts are Python 3 and never a gate; one skill's visual companion wants
# Node and is opt-in per question. `perl` is not among them, and subtask.sh used it on
# its --plan path.
#
# THE FLOOR'S VALUE IS NOT THAT THE LIST IS SHORT; IT IS THAT THE LIST IS TRUE. perl is on
# essentially every system the kit will meet, so the practical risk is small — and an
# undeclared dependency on an optional path is exactly what an adopter porting to a
# minimal container finds at the wrong moment. A floor nobody checks is a claim.
#
# THE CARVE-OUTS ARE DERIVED, not listed here: this case reads the shipped scripts, and
# the two named extras live in directories it does not walk.
# =============================================================================
case_shipped_scripts_stay_on_the_floor() {
  cf_reset
  # NO SANDBOX. The population is the SHIPPED MANIFEST, which describes the real tree; a sandbox
  # is a mutated copy of part of it and could not answer the question.
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  [ -f "$man" ] \
    || _fixture_die "case_shipped_scripts_stay_on_the_floor: process/KIT-MANIFEST is absent, which the startup guard should already have refused."

  # The interpreters that are NOT on the floor. Held one per line so this case's own text cannot
  # satisfy the search it performs. `python3` is listed SEPARATELY from `python`: the command-
  # position pattern below anchors on a word boundary, so `python3 -c` never matched `python`,
  # and a shipped hook invoking python3 sat outside this case for as long as it has existed.
  local i1='perl' i2='python' i3='python3' i4='node' i5='ruby'

  local rel f sb n=0 walked=0 outspan="" absent=""
  local undeclared="" stale=""

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    n=$(( n + 1 ))
    f="$REAL_REPO_ROOT/$rel"
    [ -f "$f" ] || { absent="$absent $rel"; continue; }
    sb="$(head -1 "$f" 2>/dev/null)"
    case "$sb" in
      '#!'*sh) ;;                        # a POSIX-shell program — inside this check's span
      '#!'*)                             # a program in another language — OUTSIDE it, see below
        outspan="$outspan ${rel}(${sb##*/})"; continue ;;
      *) continue ;;                     # not a program at all
    esac
    walked=$(( walked + 1 ))

    # THE HARNESS IS ONE PROGRAM IN SEVERAL FILES. Its entry point sources lib/*.sh and cases/*.sh,
    # which carry no shebang and so are "not a program" above; the entry point's startup probe is
    # their declaration. So the entry point is read as the whole population it loads, and a hit
    # names the file that holds it. Read alone, the entry point's perl probe would guard nothing
    # it holds — a stale declaration — while the calls it guards went unread.
    local ops=("$f") _pf
    if [ "$f" -ef "$HARNESS_ENTRY" ]; then
      ops=()
      while IFS= read -r _pf; do [ -n "$_pf" ] && ops+=("$_pf"); done <<FLOOR_POP_EOF
$(_harness_sources)
FLOOR_POP_EOF
      _harness_population_is_whole <(cat "${ops[@]}")
    fi

    local w hits guarded
    for w in "$i1" "$i2" "$i3" "$i4" "$i5"; do
      # COMMAND POSITION, not mere appearance. `echo "… a node id …"` mentions node and does not
      # invoke it. The leading `VAR=value ` group is there because the shipped idiom for passing a
      # value safely is exactly `PLAN="$PLAN" perl …`.
      hits="$(awk -v w="$w" -v many="${#ops[@]}" -v root="$REAL_REPO_ROOT" '
        /^[[:space:]]*#/ { next }
        $0 ~ ("(^|[;&|(]|\\$\\()[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*" w "([[:space:]]|$)") { print (many > 1 ? substr(FILENAME, length(root) + 2) ":" : "") FNR ": " substr($0,1,70) }
      ' "${ops[@]}" 2>/dev/null || true)"
      # DECLARED = the file guards the interpreter with `command -v` in its own text. That is the
      # property, and it is the whole of the exemption: a program that CHECKS FOR an interpreter
      # before using it has a defined behaviour without it, and a program that does not, does not.
      # No name list — attempting one is the defect this case was rewritten to remove.
      guarded=0
      grep -qE "command -v ${w}([^0-9A-Za-z_]|\$)" "${ops[@]}" 2>/dev/null && guarded=1
      if [ -n "$hits" ] && [ "$guarded" -eq 0 ]; then
        undeclared="$undeclared
    $rel invokes '$w' and never checks for it: $(printf '%s' "$hits" | head -1)"
      elif [ -z "$hits" ] && [ "$guarded" -eq 1 ]; then
        # THE SECOND DIRECTION, and it is the notch. A declaration that outlives its use is how an
        # exemption list rots into a list of things nobody checks: the guard reads as evidence that
        # the dependency is handled, when the dependency is gone.
        stale="$stale $rel($w)"
      fi
    done
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF

  # ── INSTRUMENT CHECK. The floor here is NOT a typed number — it is the COMPARISON that every
  #    row of the manifest was reached. A literal minimum ("at least 15") is a number that must be
  #    maintained and will not be, and it is satisfiable by editing the answer, which is precisely
  #    what this case is being rewritten to stop.
  [ "$n" -gt 0 ] \
    || cf "(instrument) the manifest yielded no paths — every assertion here would be vacuously true"
  [ -z "$absent" ] \
    || cf "(instrument) the manifest names path(s) absent from this tree, so they were NOT examined —$absent"
  [ "$walked" -gt 0 ] \
    || cf "(instrument) not one shipped SHELL program was found among $n manifest path(s) — the shebang test stopped matching, so 'nothing off the floor' is true of nothing"

  [ -z "$undeclared" ] \
    || cf "shipped shell program(s) invoke an interpreter past the kit's declared floor (git + a POSIX shell) WITHOUT checking for it first:$undeclared"
  [ -z "$stale" ] \
    || cf "shipped shell program(s) carry a 'command -v' guard for an interpreter they no longer invoke —$stale. A declaration that outlives its use reads as coverage and is none"

  # THE SPAN IS PRINTED ON THE CLEARING BRANCH, and the non-shell members are NAMED rather than
  # silently dropped. The command-position pattern above is written for SHELL: run against a
  # Python file it reads `(node == item` and `node = frontier.pop()` as invocations, which is a
  # false accusation of exactly the kind that gets a floor check switched off for being noisy.
  # A non-shell program's dependency is declared by its own shebang and is that program's to hold.
  finish "of $n manifest path(s), the $walked that are shipped SHELL programs invoke no interpreter past the kit's floor without checking for it first, and none carries a check for one it no longer invokes — the population is DERIVED FROM THE MANIFEST rather than from a glob, so a file the adopter was told to add is not counted as ours; the harness entry point is read as the whole population it loads. NOT MEASURED HERE, because this check's pattern reads shell and would report a variable named 'node' as an invocation:${outspan:- (none)}"
}

# =============================================================================
# CASE — NO --help OPENS WITH ITS OWN KIT-CLASS MARKER.
#
# Every header-derived --help printed from a literal line 3, and that literal encoded a
# premise: line 1 is the shebang, line 2 is the whole KIT-CLASS marker. The premise is
# false wherever the marker WRAPS — several shipped files carry one spanning more than one
# line, and the set is derivable, so do not re-add a count here; the twin of this sentence
# in scripts/lib/usage.sh carried "three" until it was corrected on 2026-09-03 and THIS one
# was left, which is what fixing an instance instead of a class looks like from the inside
# — and help then opens with marker text, which is precisely what the window exists
# to exclude. The window's END was carefully derived; only its START was assumed.
#
# THE ASSERTION IS ABOUT THE OUTPUT, not about the number. A case pinning `start` to a
# computed value would pass against a renderer that computed it and then ignored it.
# =============================================================================
case_help_never_opens_with_the_class_marker() {
  cf_reset
  make_sandbox
  local f rel base out n=0 marker_key skipped=0

  # Derive the marker's own key rather than typing it — the same constant kit-init protects.
  marker_key="$KIT_CLASS_MARKER_KEY"
  [ -n "$marker_key" ] \
    || _fixture_die "case_help_never_opens_with_the_class_marker: no KIT_CLASS_MARKER_KEY — the assertion below would search for an empty string and pass on every file."

  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  [ -f "$man" ] \
    || _fixture_die "case_help_never_opens_with_the_class_marker: process/KIT-MANIFEST is absent, which the startup guard should already have refused."

  # ── THE POPULATION SELECTS ON THE PROPERTY, NOT ON THE STRING. ──────────────────────────────
  #
  # It used to be `grep -q -- "--help" "$f"`: any file CONTAINING the characters `--help`. On the
  # kit's own tree that is nearly the same set as "has a usage handler". On a tree that has run the
  # initializer it is not: kit-init appends a stamp receipt to scripts/config.sh, the receipt
  # mentions `--help`, and config.sh also carries a KIT-CLASS marker — so both filters passed and a
  # SOURCED SEAM WITH NO CLI entered the population. `config.sh --help` prints nothing, because
  # there is nothing there to print, and the case reported it as a defect. **A blind adopter met
  # that failure on day one and wrote "a run that reports two failures is unchanged, not broken"
  # into its own project law.** The tree was not broken; the population was.
  #
  # The property is *is this a command-line tool at all*, and the kit now answers that in the
  # contract that states the CLI shape — with the class's admission test beside it, not as a name
  # here. A stamp receipt cannot make a sourced seam a CLI, so it cannot re-enter this population
  # by acquiring a string.
  local exempt; exempt="$(_cli_exempt_prefixes)"
  [ -n "$exempt" ] \
    || _fixture_die "case_help_never_opens_with_the_class_marker: could not derive the CLI-shape exempt classes out of issue-creation.md. With none derived, every sourced seam and hook re-enters this population and the case reports their absent usage handlers as defects — which is the very finding this case was rewritten to close."

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    f="$REAL_REPO_ROOT/$rel"
    [ -f "$f" ] || continue
    head -1 "$f" 2>/dev/null | grep '^#!.*sh$' >/dev/null || continue

    local e skip=0
    for e in $exempt; do case "$rel" in "$e"*) skip=1 ;; esac; done
    [ "$skip" -eq 1 ] && { skipped=$(( skipped + 1 )); continue; }

    # Only a file that CARRIES the marker can leak it. This filter is the subject of the
    # assertion, not a proxy for one.
    grep -q "$marker_key" "$f" 2>/dev/null || continue
    n=$(( n + 1 ))
    base="$(basename "$f")"

    # Run from a scratch cwd: a usage request is contracted to do no work, and this is one of the
    # places that claim is exercised rather than assumed.
    out="$( cd "$SB_TMP" && bash "$f" --help </dev/null 2>&1 )" || true
    [ -n "$out" ] \
      || { cf "$rel --help printed nothing — every tool the CLI contract binds answers a usage request, and this one is bound"; continue; }
    # THE FIRST FIVE LINES are the window's opening; a marker that wraps shows up there.
    printf '%s\n' "$out" | head -5 | grep "$marker_key" >/dev/null \
      && cf "$base --help opens with its own $marker_key marker — the window START is assuming the marker is one line, and this file's is not: $(printf '%s' "$out" | head -3 | tr '\n' '|' | cut -c1-140)"
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF

  # ── INSTRUMENT CHECKS, and neither is a typed floor. `n >= 8` used to sit here: a literal that
  #    somebody must maintain and will not, and one that is satisfiable by editing the answer.
  #    What replaces it is the comparison — the manifest yielded a population, the exempt classes
  #    matched something, and marker-carrying tools were found among what remained.
  [ "$n" -gt 0 ] \
    || cf "(instrument) not one bound tool carrying a $marker_key marker was found — one of the two filters stopped matching, so 'no leakage' is true of nothing"
  [ "$skipped" -gt 0 ] \
    || cf "(instrument) not one manifest path matched an exempt class, though the contract declares several — the prefix match stopped working, and sourced seams are being asked for usage handlers again"

  finish "no --help among the $n shipped tools that the CLI contract BINDS and that carry a $marker_key marker opens with that marker's own text, and every one of them answers a usage request at all — the window START is derived from where the marker ENDS (every marker's last line cites the extraction manifest), not from the assumption that it is one line. The population is the manifest minus the classes issue-creation.md § 3 declares unbound ($skipped shipped program(s)), so a stamp receipt that merely CONTAINS the string '--help' can no longer drag a sourced seam into it"
  teardown
}

# _role_example_label_token — the label's machine token. DECLARED in
# process/EXTRACTION.md § 2.4's ROLE-EXAMPLE-LABEL-TOKEN marker block, never typed here and
# never read off the files the case below checks: a token derived FROM the instances it guards
# could not see them all drift together in silence. That is the same argument § 2.4's own
# "never derive the tag from the set" rule makes, one level up.
#
# THE TOKEN IS THE LAST BACKTICKED SPAN IN THE BLOCK, not the first. The declaring sentence has
# to name the flags it is about, so its FIRST span is `--help` — a derivation that took it would
# declare the token to be a flag name, find it in every usage line in the tree and pass forever.
# The span COUNT is asserted by the caller so a second trailing span cannot slip in unnoticed.
_role_example_label_token() {  # echoes the token; prints nothing if the block is absent
  local sheet="$REAL_REPO_ROOT/process/EXTRACTION.md"
  [ -f "$sheet" ] || return 0
  awk '/ROLE-EXAMPLE-LABEL-TOKEN:BEGIN/,/ROLE-EXAMPLE-LABEL-TOKEN:END/' "$sheet" \
    | grep -oE '`[^`]+`' | tail -1 | tr -d '`'
}

_role_example_label_spans() {  # echoes how many backticked spans the block holds
  local sheet="$REAL_REPO_ROOT/process/EXTRACTION.md"
  [ -f "$sheet" ] || { echo 0; return 0; }
  awk '/ROLE-EXAMPLE-LABEL-TOKEN:BEGIN/,/ROLE-EXAMPLE-LABEL-TOKEN:END/' "$sheet" \
    | grep -coE '`[^`]+`'
}

# =============================================================================
# CASE — EVERY --help EXAMPLE NAMING A DECLARED ROLE CARRIES THE LABEL
#
# The kit rules that a --help example naming a role is PROGRAM OUTPUT, not a comment, and must
# say the role shown is an example value (process/EXTRACTION.md § 2.4). The rule was stated once
# and applied to the shipped files BY HAND, and nothing since checked either direction:
# nothing asserted the labels were still there, and nothing noticed a new site arriving
# unlabelled — which is the default state the rule exists to end.
#
# BOTH DIRECTIONS OR NEITHER. Deleting a label leaves --help printing a bare confident example
# and every other case green; that was measured on a built tree before this case was written.
# The population is DERIVED from the manifest and from each tool's OWN --help OUTPUT — never a
# re-parse of its source, which § 2.4 itself rejects: a derivation that reads its own subject's
# source shares that subject's blind spot, and the rendered text is what an operator pastes.
#
# EVERY READ BELOW IS `grep ... >/dev/null`, NEVER A PIPED `grep -q`, and the harness has its own
# floor asserting that. Under `set -o pipefail` a `-q` reader exits the moment it matches, the
# producer dies on SIGPIPE once it has cleared the pipe buffer, and the pipeline reports the
# PRODUCER'S death instead of the reader's answer. Dropping -q and redirecting drains the input and
# returns the identical status. This case was written with `-q` and the floor caught all four sites.
#
# THE MEMBERSHIP FILTER IS NOT TIDINESS. A bare `--role \S+` scan over the real tree matches
# `--role whitelist`, `--role must`, `--role enforcement` and dozens more prose fragments, none
# of them an example. Requiring the word after --role to be a DECLARED role is what makes the
# population the set this sentence names — the same discriminator § 2.4's own SET recipe uses,
# and derived from the hook rather than typed here.
# =============================================================================
case_role_examples_carry_their_label() {
  cf_reset
  make_sandbox   # for SB_TMP + teardown; the population below reads the REAL tree, not the sandbox

  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  [ -f "$man" ] \
    || _fixture_die "case_role_examples_carry_their_label: process/KIT-MANIFEST is absent, which the startup guard should already have refused."

  local exempt; exempt="$(_cli_exempt_prefixes)"
  [ -n "$exempt" ] \
    || _fixture_die "case_role_examples_carry_their_label: could not derive the CLI-shape exempt classes out of issue-creation.md — with none derived, every sourced seam and hook is judged as though an operator could type a --role flag at it."

  local spans; spans="$(_role_example_label_spans)"
  [ "$spans" -ge 1 ] \
    || _fixture_die "case_role_examples_carry_their_label: process/EXTRACTION.md's ROLE-EXAMPLE-LABEL-TOKEN block holds no backticked span, so there is no token to assert and every header would pass labelled or not."

  local token; token="$(_role_example_label_token)"
  [ -n "$token" ] \
    || _fixture_die "case_role_examples_carry_their_label: could not derive the label's machine token from process/EXTRACTION.md's ROLE-EXAMPLE-LABEL-TOKEN block — with none derived, every header naming a role in a --role position would silently pass, labelled or not."

  # THE TOKEN MUST NOT BE A FLAG NAME. The block's sentence names the flags it is about, so a
  # derivation that took the wrong span would land on `--help` or `--role` — which appears in
  # every usage line in the tree and would make this case pass on a wholly unlabelled tree.
  case "$token" in
    -*) _fixture_die "case_role_examples_carry_their_label: the token derived from the ROLE-EXAMPLE-LABEL-TOKEN block is '$token', which is a FLAG name, not a label. The block's declaring sentence must END on the literal; a token that is a flag appears in every usage line and would pass on a tree with no labels at all." ;;
  esac

  # FALLBACK POLICY HERE: _fixture_die. With no declared set there is nothing to judge a --role example against.
  local roles; roles="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$REAL_REPO_ROOT/scripts/githooks/commit-msg" | head -1)"
  [ -n "$roles" ] \
    || _fixture_die "case_role_examples_carry_their_label: could not derive the declared role set from scripts/githooks/commit-msg — with none derived, the --role-position scan below has no membership to require and would match any word after --role."

  # ── THE POPULATION: bound tools whose OWN --help OUTPUT puts a DECLARED role in a --role
  #    argument position. Membership and invocation form both come from `_cli_invocation`, the
  #    one place that mapping lives — so a shipped program in a language this harness learns to
  #    invoke joins this population at the same moment it joins the CLI-shape one, rather than
  #    being silently out of reach of a rule that binds it.
  local rel f base out interp n=0 skipped=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    f="$REAL_REPO_ROOT/$rel"
    [ -f "$f" ] || continue
    interp="$(_cli_invocation "$f")"
    [ -n "$interp" ] || continue

    local e skip=0
    for e in $exempt; do case "$rel" in "$e"*) skip=1 ;; esac; done
    if [ "$skip" -eq 1 ]; then skipped=$(( skipped + 1 )); continue; fi

    if [ "$interp" = SHELL ]; then
      out="$( cd "$SB_TMP" && bash "$f" --help </dev/null 2>&1 )" || true
    else
      out="$( cd "$SB_TMP" && "$interp" "$f" --help </dev/null 2>&1 )" || true
    fi
    # A silent bound tool is case_help_never_opens_with_the_class_marker's finding, not this
    # case's — skip rather than re-assert it, so one absent handler cannot report as two defects.
    [ -n "$out" ] || continue

    printf '%s\n' "$out" | grep -E -- "--role[[:space:]]+($roles)([^A-Za-z]|\$)" >/dev/null || continue
    n=$(( n + 1 ))
    base="$(basename "$f")"
    printf '%s\n' "$out" | grep -F -- "$token" >/dev/null \
      || cf "$base --help shows a declared role in a --role argument position and carries no '$token' — an operator reading this tree's --help sees a bare confident example with no notice that the role shown may not be one this project declares"
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF

  # ── INSTRUMENT CHECKS. A search that stopped matching would report "all labelled" forever,
  #    which is the exact failure mode this family was found through: an instrument reddened on
  #    these examples once, and what replaced it was a sentence.
  [ "$n" -gt 0 ] \
    || cf "(instrument) not one bound tool's --help showed a declared role in a --role argument position — the population this case exists to police is empty, so 'every one labelled' would be true of nothing"
  [ "$skipped" -gt 0 ] \
    || cf "(instrument) not one manifest path matched an exempt class, though the contract declares several — the prefix match stopped working, and sourced seams are being asked for usage handlers again"

  # ── THE REDDENING CONTROL, on a COPY — never a shipped file. A fabricated header, built so it
  #    puts a declared role in a --role position and deliberately carries no label, must trip the
  #    SAME predicate the population loop uses — proving the PREDICATE is what is green, not
  #    merely this run's shipped tree.
  #    The probe is a HEADER ONLY, so it is rendered by sourcing the real lib/usage.sh and calling
  #    kit_usage on it — never a hand-rolled re-implementation of the window that renderer computes.
  #    It carries a trailing non-comment line because kit_usage's window ENDS at the first one; an
  #    all-comment file renders empty, which the first guard below caught when it did.
  local first_role; first_role="$(printf '%s' "$roles" | cut -d'|' -f1)"
  local probe="$SB_TMP/roleprobe.sh"
  {
    printf '#!/usr/bin/env bash\n'
    printf '# Usage:\n'
    printf '#   ./scripts/roleprobe.sh --role %s --note "..."\n' "$first_role"
    printf 'true\n'
  } > "$probe" 2>/dev/null
  if [ ! -s "$probe" ]; then
    _control_did_not_run "write the planted header to probe into"
  else
    out="$(bash -c '. "$1/scripts/lib/usage.sh"; kit_usage "$2"' _ "$REAL_REPO_ROOT" "$probe" 2>&1)" || true
    if ! printf '%s\n' "$out" | grep -E -- "--role[[:space:]]+($roles)([^A-Za-z]|\$)" >/dev/null; then
      _control_did_not_run "get the planted header to show a declared role in a --role argument position at all: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    elif printf '%s\n' "$out" | grep -F -- "$token" >/dev/null; then
      _control_did_not_run "plant a header that OMITS the label — the probe's own text already carries '$token', so a red here would prove nothing"
    fi
    # No further assertion is needed: the two guards above are exhaustive. If both pass, the probe
    # IS a genuine unlabelled role example — precisely what the population loop's own `cf` fires
    # on, the same predicate, exercised on a copy every run.
  fi

  finish "of $n bound tool(s) whose --help shows a declared role in a --role argument position (population from process/KIT-MANIFEST through the same _cli_invocation predicate the CLI-shape case walks, roles from scripts/githooks/commit-msg, $skipped exempt by issue-creation.md's CLI-SHAPE-EXEMPT-CLASSES block, the label's token from EXTRACTION.md's ROLE-EXAMPLE-LABEL-TOKEN block and asserted not to be a flag name), every one carries the label — and a planted unlabelled example on a COPY trips the same predicate every run"
  teardown
}

# =============================================================================
# CASE — THE SCAFFOLDING SENTINEL HAS THREE AUTHORS AND THEY MUST AGREE.
#
# The mark is written by two shipped root documents, looked for by check-board.sh's
# graduation arm, and seeded by this harness. Single-sourcing the FIXTURE (one
# seed_scaffolding_tree instead of five re-typed pairs) does not make those three agree —
# it only means a disagreement now shows up once instead of five times. This case is what
# actually holds them together.
#
# WHY NOT JUST DERIVE THE FIXTURE FROM check-board.sh: because then the fixture and the
# tool agree BY CONSTRUCTION, and a rename in the shipped documents — the thing an adopter
# deletes, the only place the mark is user-visible — would go unnoticed while every
# graduation case stayed green. That reason stands, and the fixture is still never derived
# from the probe. What is superseded is the fixture's other end: it read the DOCUMENTS, and
# it now reads the harness's own declared KIT_SCAFFOLD_MARK, because the documents are
# REPLACE-class and a tree that finished day one has replaced both — the derivation made
# this whole harness refuse to start there, zero cases. The three authors are unchanged.
# Arm (a) asserts the document author WHERE A SHIPPED COPY IS STILL PRESENT, and names the
# documents it did not measure when one is not (instruments.md § A.4).
# =============================================================================
case_scaffolding_fixture_matches_the_tree() {
  cf_reset
  make_sandbox
  local doc probe_hits line1 a_shipped="" a_unshipped=""

  # (a) EVERY SHIPPED root document carries the mark — and "shipped" is decided by the file's
  #     OWN declared class, not by its name. The harness no longer derives the mark from these
  #     files, so this arm is the third author held against the first: a rename in the shipped
  #     documents that KIT_SCAFFOLD_MARK did not follow reddens here.
  #     WHY IT IS NARROWED TO SHIPPED COPIES. CLAUDE.md and README.md are REPLACE-class, and
  #     SEED requires an adopter to have replaced both, so on a tree that finished day one the
  #     two files with those names are the ADOPTER'S. Demanding the kit's mark inside somebody
  #     else's document is an arm that is red on every correct tree — a control that has to be
  #     normalised away rather than believed. The shipped copies declare themselves on line 1
  #     and the adapter template tells the adopter to DROP that marker from their copy, so the
  #     file's own declaration is the discriminator; the documents this arm did NOT measure are
  #     named in its own result line, on the clearing branch (instruments.md § A.4), instead of
  #     being left for a reader to mistake for a wider verdict.
  #     THE ONE AMBIGUOUS STATE IS A TRUE RED. A file declaring the kit class and carrying no
  #     sentinel is either the shipped stub EDITED — illegal for a REPLACE-class file — or an
  #     adapter still carrying the kit's marker. The message names both readings, because the
  #     arm cannot tell them apart and guessing would send the reader to the wrong file.
  # Read the REAL tree, not the sandbox: make_sandbox does not seed the root documents
  # (a day-one tree has them, a sandbox is built without them), so a sandbox miss here
  # would be about the fixture and not about the kit that ships.
  # NO PIPE ON THE LINE-1 READ: `sed … | grep -q` is the producer-into-early-exit-reader shape
  # this file's own header forbids under pipefail, so line 1 goes through a variable.
  for doc in CLAUDE.md README.md; do
    if [ ! -f "$REAL_REPO_ROOT/$doc" ]; then
      a_unshipped="$a_unshipped $doc(absent)"
      continue
    fi
    line1="$(sed -n '1p' "$REAL_REPO_ROOT/$doc")"
    case "$line1" in
      *"$KIT_CLASS_MARKER_KEY KIT"*) ;;
      *) a_unshipped="$a_unshipped $doc(line 1 declares no $KIT_CLASS_MARKER_KEY KIT)"; continue ;;
    esac
    a_shipped="$a_shipped $doc"
    grep -qxF "$KIT_SCAFFOLD_MARK" "$REAL_REPO_ROOT/$doc" \
      || cf "(a) $doc declares itself $KIT_CLASS_MARKER_KEY KIT on line 1 but holds no line equal to '$KIT_SCAFFOLD_MARK' — and both readings of that are a defect: either it is the shipped stub with its sentinel removed, which is an EDIT of a REPLACE-class file, or it is an adapter built from the template that still carries the kit's marker the template tells you to drop"
  done

  # (b) check-board.sh LOOKS for exactly that line, with the same whole-line match. Derived
  #     from the script, not retyped: a literal here would be a fourth author of the very
  #     constant under test. AND THIS IS WHERE THE NO-FALLBACK PROPERTY LIVES now that the
  #     mark is declared instead of read out of the tree — a constant the tool does not look
  #     for reddens here, so the fixture cannot be invisible to the tool without a red.
  grep -qF "grep -qxF '$KIT_SCAFFOLD_MARK'" "$SB_WORK/scripts/check-board.sh" \
    || cf "(b) check-board.sh does not probe for '$KIT_SCAFFOLD_MARK' with a whole-line match — the tool and the harness disagree, so the graduation arm is looking for a mark nobody writes"

  # (c) THE ARM SELECTS ITS POPULATION FROM THE FILES' OWN DECLARATION, not from a list
  #     typed into the script. This assertion used to read `grep -c "for f in CLAUDE.md
  #     README.md"` — it asserted the hardcoded list itself, so it was a check that the
  #     duplication was still there. That list was a second copy of EXTRACTION.md § The
  #     second axis: DISPOSITION's member table, and when (g1) was changed to derive the
  #     population from KIT-DISPOSITION: REPLACE declarations, this arm reddened for
  #     asserting the very thing that was removed.
  #
  #     WHAT IT ASSERTS NOW IS THE COUPLING THAT REPLACED IT, and it is the stronger
  #     property: the tool must READ the declaration that seed_scaffolding_tree WRITES.
  #     Derived from the constant, never re-typed, for the same reason (b) gives about
  #     the mark — a literal here would be a second author of the key under test.
  grep -qF "$KIT_REPLACE_DISPOSITION" "$SB_WORK/scripts/check-board.sh" \
    || cf "(c) check-board.sh's graduation arm does not mention '$KIT_REPLACE_DISPOSITION' — it no longer reads the disposition declaration that seed_scaffolding_tree writes, so the fixture seeds a population the tool cannot see"

  # (d) THE EFFECT, end to end. Everything above is textual; this arm proves the seeded
  #     tree actually trips the arm. Without it, three agreeing strings could still be the
  #     wrong strings. The receipt is what makes the graduation arm REPORT rather than
  #     stay unrun — the same premise the rest of this family establishes.
  seed_scaffolding_tree
  printf '\n%s on 2026-01-01 — prefix XYZ, trunk %s.\n' "$KIT_STAMP_MARK" "$SB_TRUNK" \
    >> "$SB_WORK/scripts/config.sh"
  publish_sandbox
  local out; out="$(cb_run)"
  printf '%s\n' "$out" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    || cf "(d) a tree seeded by seed_scaffolding_tree does not read as still-scaffolding to check-board.sh: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"


  # (e) ARM (a)'s DISCRIMINATOR IS ITSELF ASSERTED, and the two states it hides are asserted
  #     on DIFFERENT trees, because they are different defects.
  #
  #     Arm (a) decides what to measure from each document's OWN line 1, so deleting that line
  #     silently removes the document from the span: arm (a) prints "not a shipped copy", the
  #     sentinel could then be renamed or removed inside it, and this case stays green. A
  #     document that is ABSENT is likewise printed as "(absent)" and not measured — that state
  #     used to redden, because `grep -qF` failed on a missing file, and the red was real even
  #     though its message was misleading. Both are states in which this case reports success
  #     about a document nothing looked at. A CONTROL THAT CHOOSES ITS OWN OPERAND SET OWES AN
  #     ASSERTION THAT THE SET IS RIGHT — process/doctrine/instruments.md § A.4's operand-set
  #     rule, read one notch further.
  #
  #     EXISTENCE IS ASSERTED ON BOTH KINDS OF TREE. The adoption question is whether a document
  #     is the ADOPTER'S or the KIT'S — not whether it is THERE. Arm (a) walks both names
  #     unconditionally and check-board.sh's graduation arm iterates the same pair, so on any
  #     tree a missing one means both are working with one fewer operand than they think; and
  #     process/SEED.md's day-one checklist requires both to have been REPLACED, which requires
  #     both to exist. Measured 2026-09-07: both are present on the shipped tree and on a tree
  #     built through day one, so this is a floor neither tree is near rather than a rule with a
  #     tolerated exception.
  #
  #     THE CLASS MARKER IS ASSERTED ONLY WHERE THE TREE HAS NOT BEEN ADOPTED. On an adopted
  #     tree both documents are legitimately the adopter's — the adapter template tells them to
  #     DROP the marker — so demanding it would be red on every correct tree, which is arm (a)'s
  #     own reasoning applied to arm (a)'s premise. That judgement about the tree comes from the
  #     SAME derivation case_ship_state uses, which is why the derivation is now a function
  #     rather than a second copy that could disagree with it about one tree.
  local lived_why e_marked=""
  lived_why="$(_tree_has_lived)"
  for doc in CLAUDE.md README.md; do
    if [ ! -f "$REAL_REPO_ROOT/$doc" ]; then
      cf "(e) $doc is ABSENT — the kit ships both root documents, SEED's day-one checklist requires both to have been replaced, and check-board.sh's graduation arm iterates this same pair. Arm (a) prints an absent document as not-measured rather than reddening, so nothing else in this suite would say this"
      continue
    fi
    if [ -n "$lived_why" ]; then continue; fi
    if _root_doc_is_shipped_copy "$REAL_REPO_ROOT" "$doc"; then
      e_marked="$e_marked $doc"
    else
      cf "(e) $doc does not declare $KIT_CLASS_MARKER_KEY KIT on line 1, on a tree that has NOT been adopted ($REAL_REPO_ROOT) — arm (a) reads exactly that line to decide whether to measure this document, so its absence removes the document from arm (a)'s span SILENTLY: the sentinel inside it stops being checked and this case still reports success"
    fi
  done

  # ── THE REDDENING CONTROL, on a FABRICATED root — never the real documents, which this
  #    harness must not write to (case_isolation asserts the whole real tree is unchanged across
  #    the run). The discriminator is lifted into a function precisely so it can be pointed at a
  #    copy. NO PIPE ON ANY LINE-1 READ, here or in the helper: `sed … | grep -q` is the
  #    producer-into-early-exit-reader shape this file's header forbids under pipefail, which is
  #    why arm (a) routes line 1 through a variable and so does this.
  local ctl="$SB_TMP/rootdocs" ctl_l1
  mkdir -p "$ctl"
  printf '%s KIT — a fabricated shipped copy\n\n%s\n' "$KIT_CLASS_MARKER_KEY" "$KIT_SCAFFOLD_MARK" > "$ctl/CLAUDE.md"
  if ! _root_doc_is_shipped_copy "$ctl" CLAUDE.md; then
    # THE POSITIVE CONTROL FIRST. A discriminator that accepts nothing would make both negative
    # controls below pass for the wrong reason (instruments.md § A.2).
    _control_did_not_run "build a fabricated root document the discriminator ACCEPTS"
  else
    # STATE 1 — the marker line removed. THE MUTATION IS ASSERTED TO HAVE APPLIED before its
    # effect is believed: a sed that matched nothing leaves this control silent and green.
    sed -i.bak '1d' "$ctl/CLAUDE.md"; rm -f "$ctl/CLAUDE.md.bak"
    ctl_l1="$(sed -n '1p' "$ctl/CLAUDE.md")"
    case "$ctl_l1" in
      *"$KIT_CLASS_MARKER_KEY"*)
        _control_did_not_run "remove the class marker from the fabricated document (line 1 still carries it)" ;;
      *)
        if _root_doc_is_shipped_copy "$ctl" CLAUDE.md; then
          cf "(control) the discriminator still calls a document a shipped copy after its $KIT_CLASS_MARKER_KEY line was deleted — arm (e) cannot detect the state it is written for"
        fi ;;
    esac
    # STATE 2 — the document gone. Asserted as its own state because arm (a) treats absent and
    # unmarked identically, printing both as not-measured, while they are different defects.
    rm -f "$ctl/CLAUDE.md"
    if [ -f "$ctl/CLAUDE.md" ]; then
      _control_did_not_run "delete the fabricated document"
    elif _root_doc_is_shipped_copy "$ctl" CLAUDE.md; then
      cf "(control) the discriminator calls an ABSENT document a shipped copy — arm (e)'s absent branch could never fire"
    fi
  fi
  finish "the scaffolding sentinel's three authors agree: the harness DECLARES the mark as the whole shipped line and derives it from nothing in the tree under test, check-board.sh's graduation arm matches that same line exactly on that same pair of root documents, and a tree seeded by seed_scaffolding_tree actually reads as still-scaffolding — the fixture is never derived from the probe, so a rename cannot make the two agree by construction. Arm (a)'s span is the root documents whose line 1 declares $KIT_CLASS_MARKER_KEY KIT: asserted to carry it =${a_shipped:- (none)}; not a shipped copy, adopter-owned, NOT MEASURED HERE =${a_unshipped:- (none)}. Arm (e) asserts arm (a)'s own discriminator rather than trusting it: both root documents EXIST on either kind of tree (the adoption question is whose the document is, not whether it is there — and SEED's day-one checklist requires both to have been replaced), and where the tree has NOT been adopted both DECLARE the class on line 1, asserted =${e_marked:- (none)}. WHICH HALF RAN ON THIS TREE: ${lived_why:+the marker half was NOT MEASURED — }${lived_why:-both halves ran; this tree carries no adoption signal}${lived_why:+, and that is the signal that decided it}. A fabricated root document — never the real ones, which this harness does not write to — proves the discriminator ACCEPTS a marked document and REJECTS both a deleted marker and an absent file, with each mutation asserted to have applied before its effect is believed."
  teardown
}

# =============================================================================
# CASE — A REFORMAT OF A DERIVED SEAM DECLARATION IS REFUSED LOUDLY, NEVER ABSORBED.
#
# Four names are parsed out of two files by nine anchored expressions in five files.
# The shape those expressions assume was an undeclared contract between files that never
# mention each other, until config-seam.md § 2 wrote it down.
#
# THE MUTATION HERE IS SEMANTICS-PRESERVING, AND THAT IS THE ENTIRE POINT. Dropping the
# outer double quotes from `NAME="${NAME:-v}"` is identical to the shell — an assignment
# RHS is not word-split — and invisible to every anchored sed. So the value keeps working
# while every derivation of it silently returns nothing. A case that changed the VALUE
# would be testing the value; this one tests the SHAPE, which is the thing that can break
# without looking broken.
#
# case_ship_state guards the same shape by exact-line comparison, but it SKIPS on an
# adopted tree — precisely where adopters live. This case does not skip.
# =============================================================================
case_seam_shape_reformat_is_loud() {
  cf_reset
  if ! has_issue_template; then skp "a reformatted seam declaration is refused loudly" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # kit-init needs a prepared .claude/ and a published trunk; a bare make_sandbox gives
  # neither and it refuses at PREFLIGHT with three unmet preconditions — a refusal that
  # would satisfy every "it refused" assertion below for entirely the wrong reason.
  kit_init_sandbox
  publish_sandbox
  local c="$SB_WORK/scripts/config.sh" k="$SB_WORK/scripts/lib/kanban-worktree.sh"
  local out rc eff

  # ── INSTRUMENT CHECK, first: kit-init SUCCEEDS on this fixture UNMUTATED. Without this
  #    the case cannot tell a shape refusal from a fixture that never worked. Run in a
  #    throwaway copy so the real sandbox stays unstamped for the mutations below.
  local pristine="$SB_TMP/seam-pristine"
  rm -rf "$pristine"; cp -R "$SB_WORK" "$pristine"
  rc=0; out="$( "$pristine/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || _fixture_die "case_seam_shape_reformat_is_loud: kit-init exits $rc on the UNMUTATED fixture — every refusal this case asserts would be free. Output: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  perl -i -pe 's/^ISSUE_PREFIX="\$\{ISSUE_PREFIX:-([^}]*)\}"$/ISSUE_PREFIX=\${ISSUE_PREFIX:-$1}/' "$c"
  grep -qxF "ISSUE_PREFIX=\${ISSUE_PREFIX:-$KIT_NEUTRAL_PREFIX}" "$c" \
    || _fixture_die "case_seam_shape_reformat_is_loud: the reformat did not apply — the declaration moved and this case is mutating nothing."
  # COMMIT IT. kit-init refuses a dirty checkout before it reads anything, and that
  # refusal would satisfy "(a) it refused" while proving nothing about the shape.
  git -C "$SB_WORK" add -A && sbcommit -q -m "reformat the ISSUE_PREFIX declaration" >/dev/null 2>&1

  # ── INSTRUMENT CHECK. Prove the mutation changed the SHAPE and not the VALUE. If
  #    sourcing yields something different, every refusal below is attributable to a
  #    changed value and this case proves nothing about the shape.
  eff="$( . "$c" >/dev/null 2>&1; printf '%s' "$ISSUE_PREFIX" )"
  if [ "$eff" != "$KIT_NEUTRAL_PREFIX" ]; then
    skp "a reformatted seam declaration is refused loudly" \
        "sourcing the reformatted config.sh yields '$eff', not '$KIT_NEUTRAL_PREFIX' — the mutation is not semantics-preserving here, so a refusal below would not be about the shape"
    teardown; return
  fi

  # EFFECT (a) — kit-init REFUSES and NAMES the file. Not "proceeds on an empty default".
  rc=0; out="$( "$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(a) kit-init.sh exited 0 with an unparseable ISSUE_PREFIX declaration — it proceeded on an empty default"
  printf '%s' "$out" | grep 'config\.sh' >/dev/null || cf "(a) the refusal does not NAME scripts/config.sh: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-140)"
  grep -q 'ISSUE_PREFIX:-SBX' "$c" && cf "(a) config.sh was STAMPED during a refusal — the run mutated before it checked"

  # EFFECT (b) — the SAME for the other declaring file. Four consumers parse this one and
  #    it is not in the seam file at all, which is how it kept escaping the guard.
  perl -i -pe 's/^KWT_TRUNK_LAST_RESORT="\$\{KWT_TRUNK_LAST_RESORT:-([^}]*)\}"$/KWT_TRUNK_LAST_RESORT=\${KWT_TRUNK_LAST_RESORT:-$1}/' "$k"
  grep -q '^KWT_TRUNK_LAST_RESORT=\${' "$k" \
    || _fixture_die "case_seam_shape_reformat_is_loud: the lib reformat did not apply — that declaration moved too."
  git -C "$SB_WORK" add -A && sbcommit -q -m "reformat the trunk last-resort declaration" >/dev/null 2>&1
  rc=0; out="$( "$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(b) kit-init.sh exited 0 with an unparseable KWT_TRUNK_LAST_RESORT declaration"

  # EFFECT (c) — the READ-ONLY consumer degrades ANNOUNCED, never to a guessed branch.
  #    With both auto-detections removed, check-board has nothing but the declaration left.
  git -C "$SB_WORK" symbolic-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
  git -C "$SB_WORK" config --unset init.defaultBranch >/dev/null 2>&1 || true
  out="$( cd "$SB_WORK" && "$SB_WORK/scripts/check-board.sh" 2>&1 )" || true
  printf '%s' "$out" | grep -F '<unresolved trunk>' >/dev/null \
    || cf "(c) check-board.sh did not announce the unresolved trunk: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-140)"

  finish "a semantics-preserving reformat of either derived seam declaration — config.sh's or the lib's — is refused loudly by kit-init.sh naming the file, and announced rather than guessed by the read-only consumer; the value still sources correctly, which is what makes the shape the thing under test"
  teardown
}

# =============================================================================
# CASE — A PUBLISHED EXIT-CODE TABLE IS AN INSTRUCTION TO BRANCH, AND NOTHING DROVE ONE.
# =============================================================================
# ── THE PROGRAMS THAT DECLARE A CALLER-BRANCHABLE EXIT-CODE TABLE. ───────────────────────────
#
# DERIVED, NOT NAMED, and the derivation is the point of the case below rather than a flourish.
# The gap this case closes is not "stall.sh has no test" — it is a CLASS: a shipped program that
# publishes a table of exit codes has told every caller to BRANCH on them, and a code nothing
# drives is a branch nobody has ever taken. `-ne 0` is not a substitute: the whole content of a
# table is that the nonzero codes MEAN DIFFERENT THINGS, so an assertion that collapses them
# asserts the one thing the table denies.
#
# THE SHAPE, and why it is this narrow. A declaring program writes its table as header comment
# lines of the form `#   <code>  <word…>` — an EXIT STATUS (0-255) in the first comment column,
# followed by prose, two or more of them, and the set STARTING AT 0. That is a structural
# property of the text rather than a name list or a phrase match: a program that starts
# publishing a table joins this population by writing one, and one that stops publishing leaves.
#
# THE TWO NARROWINGS WERE MEASURED, NOT REASONED, AND THEY ARE NOT A CONJUNCTION — that was
# written here first and was false. The draft predicate read any `#   <digits>  <word>` line
# inside the leading comment block and collected THIS FILE's own byte-count table — `200 cards
# 12231 …` — as a set of exit codes. The comment-block bound did not help, because this harness's
# header is one unbroken block with that table inside it. So two narrowings went in: the value
# must be a possible exit status (0-255), and the set must begin at 0, because a program that
# tells callers to branch publishes its SUCCESS code.
#
# RUN SEPARATELY AGAINST THE SHIPPED TREE, EACH ONE ALONE ALREADY YIELDS THE SAME TWO MEMBERS —
# the byte counts are four digits AND never include a 0 row, so either test excludes them. The
# pair is kept deliberately and the redundancy is the reason, not an oversight: they fail on
# different future text (a three-digit measurement that happens to start at 0; a small-number
# table that is not exit codes), and a derivation whose only narrowing is the one this tree
# happened to need is a derivation tuned to one file. What must NOT be written here is that both
# are required to reach two — nothing measured says so.
#
# WHAT IT DOES NOT CLAIM. It reads the leading comment block only, so a table written further
# down is invisible — disclosed in the finish line rather than silently excluded, because a
# derivation that cannot say where it stopped looking is a name list wearing a loop.
#
# Prints `<rel-path> <code> <code>…` per declaring program, codes ascending and unique.
_exit_code_tables() {  # reads the manifest; one line per shipped program that declares a table
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST" rel codes
  [ -f "$man" ] || return 0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$(head -1 "$REAL_REPO_ROOT/$rel" 2>/dev/null)" in '#!'*) ;; *) continue ;; esac
    # THE SPAN IS THE LEADING COMMENT BLOCK — every line up to the first that is neither a
    # comment nor blank. That bound alone is NOT what excludes a measurement table, and saying
    # so here is the correction: this harness's own header is one unbroken comment block with a
    # byte-count table inside it, and the bound admitted it. The VALUE RANGE below is what
    # excludes it.
    codes="$(awk '
        NR>1 && !/^#/ && !/^[[:space:]]*$/ { exit }
        /^#[[:space:]]+(0|[1-9][0-9]?|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[[:space:]]+[A-Za-z]/ {
          gsub(/^#[[:space:]]+/,""); print $1 }
      ' "$REAL_REPO_ROOT/$rel" 2>/dev/null | sort -un | tr '\n' ' ')"
    # A TABLE IS TWO CODES OR MORE. One number in a header is a sentence, not a table, and
    # nothing branches on a single answer.
    [ "$(printf '%s' "$codes" | wc -w | tr -d ' ')" -ge 2 ] || continue
    # ...AND IT STARTS AT 0. A program that tells callers to branch publishes its SUCCESS code;
    # a run of small numbers that never mentions 0 is a list of something else.
    case "$codes" in '0 '*) ;; *) continue ;; esac
    printf '%s %s\n' "$rel" "${codes% }"
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF
}

case_declared_exit_codes_are_driven() {
  cf_reset
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  [ -f "$man" ] \
    || _fixture_die "case_declared_exit_codes_are_driven: process/KIT-MANIFEST is absent, which the startup guard should already have refused."

  # ── THE POPULATION, derived once and used twice: to say who is in it, and to say which of
  #    their codes this file actually drives. Both halves are below; neither is typed.
  local pop; pop="$(_exit_code_tables)"
  [ -n "$pop" ] \
    || _fixture_die "case_declared_exit_codes_are_driven: not one shipped program was found declaring an exit-code table. The header shape this derivation reads has moved, so the case would report PASS over an empty set — which is exactly the silence it exists to break."

  # ── THE DRIVEN ARMS. TWO members of the population are driven end to end here, and each is
  #    here for its own reason rather than because the list grew.
  #
  #    `scripts/notify/stall.sh` — its table is the one whose CODES CARRY THE MEANING:
  #    0/3/1 are moving / stalled / unknown, and the third is a different answer from the
  #    second rather than a worse version of it. Collapsing unknown into stalled is how a
  #    watchdog earns a reputation for false alarms and then gets muted — so a test that only
  #    proved "nonzero when quiet" would leave the defect that matters unguarded.
  #
  #    `scripts/finish-pr.sh` — the same shape with a MUTATED TRUNK behind it instead of a muted
  #    alarm. Its 1 says "nothing landed, safe to re-run" and its 3 says "LANDED, do NOT re-run":
  #    opposite instructions, not degrees. A caller that collapses 3 into 1 re-runs a landing that
  #    already happened. Unlike stall.sh it is not opt-in — it IS the landing path — so its 3 is
  #    reachable on every project running the kit.
  local sub="scripts/notify/stall.sh"
  local fpr="scripts/finish-pr.sh"
  local driven="" fpr_driven="" undriven=""
  # NO PIPED `grep -q` — this file's own header rule, and `$pop` is a producer that grows with
  # the population, which is exactly the class the rule names. Tested as a string instead.
  local _s
  for _s in "$sub" "$fpr"; do
    case "
$pop" in *"
$_s "*) : ;; *)
      cf "(instrument) $_s is not in the derived population, so every arm below is about a program this case can no longer say declares a table — the header shape moved, or the manifest stopped naming it" ;;
    esac
  done

  local out rc

  # ── (a) SOMETHING ON THE REMOTE IS NEWER THAN THE THRESHOLD → 0, `moving`.
  make_sandbox
  publish_sandbox
  out="$( cd "$SB_WORK" && ./scripts/notify/stall.sh --quiet-minutes 90 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(a) a remote whose newest head is minutes old exited $rc, want 0: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  case "$out" in *moving*) driven="$driven 0" ;; *)
    cf "(a) the clearing line never says 'moving', so a caller reading the text cannot tell a clearance from a stall: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)" ;;
  esac
  # THE SPAN ON THE CLEARING BRANCH (doctrine/instruments.md § A.4): a clearance with no
  # subject is read as covering whatever the reader had in mind.
  case "$out" in *"$SB_TRUNK"*) : ;; *)
    cf "(a) the clearing line does not name the ref it measured, so 'moving' covers whatever the reader assumes it covers: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)" ;;
  esac
  case "$out" in *head*) : ;; *)
    cf "(a) the clearing line does not say how many heads it walked — a clearance over an unstated span" ;;
  esac

  # ── (d) HEAD IS NOT THE SIGNAL, and it rides arm (a)'s sandbox because it is the same
  #        question asked of a worse tree. A branch that is NOT checked out is advanced on the
  #        remote and HEAD is left where it was; the answer must still be `moving`.
  #        This is the arm that catches someone "simplifying" `git ls-remote` into a local
  #        rev-parse — a monitor keyed on HEAD once reported a dead project that was working
  #        normally, 697 minutes against 1, and that measurement is the reason the program
  #        reads every head instead of one.
  local sideref="liveness-side"
  git -C "$SB_WORK" push --quiet origin "HEAD:refs/heads/$sideref" >/dev/null 2>&1
  # THE PLANT IS A DATE, NOT A PUSH ORDER. Backdating the CHECKED-OUT tip is what makes HEAD
  # stale; the side branch keeps the fresh date. Without this the two are the same commit and
  # the arm passes on a tree where HEAD would have answered correctly too.
  GIT_COMMITTER_DATE="2020-01-01T00:00:00 +0000" GIT_AUTHOR_DATE="2020-01-01T00:00:00 +0000" \
    sbcommit --allow-empty -m "[$SB_ROLE] backdate the checked-out tip" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push --quiet --force origin "$SB_TRUNK" >/dev/null 2>&1
  local head_age; head_age="$(git -C "$SB_WORK" show -s --format=%ct HEAD 2>/dev/null || echo 0)"
  [ "$head_age" -lt "$(( $(date +%s) - 86400 ))" ] \
    || _fixture_die "case_declared_exit_codes_are_driven: the backdated HEAD is not actually old, so arm (d) would pass on a tree where HEAD is a perfectly good signal and would prove nothing."
  out="$( cd "$SB_WORK" && ./scripts/notify/stall.sh --quiet-minutes 90 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] \
    || cf "(d) HEAD IS BEING READ AS THE SIGNAL: the checked-out tip is backdated to 2020 while '$sideref' on the remote is minutes old, and this exited $rc rather than 0. A program that walks every head cannot see the backdated one as the answer: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  case "$out" in *"$sideref"*) : ;; *)
    cf "(d) the report does not name '$sideref' as the newest ref, so even a green here does not say the non-checked-out branch was what it measured: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)" ;;
  esac
  teardown

  # ── (b) NOTHING NEWER THAN THE THRESHOLD → 3, `STALLED`, naming the age and the threshold.
  #        The fixture builds its own dated commit rather than growing a date parameter on a
  #        shared seeder: the subject here is a REMOTE, and a dated commit in every other
  #        case's fixture is a cost those cases did not ask for.
  make_sandbox
  GIT_COMMITTER_DATE="2020-01-01T00:00:00 +0000" GIT_AUTHOR_DATE="2020-01-01T00:00:00 +0000" \
    publish_sandbox
  local newest; newest="$(git -C "$SB_ORIGIN" log -1 --format=%ct "refs/heads/$SB_TRUNK" 2>/dev/null || echo 0)"
  [ "$newest" -gt 0 ] && [ "$newest" -lt "$(( $(date +%s) - 86400 ))" ] \
    || _fixture_die "case_declared_exit_codes_are_driven: the remote's newest head is not older than a day (committer date '$newest'), so arm (b) would be asserting a stall over a tree that is not quiet."
  out="$( cd "$SB_WORK" && ./scripts/notify/stall.sh --quiet-minutes 90 2>&1 )"; rc=$?
  if [ "$rc" -eq 3 ]; then driven="$driven 3"; else
    cf "(b) a remote whose newest head predates the threshold by years exited $rc, want 3. A watchdog that cannot report a stall is the original defect with a program in front of it: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  case "$out" in *STALLED*) : ;; *)
    cf "(b) the finding never says STALLED, so an operator reading the line cannot tell it from a clearance: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;;
  esac
  case "$out" in *"threshold 90m"*) : ;; *)
    cf "(b) the finding does not restate the threshold it was judged against, so a reader cannot tell an alarm from a mis-set flag: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;;
  esac

  # ── (e) `--notify` REACHING NOBODY MUST BE LOUD, and it rides arm (b) because a stall is the
  #        only branch that delivers. A stall report that was computed and not delivered is the
  #        original defect with an extra step, so the FINDING must still print and the failure
  #        to deliver must be stated in the same breath.
  rm -f "$SB_WORK/scripts/notify.sh"
  out="$( cd "$SB_WORK" && ./scripts/notify/stall.sh --quiet-minutes 90 --notify 2>&1 )"; rc=$?
  [ "$rc" -eq 3 ] \
    || cf "(e) with no notify.sh to dispatch to, --notify changed the VERDICT to $rc — delivery is not the finding, and a watchdog that downgrades its own answer because the phone was off has lost the thing it computed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  case "$out" in *STALLED*) : ;; *)
    cf "(e) the finding itself disappeared when delivery failed — computed and then swallowed, which is the defect the program exists to end: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;;
  esac
  case "$out" in *"reached nobody"*|*"NOT DELIVERED"*) : ;; *)
    cf "(e) --notify reached nobody and said so nowhere: the operator is left believing a report was sent. Silence on a failed delivery is indistinguishable from a delivery: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;;
  esac
  teardown

  # ── (c) THE ARM THAT MATTERS: A REMOTE THAT CANNOT BE READ → 1, `UNKNOWN`, NEVER 3.
  #        Three routes to unreadable, because they fail in three different places in the
  #        program and one of them is the instrument check. Driving one and claiming the code
  #        is covered is the single-observation habit this repository keeps paying for.
  make_sandbox
  publish_sandbox
  local label
  for label in undeclared vanished empty; do
    local remote_arg="origin"
    case "$label" in
      undeclared) remote_arg="no-such-remote-declared-anywhere" ;;
      vanished)   git -C "$SB_WORK" remote add vanished "$SB_TMP/never-created.git" >/dev/null 2>&1
                  remote_arg="vanished" ;;
      empty)      git init --bare "$SB_TMP/nothing.git" >/dev/null 2>&1
                  git -C "$SB_WORK" remote add emptyremote "$SB_TMP/nothing.git" >/dev/null 2>&1
                  remote_arg="emptyremote" ;;
    esac
    out="$( cd "$SB_WORK" && ./scripts/notify/stall.sh --quiet-minutes 90 --remote "$remote_arg" 2>&1 )"; rc=$?
    if [ "$rc" -eq 3 ]; then
      cf "(c/$label) AN UNREADABLE REMOTE WAS REPORTED AS A STALL (exit 3). Unknown and alive are different answers and so are unknown and stalled: a watchdog that cannot tell 'nothing moved' from 'I could not look' raises an alarm every time the network hiccups, and the operator who mutes it has muted the real one too: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    elif [ "$rc" -eq 0 ]; then
      cf "(c/$label) an unreadable remote was CLEARED (exit 0) — the quieter half of the same defect, and the worse one: nobody is told anything at all: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    elif [ "$rc" -ne 1 ]; then
      cf "(c/$label) an unreadable remote exited $rc, want 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
    else
      driven="$driven 1"
    fi
    case "$out" in *UNKNOWN*) : ;; *)
      cf "(c/$label) the exit code says unknown and the TEXT does not, so an operator watching the log rather than the status learns nothing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;;
    esac
  done
  teardown

  # ── (f) USAGE ERROR → 2, the fourth declared code. Cheap here and NOT redundant with the
  #        CLI-shape sweep: that case proves an unknown OPTION exits 2, while the table also
  #        declares 2 for a missing required value — and this program's threshold is required
  #        with no default on purpose, so the refusal is the behaviour.
  make_sandbox
  publish_sandbox
  out="$( cd "$SB_WORK" && ./scripts/notify/stall.sh 2>&1 )"; rc=$?
  if [ "$rc" -eq 2 ]; then driven="$driven 2"; else
    cf "(f) omitting the required --quiet-minutes exited $rc, want 2. A threshold with a silent default is this program inventing a cadence for a project it knows nothing about, and an alarm on a borrowed number fires through every night until somebody mutes it: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  case "$out" in *"--quiet-minutes"*) : ;; *)
    cf "(f) the refusal does not name the option it wanted, leaving the caller with a stop and no next step: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" ;;
  esac
  out="$( cd "$SB_WORK" && ./scripts/notify/stall.sh --quiet-minutes ninety 2>&1 )"; rc=$?
  [ "$rc" -eq 2 ] \
    || cf "(f) a non-numeric threshold exited $rc, want 2 — an unparsed threshold that runs anyway compares against an arithmetic accident: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  teardown

  # ═══ scripts/finish-pr.sh — THE SECOND SUBJECT. Four arms, one per declared code. ═══
  #
  # WHY ALL FOUR AND NOT JUST 3. The accounting below is ALL-OR-NOTHING PER SUBJECT: it walks the
  # codes the program's own header declares and reds on any the arms here did not drive. So a
  # subject that drives 3 alone reds on 0, 1 and 2 — and the only ways out are to hand-type an
  # exemption list (which turns a derived accounting into a name list with a loop, the exact
  # failure this case's header refuses) or to drive the rest. Driving the rest is cheaper than
  # arguing, and the overlap with the case_finish_pr_* family is NAMED rather than discovered:
  #
  #   * `case_finish_pr_happy` lands green and asserts `-eq 0`, so arm (g) genuinely repeats it;
  #   * `case_finish_pr_empty_merge` asserts `-ne 0`, which is NOT the same assertion as `-eq 1`
  #     — this case's own header says so in as many words ("`-ne 0` is not a substitute … an
  #     assertion that collapses them asserts the one thing the table denies"). Arm (h) is the
  #     first thing in this harness to assert finish-pr's 1 as a VALUE;
  #   * nothing anywhere asserted 2 or 3 for this program before these arms.
  #
  # The overlap is not redundancy. Those cases assert BEHAVIOUR (what moved, what did not, what
  # the board note claims); these assert the CODE AS A PUBLISHED BRANCH INSTRUCTION, and they are
  # what the accounting reads. A cross-case accounting would need `$driven` to survive a
  # teardown, and nothing in this harness carries state between cases.

  # ── (g) A COMPLETE LANDING → 0.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-384" codes chore "Exit-code table: complete landing" "feature/$SB_PREFIX-384-codes"
  publish_sandbox
  seed_branch "$SB_PREFIX-384" codes CODES.txt
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-384" 2>&1 )"; rc=$?
  if [ "$rc" -eq 0 ]; then fpr_driven="$fpr_driven 0"; else
    cf "(g) a landing that squashed, pushed, retired the branch and advanced the board exited $rc, want 0. A green run reported nonzero is the direction that gets the code ignored: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  teardown

  # ── (h) REFUSED WITH NOTHING LANDED → 1, AND THE TRUNK MUST BE UNTOUCHED. The premise of the
  #        1 row is "safe to fix the cause and re-run", and that is only true if nothing landed —
  #        so the arm asserts the trunk as well as the code. The route is an empty merge: a branch
  #        with no net change vs the trunk, which finish-pr aborts AFTER the squash attempt and
  #        BEFORE any push.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-385" codes chore "Exit-code table: nothing to land" "feature/$SB_PREFIX-385-codes"
  publish_sandbox
  git -C "$SB_WORK" branch "feature/$SB_PREFIX-385-codes" "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/$SB_PREFIX-385-codes" --quiet >/dev/null 2>&1
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-385" 2>&1 )"; rc=$?
  if [ "$rc" -eq 1 ]; then fpr_driven="$fpr_driven 1"; else
    cf "(h) a branch with no net change exited $rc, want 1. 1 is the code that PROMISES nothing landed; any other value here either denies a true refusal or claims a landing that did not happen: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  # THE PROMISE THE CODE MAKES, ASSERTED SEPARATELY FROM THE CODE.
  origin_has_path "progress/qa_complete/$SB_PREFIX-385-codes.md" \
    && cf "(h) exit 1 was returned and the card IS in qa_complete/ on the trunk — the code promises nothing landed and something did"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$SB_PREFIX-385-codes" 2>/dev/null)" ] \
    || cf "(h) exit 1 was returned and the feature branch was deleted from the remote anyway — a refusal that destroys state is not the refusal the 1 row describes"
  teardown

  # ── (i) USAGE ERROR → 2. A leading '-' where the issue id goes: the program's own header calls
  #        2 "nothing was read or touched", and this is the refusal that fires before any read.
  make_sandbox
  publish_sandbox
  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh --no-such-option 2>&1 )"; rc=$?
  if [ "$rc" -eq 2 ]; then fpr_driven="$fpr_driven 2"; else
    cf "(i) an unknown option exited $rc, want 2. 2 and 1 are the difference between 'you typed it wrong' and 'the landing was refused', and a caller that cannot tell them apart retries a typo: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  fi
  teardown

  # ── (j) THE ARM THIS SUBJECT IS HERE FOR: LANDED BUT NOT FINISHED → 3, NEVER 1.
  #
  #    THE PLANT IS NOT A STUB, AND THAT IS THE WHOLE DESIGN PROBLEM. A fixture that replaces the
  #    landing with something that returns 3 asserts the code and not the meaning — the meaning is
  #    that THE SQUASH IS ON THE TRUNK. So this arm runs the landing for real, end to end: the real
  #    pre-merge gate, a real `git merge --squash` with real net changes, a real push to a real bare
  #    remote. Nothing about steps 1-3 is faked.
  #
  #    WHAT IS BROKEN IS STEP 4, AND IT IS BROKEN IN THE TREE RATHER THAN IN THE PROGRAM.
  #    finish-pr's step 4 is `move-issue.sh <id> qa_complete`, and move-issue refuses when the
  #    DESTINATION COLUMN does not exist in the kanban worktree ("progress/qa_complete/ does not
  #    exist in the worktree"). The kanban worktree is a fresh checkout of the trunk, so deleting
  #    `progress/qa_complete/` from the TRUNK before publishing makes the board advance fail on a
  #    tree that is otherwise entirely healthy. This is a real adopter state, not a contrivance:
  #    git does not track an empty directory, so a board whose columns were never given a .gitkeep
  #    does not survive a clone — which is precisely why kit-init.sh writes one per column.
  #
  #    AND THE SANDBOX SURVIVES THE HALF-FINISHED STATE, which is what lets the assertions read it:
  #    the trunk is a bare repository holding a landing whose cleanup never ran.
  make_sandbox
  seed_issue dev_complete "$SB_PREFIX-386" codes chore "Exit-code table: landed, not finished" "feature/$SB_PREFIX-386-codes"
  # THE PLANT. Remove the destination column from the tree BEFORE it is published, so the trunk
  # the kanban worktree checks out has never had one.
  rm -rf "$SB_WORK/progress/qa_complete"
  publish_sandbox
  seed_branch "$SB_PREFIX-386" codes LANDED.txt
  # THE PLANT IS REAL, CONFIRMED ON THE REMOTE. Asserted rather than assumed: if the column were
  # still on the trunk the landing would simply succeed and this arm would assert 3 against a run
  # that had no reason to return it, reporting a defect in finish-pr that is really a fixture that
  # forgot to plant anything.
  origin_has_path "progress/qa_complete/.gitkeep" \
    && _fixture_die "case_declared_exit_codes_are_driven: arm (j) planted a missing qa_complete/ column and the trunk still carries one, so the board advance would succeed and the arm would be asserting 3 over a healthy landing."

  out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" ./scripts/finish-pr.sh "$SB_PREFIX-386" 2>&1 )"; rc=$?
  if [ "$rc" -eq 3 ]; then fpr_driven="$fpr_driven 3"; else
    if [ "$rc" -eq 1 ]; then
      cf "(j) A LANDING THAT REACHED THE TRUNK WAS REPORTED AS 1 — the code whose own header row says 'nothing landed, safe to fix the cause and re-run'. The 3 row forbids that re-run in the same breath. An automation reading 1 here re-runs finish-pr against a branch that is already merged: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
    elif [ "$rc" -eq 0 ]; then
      cf "(j) a landing whose board advance FAILED exited 0 — the quieter half of the same defect and the worse one: the caller is told the run is complete and the card is still sitting in dev_complete/: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
    else
      cf "(j) a landing whose board advance failed exited $rc, want 3: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
    fi
  fi

  # ── THE MEANING, NOT THE CODE. Three assertions, and they are what separate this arm from a stub.
  # (1) THE SQUASH IS GENUINELY ON THE TRUNK. Without this the 3 above could have been returned by
  #     a run that landed nothing, which is the 1 row, and the arm would be asserting the opposite
  #     of what it claims.
  origin_has_path "LANDED.txt" \
    || cf "(j) exit 3 says LANDED BUT NOT FINISHED and the branch's change is NOT on the trunk — either nothing landed (making 3 the wrong code) or this fixture reached 3 without a landing, which would assert the code and not the meaning"
  # (2) THE FOLLOW-UP GENUINELY DID NOT COMPLETE. The card must still be where it started.
  origin_has_path "progress/dev_complete/$SB_PREFIX-386-codes.md" \
    || cf "(j) the card is no longer in dev_complete/ on the trunk, so the follow-up step did not fail — 3 was returned over a run that finished"
  # (3) THE TEXT SAYS BOTH HALVES. A caller reading the log rather than the status must be told the
  #     trunk moved AND told not to re-run; the exit code alone is the half nobody reads first.
  case "$out" in *"LANDED, NOT FINISHED"*|*"IS LANDED"*) : ;; *)
    cf "(j) the run never says the landing happened, so an operator reading the output cannot tell this from an ordinary refusal: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)" ;;
  esac
  case "$out" in *"DO NOT re-run"*|*"do NOT re-run"*) : ;; *)
    cf "(j) the run does not tell the operator NOT to re-run the script, which is the one instruction the 3 row exists to deliver: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)" ;;
  esac
  teardown

  # ── THE ACCOUNTING. Every code each subject DECLARES must have been driven above, and the
  #    comparison is derived on both sides: the declared set comes out of the program's own
  #    header, the driven set out of the arms that ran. A code added to the table and to no arm
  #    reds here rather than sitting in the header as a promise nobody keeps.
  #
  #    PER SUBJECT, NOT POOLED. The two programs' tables overlap numerically and mean entirely
  #    different things — stall.sh's 3 is STALLED and finish-pr's 3 is LANDED BUT NOT FINISHED —
  #    so a single pooled `driven` set would let an arm for one program discharge the other's
  #    obligation. Both declare 0 1 2 3 today, which is exactly the tree on which a pooled
  #    accounting would look green while half the arms were missing.
  local declared c
  local _pair
  for _pair in "$sub|$driven" "$fpr|$fpr_driven"; do
    local _who="${_pair%%|*}" _got="${_pair#*|}" _missing=""
    declared="$(printf '%s\n' "$pop" | awk -v s="$_who" '$1==s{$1="";print}')"
    for c in $declared; do
      case " $_got " in *" $c "*) : ;; *) _missing="$_missing $c" ;; esac
    done
    [ -z "$_missing" ] \
      || { undriven="$undriven $_who:$_missing"
           cf "$_who declares exit code(s) no arm here drives —$_missing. A published code is an instruction to callers to branch on it; a code nothing drives is a branch nobody has ever taken"; }
  done

  # ── THE SECOND DIRECTION, and it is the one that makes this a population rather than a test.
  #    Every OTHER declaring program is named with its codes and with the fact that this case
  #    does not drive them. That is a disclosure, not a failure: naming the rest of the class is
  #    how the next member gets a case instead of a silence, and a finish line that said "the
  #    shipped set" while driving one member would be the claim this harness has been burned by.
  #
  #    THE EXCLUSION IS DERIVED FROM THE DRIVEN SET, not from a second list of subject names. The
  #    driven subjects are `$sub` and `$fpr`; a third one added above and forgotten here would be
  #    announced as undriven, which is the safe direction — a member wrongly named as driven is
  #    the silence this disclosure exists to break.
  local others="" _skip
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    _skip=""
    for _s in "$sub" "$fpr"; do
      case "$line" in "$_s "*) _skip=yes ;; esac
    done
    [ -z "$_skip" ] || continue
    others="$others ${line%% *}(${line#* })"
  done <<EOF
$pop
EOF

  finish "TWO declaring programs are DRIVEN, one arm per declared code each, against sandboxes this case builds itself. scripts/notify/stall.sh: newer-than-threshold clears with 0 and names the ref and the head count; nothing-newer reports 3 naming the age and the threshold; an unreadable remote reports 1 and UNKNOWN by THREE routes (a remote never declared, one whose repository is gone, one that advertises no heads at all) and NEVER 3 — unknown and stalled are different answers and a watchdog that confuses them gets muted; a missing or non-numeric threshold refuses with 2; plus a backdated checked-out tip beside a minutes-old branch nobody checked out still reading as moving, naming that branch, so HEAD cannot be the signal, and --notify with nothing to dispatch to still printing the finding, still exiting 3, and saying out loud that it reached nobody. scripts/finish-pr.sh: a complete landing exits 0; a branch with no net change exits 1 AND the trunk is asserted untouched, because 'safe to re-run' is only true if nothing landed; an unknown option exits 2; and a landing whose BOARD ADVANCE fails exits 3 and never 1 — the plant is a trunk published without a progress/qa_complete/ column, so the squash, the push and the branch retirement all happen FOR REAL and only step 4 breaks, and the arm then asserts the meaning rather than the code: the branch's change IS on the trunk, the card is still in dev_complete/, and the output says both that it landed and that the operator must not re-run. The codes asserted are compared PER SUBJECT against the table each program's own header declares — never pooled, because both tables read 0 1 2 3 and mean different things — so a code added there and nowhere here reds. THE POPULATION IS DERIVED from every shipped program whose header declares a table of two or more codes; the members this case does NOT drive are named rather than dropped, and their codes with them:${others:- (none — these are the only declaring programs the manifest names)}. NOT MEASURED: a table written below the header block, which this derivation does not read; and for finish-pr, the OTHER routes to each code — 1 has several refusal sites and only the empty merge is driven, and 3 has exactly one author (a failing move-issue.sh) which is the site driven here"
}

# =============================================================================
# CASE — THE SHIPPED MANIFEST DESCRIBES THIS TREE, AND THE COPY-LIST IS INSIDE IT.
#
# The zip carries process/KIT-MANIFEST: <sha256>  <path>  <class>, one row per shipped file,
# generated at build and never tracked. It exists because every guard in this file that asks a
# question about "the shipped scripts" answers it from a GLOB, and on a tree that has adopted the
# kit a glob cannot tell a kit file from a file the adopter was TOLD to add. Measured on a built
# day-one tree: the interpreter-floor case reports 25 shipped scripts on the pristine kit and 26
# after adoption, having counted the adopter's own gate runner and called it shipped.
#
# THIS CASE DOES NOT REWRITE THOSE POPULATIONS — that is a separate change, and it is what the
# manifest is FOR. What this case does is make the manifest trustworthy enough to build on:
# it is present, it is non-empty, every path it names exists, it excludes itself, and it is a
# SUPERSET of the hand-typed minimum kit-init refuses without. That last arm is the one that
# would catch a shipped file being dropped from the build while the initializer still demands it.
#
# WHY IT SKIPS RATHER THAN FAILS WITH NO MANIFEST. The manifest is a property of the BUILT ZIP;
# it does not exist in the kit's source repository, where this harness is already unsupported.
# A skip that NAMES the file is honest about which tree it is looking at; a failure there would
# be this harness reporting a defect in a tree nobody ships.
# =============================================================================
case_shipped_manifest_describes_the_tree() {
  cf_reset
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST"
  # NOT A SKIP. The startup guard above refuses the whole run without this file, so reaching
  # here without it is impossible — and a dead branch that says "skip" would be a standing
  # invitation to delete the startup guard and let the population cases go quiet instead of red.
  [ -f "$man" ] \
    || _fixture_die "case_shipped_manifest_describes_the_tree: process/KIT-MANIFEST is absent, which the startup guard should already have refused. Either that guard was removed or something deleted the manifest mid-run; either way every population case below derives from it."

  local n=0 missing="" self=0 rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    n=$(( n + 1 ))
    [ "$rel" = "process/KIT-MANIFEST" ] && self=1
    [ -e "$REAL_REPO_ROOT/$rel" ] || missing="$missing $rel"
  done <<EOF
$(grep -v '^#' "$man" | awk '{print $2}')
EOF

  # ── INSTRUMENT CHECK: a manifest that named nothing would satisfy every arm below.
  #    The floor is not a typed number: it is the COMPARISON that the manifest is non-empty and
  #    that its rows outnumber the copy-list minimum it must contain.
  [ "$n" -gt 0 ] \
    || cf "(instrument) process/KIT-MANIFEST holds no path rows — every assertion in this case would be vacuously true over an empty set"

  [ -z "$missing" ] \
    || cf "the manifest names path(s) that do not exist in this tree —$missing. The manifest describes the artifact or it describes nothing"

  [ "$self" -eq 0 ] \
    || cf "the manifest lists ITSELF, which cannot be right: its own hash is not knowable while it is being written, so the row is either wrong or the exclusion broke"

  # ── The copy-list minimum must be a SUBSET of the manifest. Both sides derived: the list is
  #    read out of kit-init.sh's own COPY_LIST array rather than retyped here, so a file added to
  #    that array and never shipped is caught, and this case cannot drift from it.
  local ki="$REAL_SCRIPTS/kit-init.sh" f absent="" cl=0
  if [ -f "$ki" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      cl=$(( cl + 1 ))
      grep -v '^#' "$man" | awk '{print $2}' | grep -xF "$f" >/dev/null || absent="$absent $f"
    done <<EOF
$(awk '/^COPY_LIST=\(/{f=1;next} f&&/^\)/{exit} f{gsub(/^[[:space:]]+|[[:space:]]+$/,""); if($0!="") print}' "$ki")
EOF
    # ── INSTRUMENT CHECK: the extractor found the array. A COPY_LIST that was renamed or
    #    reshaped yields zero entries, and "every entry is in the manifest" is then true of
    #    nothing — the exact shape this case exists to refuse elsewhere.
    [ "$cl" -gt 0 ] \
      || cf "(instrument) no entries were extracted from kit-init.sh's COPY_LIST — the array was renamed or reshaped, so the subset assertion below covers nothing"
    [ -z "$absent" ] \
      || cf "kit-init.sh REFUSES to run without these file(s) and the shipped manifest does not name them —$absent. Either the build stopped shipping a file the initializer demands, or COPY_LIST names something that never travelled"
  else
    cf "scripts/kit-init.sh is absent, so the copy-list subset arm could not run — and this case's whole point is that the two agree"
  fi

  finish "process/KIT-MANIFEST names $n shipped path(s), every one of which exists in this tree; it excludes itself; and all $cl entries of kit-init.sh's own COPY_LIST minimum are inside it — both sides of that comparison derived, neither retyped here"
}

# =============================================================================
# A RESTATED RULE IS COPIED ONLY WHERE ITS CANONICAL SITE SAYS
# =============================================================================
# A RULE-COPIES block at a rule's canonical site names its key sentence and its deliberate copies.
# Each listed file must carry the key; no unlisted shipped file may. Matching is on folded text:
# lines joined, comment leaders, `*` and backticks dropped, whitespace collapsed, case ignored.
# Not scanned: process/KIT-RELEASE-NOTES.md (a dated record) and scripts/test/ (it asserts rules).
_rule_copies_begin='^[[:space:]]*(<!--[[:space:]]*|#[[:space:]]*)?RULE-COPIES:BEGIN'

_rule_fold() {  # <root> <rel>... — "<rel><TAB><folded text>" per file, RULE-COPIES blocks dropped
  local root="$1"; shift
  ( cd "$root" && LC_ALL=C awk -v b="$_rule_copies_begin" '
      function emit() { gsub(/[[:space:]]+/, " ", buf); print f "\t" tolower(buf) }
      FNR == 1 { if (f != "") emit(); f = FILENAME; buf = ""; skip = 0 }
      $0 ~ b { skip = 1 }
      skip { if ($0 ~ /RULE-COPIES:END/) skip = 0; next }
      { sub(/^[[:space:]]*(#+|\/\/+|\*+|>+)?[[:space:]]*/, ""); gsub(/[*`]/, ""); buf = buf " " $0 }
      END { if (f != "") emit() }
    ' "$@" )
}

_rule_registers() {  # <root> <rel>... — "<canonical><TAB><key><TAB><copies>" per RULE-COPIES block
  local root="$1"; shift
  ( cd "$root" && LC_ALL=C awk -v b="$_rule_copies_begin" '
      $0 ~ b { inb = 1; k = ""; c = ""; next }
      inb && /RULE-COPIES:END/ { print FILENAME "\t" k "\t" c; inb = 0; next }
      inb { l = $0; sub(/^[[:space:]]*#?[[:space:]]*/, "", l); sub(/[[:space:]]+$/, "", l)
            if (l ~ /^key: /) k = substr(l, 6); else if (l ~ /^copies: /) c = substr(l, 9) }
    ' "$@" )
}

_rule_findings() {  # <root> <fold file> <registers> — one finding per line; none means the tree holds
  local root="$1" fold="$2" canon key copies lkey c hit
  while IFS="$(printf '\t')" read -r canon key copies; do
    [ -n "$canon" ] || continue
    if [ -z "$key" ] || [ -z "$copies" ]; then echo "$canon: a RULE-COPIES block without a 'key:' or 'copies:' line"; continue; fi
    lkey="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')"
    for c in $canon $copies; do
      [ -f "$root/$c" ] || { echo "$canon lists $c, which is not in the tree"; continue; }
      awk -F'\t' -v f="$c" -v k="$lkey" '$1 == f && index($2, k) { h = 1 } END { exit !h }' "$fold" \
        || echo "$c does not carry the key sentence of $canon's rule: '$key'"
    done
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      case " $canon $copies " in *" $hit "*) ;; *) echo "$hit carries the key sentence of $canon's rule and is not listed there: '$key'" ;; esac
    done <<RULE_HITS_EOF
$(awk -F'\t' -v k="$lkey" 'index($2, k) { print $1 }' "$fold")
RULE_HITS_EOF
  done <<RULE_REGS_EOF
$3
RULE_REGS_EOF
}

case_restated_rules_are_registered() {
  cf_reset
  make_sandbox
  local man="$REAL_REPO_ROOT/process/KIT-MANIFEST" rel files=()
  while IFS= read -r rel; do
    case "$rel" in ''|process/KIT-RELEASE-NOTES.md|scripts/test/*) continue ;; esac
    [ -f "$REAL_REPO_ROOT/$rel" ] && files+=("$rel")
  done <<RULE_MAN_EOF
$(grep -v '^#' "$man" | awk '{print $2}')
RULE_MAN_EOF
  local regs nregs
  regs="$(_rule_registers "$REAL_REPO_ROOT" "${files[@]}")"
  nregs="$(printf '%s\n' "$regs" | grep -c . || true)"
  [ "${nregs:-0}" -gt 0 ] \
    || _fixture_die "case_restated_rules_are_registered: no RULE-COPIES block in ${#files[@]} shipped file(s) — the case has no operand."

  _rule_fold "$REAL_REPO_ROOT" "${files[@]}" > "$SB_TMP/fold" \
    || _fixture_die "case_restated_rules_are_registered: could not fold the shipped tree."
  local found; found="$(_rule_findings "$REAL_REPO_ROOT" "$SB_TMP/fold" "$regs")"
  [ -z "$found" ] || cf "$(printf '%s' "$found" | tr '\n' '|')"

  # ── THE REDDENING CONTROL, on a COPY of the first rule's files: empty one listed copy and plant
  #    the key in an unlisted file; both must be named.
  local ctl="$SB_TMP/ctl" canon key copies c victim=""
  IFS="$(printf '\t')" read -r canon key copies <<RULE_CTL_EOF
$regs
RULE_CTL_EOF
  for c in $canon $copies; do
    mkdir -p "$ctl/$(dirname "$c")" && cp "$REAL_REPO_ROOT/$c" "$ctl/$c" || true
    [ "$c" = "$canon" ] || [ -n "$victim" ] || victim="$c"
  done
  if [ -z "$victim" ] || [ ! -f "$ctl/$victim" ]; then
    _control_did_not_run "copy a registered copy to empty"
  else
    : > "$ctl/$victim"
    printf '%s\n' "$key" > "$ctl/planted.md"
    # shellcheck disable=SC2086  # the lists are space-separated paths by declaration
    _rule_fold "$ctl" $canon $copies planted.md > "$SB_TMP/ctlfold"
    local planted; planted="$(_rule_findings "$ctl" "$SB_TMP/ctlfold" "$(_rule_registers "$ctl" "$canon")")"
    printf '%s\n' "$planted" | grep -F "$victim does not carry" >/dev/null \
      || cf "(control) emptying the registered copy $victim was not reported: ${planted:-(nothing)}"
    printf '%s\n' "$planted" | grep -F "planted.md carries" >/dev/null \
      || cf "(control) the key planted in an unlisted file was not reported: ${planted:-(nothing)}"
  fi

  finish "$nregs restated rule(s) declared in RULE-COPIES blocks: every listed copy carries its key sentence, no unlisted shipped file does, and an emptied copy and a planted echo are both named"
  teardown
}
