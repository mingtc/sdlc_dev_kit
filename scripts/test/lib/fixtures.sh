# KIT-CLASS: MIXED — self-test harness, the shared fixtures. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/lib/fixtures.sh — sourced by scripts/test/run.sh, never run on its own.
# The fixtures every case family builds on: the neutral config, the PASS/FAIL/SKIP
# recorders, make_sandbox and the seeders, the seam neutralizers (_neu_*, _kit_neutral_*), the
# origin_* readers, and the anchored plant helpers.
# =============================================================================

# ── THE NEUTRAL CONFIG — the kit's SHIPPED value for every seam the sandbox copies in,
#    declared here and DERIVED FROM NOTHING IN THE ADOPTER'S TREE. make_sandbox copies the
#    real scripts/ in, config blocks and all; _kit_neutral_config resets them to these, so a
#    case asserts the kit's frame rather than this repository's configuration.
#
#    THESE MUST EQUAL WHAT THE KIT SHIPS, and case_ship_state asserts the real files still
#    carry them. If it reddens, correct the SHIPPED file or this constant — never only this
#    constant, or the harness certifies its own assumption.
KIT_NEUTRAL_PREFIX="KIT"
KIT_NEUTRAL_PRD_PREFIX="PRD"
KIT_NEUTRAL_PROJECT_NAME="<project name>"

# THE ROLE SET THE KIT SHIPS. DECLARED, not derived: `kit-init --roles` rewrites every copy
# of the alternation under scripts/, so an adopted tree has no unstamped source left to read.
# case_ship_state keeps it honest.
KIT_NEUTRAL_ROLE_PREFIXES='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'

# THE SCAFFOLDING SENTINEL, DECLARED — the whole line the two shipped root documents carry.
# Not derived from those documents: both are REPLACE-class, so on an adopted tree they are
# gone and a derivation would stop the harness from starting. check-board.sh's probe for this
# literal is asserted by case_scaffolding_fixture_matches_the_tree arm (b), and the shipped
# documents by arm (a) wherever a shipped copy survives. It is the WHOLE LINE, matched with
# `grep -qxF`, so a backticked mention of the token in prose cannot satisfy it.
KIT_SCAFFOLD_MARK='<!-- BOOTSTRAP-SCAFFOLDING — a tool reads this line. It goes when this file goes. -->'

# THE REPLACE DISPOSITION DECLARATION, which arm (g1) uses to SELECT its population while
# KIT_SCAFFOLD_MARK is the TEST it applies. A fixture must write both, or the arm correctly
# skips it.
KIT_REPLACE_DISPOSITION='KIT-DISPOSITION: REPLACE'

# THE FILL DISPOSITION: arm (g2) counts blanks only in a PROJECT.md that declares FILL, so a
# fixture that wants the FILL finding must write the declaration the shipped sheet carries.
KIT_FILL_DISPOSITION='KIT-DISPOSITION: FILL'

# ── The seam values this harness runs against. ───────────────────────────────
# SB_PREFIX is the NEUTRAL prefix, not the adopter's: the sandbox's scripts resolve
# KIT_NEUTRAL_PREFIX, and cards seeded with any other prefix would disagree with them.
SB_PREFIX="$KIT_NEUTRAL_PREFIX"
SB_TRUNK="$(git -C "$REAL_REPO_ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
if [ -z "$SB_TRUNK" ]; then
  SB_TRUNK="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                "$REAL_SCRIPTS/lib/kanban-worktree.sh" 2>/dev/null | head -1)"
fi
# NO SECOND DEFAULT HERE (`config-seam.md` § 2): if the declaration's shape moved, a fallback
# would build every sandbox on a trunk name read from nowhere. Die instead.
if [ -z "$SB_TRUNK" ]; then
  echo "FIXTURE: could not read the trunk from origin/HEAD, and the KWT_TRUNK_LAST_RESORT" >&2
  echo "         declaration in scripts/lib/kanban-worktree.sh did not parse either." >&2
  echo "         The declaration shape is contracted (process/contracts/config-seam.md § 2)." >&2
  echo "         Refusing to invent a trunk name: every sandbox below would be built on it." >&2
  exit 1
fi
# The first role of the set the SANDBOX runs — the kit's shipped set, which _neu_roles
# resets it to.
SB_ROLE="${KIT_NEUTRAL_ROLE_PREFIXES%%|*}"

# ── The CONSUMER_SCRIPT seam. Point it at this project's vendoring/updater script
#    to activate the consumer-updater family; leave it empty and that family SKIPs.
CONSUMER_SCRIPT="${CONSUMER_SCRIPT:-}"

# --- Result accounting -------------------------------------------------------
PASS=0; FAIL=0; SKIP=0; LIVED=0
declare -a RESULTS
ok()   { PASS=$((PASS+1)); RESULTS+=("PASS  $1"); printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); RESULTS+=("FAIL  $1${2:+ — $2}"); printf '  \033[31mFAIL\033[0m  %s%s\n' "$1" "${2:+ — $2}"; }
skp()  { SKIP=$((SKIP+1)); RESULTS+=("SKIP  $1${2:+ — $2}"); printf '  \033[33mSKIP\033[0m  %s%s\n' "$1" "${2:+ — $2}"; }

# ── N/A ON A LIVED TREE — a FOURTH outcome kind, and a CLOSED one. ────────────
#
# Some cases assert a file's shape AS THE KIT SHIPS IT. On a tree past day one that shape is
# legitimately gone (filled, replaced or stamped), so the case has no subject: not a PASS,
# not a FAIL, and not a SKIP, which the adopted-tree comparison S(adopted) = S(pristine)
# would absorb. Do not widen such a case to accept the shipped shape OR the adopted one: it
# then passes on every tree and measures neither.
#
# THE REASON MUST NAME THE FILE whose shipped shape is absent, or skp_lived refuses it as a
# FAIL. It is a SHAPE test (a token with a known extension); it does not check the file
# exists, because a DELETE-IF-UNUSED member removed on day one is exactly this case.
_lived_names_a_file() {  # <reason>
  printf '%s' "${1:-}" | grep -E '[A-Za-z0-9_-]\.(md|sh|json|js|py|txt|yml|yaml|example|skeleton|template)([^A-Za-z0-9]|$)' >/dev/null
}
skp_lived() {  # <case finish line> <why the subject is absent on a tree that has lived>
  if ! _lived_names_a_file "${2:-}"; then
    bad "$1" "REFUSED by skp_lived: the reason must NAME THE FILE whose shipped shape is absent, and this one names none — '${2:-}'. A reason that names no file cannot be checked by anyone, which is how a case goes N/A forever. (The check is a SHAPE test: a token with a known file extension. It does not verify the file exists.)"
    return
  fi
  LIVED=$((LIVED+1)); RESULTS+=("N/A   $1 — $2"); printf '  \033[36mN/A\033[0m   %s — %s\n' "$1" "$2"
}

# Per-case failure accumulator. A case notes each unmet check, then finalizes
# with ok/bad based on whether anything was noted.
_cf=""
cf() { _cf="${_cf}${_cf:+; }$1"; }
cf_reset() { _cf=""; }
finish() { if [ -z "$_cf" ]; then ok "$1"; else bad "$1" "$_cf"; fi; }

# --- Sandbox construction ----------------------------------------------------
# Sets globals: SB_TMP (temp root), SB_WORK (work repo), SB_ORIGIN (bare remote).
SB_TMP=""; SB_WORK=""; SB_ORIGIN=""
teardown() { [ -n "$SB_TMP" ] && rm -rf "$SB_TMP" 2>/dev/null; SB_TMP=""; }
trap teardown EXIT

# Commit in the work repo BYPASSING the role-prefix hook (setup commits are
# infrastructure, not role work). Board-script commits still go through the hook
# naturally and carry [Role] prefixes.
sbcommit() { MSG_OK=1 git -C "$SB_WORK" commit "$@"; }

# seed_issue <folder> <id> <slug> <type> <title> [branch]
# The frontmatter must match the shipped templates' key set, `pr:` included, because
# `--set-pr` writes back only into an existing `pr:` line. This hand-written seed is not
# evidence the templates produce it: case_move_issue_set_pr_on_a_minted_card mints from the
# real template for that.
# ONE AC bullet + a matching, well-formed '## QA Verdict' table (a PASS row with real-looking
# evidence, plus the required 'shadow-check' row): finish-pr.sh's QA-Verdict landing precondition
# reads both, so every existing landing case keeps working without being touched individually.
seed_issue() {
  local folder="$1" id="$2" slug="$3" type="$4" title="$5" branch="${6:-n/a}"
  local f="$SB_WORK/progress/$folder/${id}-${slug}.md"
  cat > "$f" <<EOF
---
id: ${id}
type: ${type}
title: ${title}
branch: ${branch}
pr: null
created_at: 2026-01-01
created_by: PM
forks: none
---

# ${id} — ${title}

## Acceptance Criteria

- [ ] AC1 — the sandbox's seeded behaviour holds.

## QA Verdict

| AC id | verdict | evidence kind | evidence pointer |
|---|---|---|---|
| AC1 | PASS | test | sandbox-gate-green |
| shadow-check | — | — | assertions removed: none |

## Activity

- 2026-01-01 [PM] Seeded for the sandbox self-test.
EOF
}

# make_sandbox [work_subdir]
# The optional arg names the work-repo subdirectory under the temp root (default
# "work"). Pass a name CONTAINING A SPACE (e.g. "work dir") to reproduce a repo
# path with a space — an unquoted command expansion word-splits on it, which is a
# real defect class this harness carries a dedicated case for.
make_sandbox() {
  SB_TMP="$(mktemp -d)"
  SB_ORIGIN="$SB_TMP/origin.git"
  SB_WORK="$SB_TMP/${1:-work}"

  git init --bare "$SB_ORIGIN" >/dev/null 2>&1
  git -C "$SB_ORIGIN" symbolic-ref HEAD "refs/heads/$SB_TRUNK" >/dev/null 2>&1

  git init "$SB_WORK" >/dev/null 2>&1
  git -C "$SB_WORK" symbolic-ref HEAD "refs/heads/$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" config user.email "test@sandbox.invalid" >/dev/null 2>&1
  git -C "$SB_WORK" config user.name  "Sandbox Test"         >/dev/null 2>&1
  git -C "$SB_WORK" config init.defaultBranch "$SB_TRUNK"    >/dev/null 2>&1
  git -C "$SB_WORK" config commit.gpgsign false              >/dev/null 2>&1

  # Copy the scripts-under-test in (never symlink — the sandbox must own them so
  # they resolve the sandbox as their root).
  cp -R "$REAL_SCRIPTS" "$SB_WORK/scripts"

  # ...and the rest of the shipped executable surface, so a case can execute consumers/ and
  # setup.sh. Guarded: an adopter may have deleted either, and the population accounting in
  # case_cli_shape_across_the_shipped_set reports a shipped program gone missing.
  # NOT COPIED: .claude/, process/, docs/ and the root documents. Cases needing .claude/ build
  # it (kit_init_sandbox), and cases reading process/ read the REAL tree on purpose.
  [ -d "$REAL_REPO_ROOT/consumers" ] && cp -R "$REAL_REPO_ROOT/consumers" "$SB_WORK/consumers"
  [ -f "$REAL_REPO_ROOT/setup.sh" ]  && cp "$REAL_REPO_ROOT/setup.sh" "$SB_WORK/setup.sh"

  # scripts/test/ is REMOVED, deliberately: a nested harness run would build and tear down
  # sandboxes inside this one while its case_isolation measured a tree the outer run is
  # rewriting. So nothing here executes run.sh, and case_cli_shape_across_the_shipped_set
  # lists it as unreached on every run.
  rm -rf "$SB_WORK/scripts/test"
  # ...and reset every config-block seam `cp` just carried in (see _kit_neutral_config).
  # PLACEMENT IS LOAD-BEARING: it must run BEFORE _declare_sandbox_gate, which declares the
  # sandbox's gate into the emptied GATES table. case_kit_init_gate_and_remote_refusals(a)
  # needs that declared table, and would pass without its premise if this ran last.
  _kit_neutral_config

  mkdir -p "$SB_WORK/progress/todo" "$SB_WORK/progress/in_progress" \
           "$SB_WORK/progress/dev_complete" "$SB_WORK/progress/qa_complete" \
           "$SB_WORK/progress/blocked" "$SB_WORK/progress/done" \
           "$SB_WORK/progress/declined" "$SB_WORK/progress/history"
  # THIS LITERAL LIST STAYS. A builder's list that drifts leaves a fixture incomplete and fails
  # loudly; a guard's list that drifts goes blind, which is why _lived_signals
  # (cases/check-board.sh) derives its columns and this does not. STATUS_FOLDERS is not the
  # answer: `history` is deliberately not a status folder, and a list derived from it alone
  # would silently stop creating progress/history/.
  for d in todo in_progress dev_complete qa_complete blocked done declined history; do
    : > "$SB_WORK/progress/$d/.gitkeep"
  done

  cat > "$SB_WORK/ARCHIVE.md" <<'EOF'
# ARCHIVE.md — condensed index of completed issues

## Archived
EOF

  # A gate runner the landing path can actually pass. The shipped frame ships with
  # an EMPTY table and refuses on purpose, so every sandbox that lands a branch
  # declares one echo gate — the harness is testing finish-pr.sh here, not the
  # project's real suite.
  _declare_sandbox_gate

  # Activate the role-prefix hook in the sandbox (this also applies to .kanban-wt,
  # which shares this repo's config).
  git -C "$SB_WORK" config core.hooksPath "$SB_WORK/scripts/githooks" >/dev/null 2>&1
}

# =============================================================================
# FIXTURE MUTATION, AND THE ONE RULE ALL OF IT OBEYS
#
# EVERY MUTATION ASSERTS. A `perl -i -pe` whose anchor does not match EXITS 0 AND LEAVES THE
# FILE UNCHANGED, so a moved anchor silently yields a sandbox that was never set up, and the
# case built on it reports PASS. A mutation that cannot find its anchor is therefore FATAL
# to the run (_fixture_die), not a case failure: `cf` is for the subject misbehaving.
#
#   • A mutation that ADDS or CHANGES content asserts THE CONTENT ARRIVED
#     (_declare_sandbox_gate, rel_insert, rel_set).
#   • The NEUTRALIZER asserts ITS ANCHOR WAS FOUND and ITS POSTCONDITION HOLDS, never "the
#     file changed": on the kit's own tree the config arrays already ship empty and nothing
#     should change.
#
# ASK OF EVERY CASE AND GUARD: where does each operand come from, and is it the same tree,
# the same moment and the same authority as the others?

# A fixture that did not take aborts the run. Loudly, naming what it could not do.
_fixture_die() {
  {
    echo
    echo "════════ FIXTURE FAILURE — the sandbox was not set up ════════"
    echo "  $1"
    echo
    echo "  This is NOT a case failure. Every case after this point would assert a"
    echo "  premise that does not exist, and would report PASS while doing it."
    echo "  Aborting rather than printing a green about the wrong subject."
  } >&2
  exit 1
}

# Declare ONE gate record in the sandbox's copy of verify.sh. Self-asserting, and
# the single place the GATES anchor is written — _declare_sandbox_gate and every case
# that needs a bespoke gate go through here rather than repeating the perl.
# <record> is the bare `name|class|command…` text; the quoting and indent are added.
_declare_gate() {
  local rec_body="$1" v="$SB_WORK/scripts/verify.sh" rec
  rec="  \"$rec_body\""
  grep -qE '^GATES=\($' "$v" \
    || _fixture_die "_declare_gate: no '^GATES=(' line in the sandbox's verify.sh — the anchor moved, so gate '$rec_body' was NOT declared and anything downstream would run against an empty, REFUSING gate runner."
  # BEGIN{shift}, not $ENV{}: one convention across every parameterised mutator, and the
  # record stays out of a child's environment.
  perl -i -pe 'BEGIN{$r=shift} $_ .= "  \"$r\"\n" if /^GATES=\($/' "$rec_body" "$v"
  grep -qxF "$rec" "$v" \
    || _fixture_die "_declare_gate: '$rec_body' is not in verify.sh after the insert."
}

# Insert one always-green `select` gate into the sandbox's copy of verify.sh.
_declare_sandbox_gate() {
  _declare_gate 'sandbox gate|select|/bin/echo sandbox-gate-green'
}

# =============================================================================
# THE NEUTRALIZER. Reset every CONFIG-BLOCK seam the sandbox inherited from this
# repository back to the kit's shipped state, so a case measures the FRAME.
#
# RESET VALUES, NEVER DELETE LINES: kit-init.sh reads the current ISSUE_PREFIX and
# PROJECT_NAME defaults out of config.sh and hard-exits without them. The one deletion is
# kit-init's appended stamp receipt, one of its ALREADY-LIVED signals, which would make
# every kit-init case refuse before reaching its subject.

# The stamp receipt kit-init appends to config.sh. DERIVED from kit-init.sh rather
# than re-typed, per this harness's own contract for every other seam it reads.
KIT_STAMP_MARK="$(sed -n "s/^STAMP_MARK='\(.*\)'/\1/p" "$REAL_SCRIPTS/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$KIT_STAMP_MARK" ] || KIT_STAMP_MARK='# Stamped by scripts/kit-init.sh'

# The prefix placeholder the shipped templates and role docs carry (`<PREFIX>-NNN`), and the
# classification marker's key, which only LOOKS like the prefix. Both derived from
# kit-init.sh like KIT_STAMP_MARK; the fallbacks serve a tree with no kit-init.sh, where the
# kit-init family SKIPs anyway.
KIT_PREFIX_PLACEHOLDER="$(sed -n "s/^PREFIX_PLACEHOLDER='\(.*\)'/\1/p" "$REAL_SCRIPTS/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$KIT_PREFIX_PLACEHOLDER" ] || KIT_PREFIX_PLACEHOLDER='<PREFIX>'
KIT_CLASS_MARKER_KEY="$(sed -n "s/^CLASS_MARKER_KEY='\(.*\)'/\1/p" "$REAL_SCRIPTS/kit-init.sh" 2>/dev/null | head -1)"
[ -n "$KIT_CLASS_MARKER_KEY" ] || KIT_CLASS_MARKER_KEY='KIT-CLASS:'

# This tree's CURRENT issue prefix, read with kit-init.sh's own anchored sed — the
# same expression, so a change to the config line's shape breaks both together
# rather than leaving this one quietly matching nothing. On the shipped frame this
# reads the neutral prefix; in an adopted project it reads what kit-init stamped,
# and THAT is the token the sandbox's copied templates and role docs carry.
KIT_TREE_PREFIX="$(sed -n 's/^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([^}]*\)}"/\1/p' "$REAL_SCRIPTS/config.sh" 2>/dev/null | head -1)"
# Empty here is NOT a benign miss. The `[ -n "$KIT_TREE_PREFIX" ]` branch downstream simply
# SKIPS when this is empty, so a shape change would silently switch off a whole neutralizer
# rather than reporting one — the exact class this seam's contract exists to prevent.
if [ -z "$KIT_TREE_PREFIX" ]; then
  echo "FIXTURE: the ISSUE_PREFIX declaration in scripts/config.sh did not parse." >&2
  echo "         Its shape is contracted (process/contracts/config-seam.md § 2)." >&2
  echo "         Refusing to continue: the tree-prefix neutralizer would silently do nothing." >&2
  exit 1
fi

# _neu_scalar <file> <VAR> <exact replacement line>
_neu_scalar() {
  local f="$1" var="$2" line="$3"
  [ -f "$f" ] || _fixture_die "_neu_scalar: $f does not exist in the sandbox."
  grep -qE "^${var}=" "$f" \
    || _fixture_die "_neu_scalar: no '^${var}=' line in ${f##*/} — the key was renamed or moved out of the config block, so it was NOT neutralized and the case would assert this repository's value."
  perl -i -pe 'BEGIN{$v=shift; $r=shift} s/^\Q$v\E=.*$/$r/' "$var" "$line" "$f"
  grep -qxF "$line" "$f" \
    || _fixture_die "_neu_scalar: ${var} in ${f##*/} does not read '${line}' after the reset."
}

# _neu_array_records <file> <ARRAY> → count of non-comment, non-blank lines inside
# the array's ( … ) fence. This is the neutralizer's postcondition instrument, so
# it is deliberately separate and readable.
_neu_array_records() {
  awk -v a="$2" '
    $0 == a "=(" { inb = 1; next }
    inb && /^\)/ { inb = 0 }
    inb && !/^[[:space:]]*#/ && NF { n++ }
    END { print n + 0 }
  ' "$1"
}

# THE ADOPTION SIGNAL, ONE AUTHORING SITE, shared by case_ship_state and
# case_scaffolding_fixture_matches_the_tree arm (e) so the two cannot disagree about one
# tree. Returns the signal that fired, so a case that declines to measure can say why
# (process/doctrine/instruments.md § A.4).
_tree_has_lived() {   # -> the signal that fired, or empty for a tree that has not been adopted
  local rv="$REAL_SCRIPTS/verify.sh" rc_cfg="$REAL_SCRIPTS/config.sh" n
  if [ -f "$rc_cfg" ] && grep -q "^$KIT_STAMP_MARK" "$rc_cfg" 2>/dev/null; then
    printf '%s' "scripts/config.sh carries kit-init's stamp receipt — this tree has been adopted"
    return 0
  fi
  if [ -f "$rv" ]; then
    n="$(_neu_array_records "$rv" GATES)"
    if [ "$n" -ne 0 ]; then
      printf '%s' "scripts/verify.sh declares $n gate(s) — this project has filled its own table"
      return 0
    fi
  fi
  return 0
}

# Does <root>'s <doc> declare the kit class on line 1? The discriminator arm (a) narrows itself
# by, lifted out so it can be run against a FABRICATED root in the control below — the real
# root documents are never mutated, because this harness must not write outside its sandbox.
_root_doc_is_shipped_copy() {   # <root> <doc>
  local l1
  [ -f "$1/$2" ] || return 1
  l1="$(sed -n '1p' "$1/$2")"
  case "$l1" in
    *"$KIT_CLASS_MARKER_KEY KIT"*) return 0 ;;
    *) return 1 ;;
  esac
}

# _neu_array <file> <ARRAY> — empty a config array's RECORDS, keeping its
# `NAME=(` / `)` fence and every explanatory comment inside it. The fence must
# survive: _declare_sandbox_gate, rel_insert and kit-init's --gate-command fill
# all anchor on `^NAME=($`, and the comments are the config block's documentation.
_neu_array() {
  local f="$1" name="$2" before after
  [ -f "$f" ] || _fixture_die "_neu_array: $f does not exist in the sandbox."
  grep -qE "^${name}=\($" "$f" \
    || _fixture_die "_neu_array: no '^${name}=(' line in ${f##*/} — the array was renamed or reshaped, so emptying it did NOTHING and every case downstream would run against this repository's declared ${name}."
  before="$(_neu_array_records "$f" "$name")"
  perl -i -ne 'BEGIN{$a=shift}
    if (/^\Q$a\E=\($/) { $in = 1; print; next }
    if ($in && /^\)/)  { $in = 0; print; next }
    next if ($in && !/^\s*#/ && /\S/);
    print' "$name" "$f"
  after="$(_neu_array_records "$f" "$name")"
  [ "$after" -eq 0 ] \
    || _fixture_die "_neu_array: ${name} in ${f##*/} still holds ${after} record(s) after neutralizing (it held ${before} before)."
  grep -qE "^${name}=\($" "$f" \
    || _fixture_die "_neu_array: emptying ${name} in ${f##*/} destroyed its own '${name}=(' fence."
}

# =============================================================================
# THE SECOND NEUTRALIZER — the .claude/ tree the kit-init cases copy in.
#
# Separate from _kit_neutral_config because .claude/ does not exist yet when make_sandbox
# runs. EVERY SITE THAT COPIES THE REAL .claude/ TREE INTO A SANDBOX CALLS THIS, immediately
# after the copy.
#
# kit-init stamps the issue prefix into .claude/templates/ and scripts/config.sh together,
# and _kit_neutral_config resets only config.sh. Without this, an adopted project's sandbox
# holds templates saying `XYZ-NNN` beside a config saying `KIT`, kit-init substitutes
# nothing, and case_kit_init_happy reds.
#
# WHAT IT RESTORES: only the prefix in its ID SHAPE (`<PREFIX>-`), the one stamp whose reverse
# is decidable. NOT a bare prefix token in prose, `<trunk>` or `<project name>`: each was
# stamped blanket, and reversing it would rewrite ordinary words. No kit-init assertion reads
# them; one that grows such an assertion needs its own invertible reverse, not a wider sed.
# =============================================================================
_kit_neutral_claude() {
  local root="$SB_WORK/.claude" f tpl mk_before mk_after
  # A scratch token, not a shared vocabulary: it only has to be absent from the
  # corpus for the length of one sed, so it is spelled here rather than derived.
  local sentinel='@@KITTESTCLASSKEY@@'
  [ -d "$root" ] || return 0

  # Reverse kit-init's prefix stamp, and ONLY on a tree that carries one: on the shipped
  # frame KIT_TREE_PREFIX is the neutral prefix and nothing should change. A project that
  # stamped the shipped prefix leaves `KIT-NNN`, which kit-init's OLD_PREFIX branch handles.
  if [ -n "$KIT_TREE_PREFIX" ] && [ "$KIT_TREE_PREFIX" != "$KIT_NEUTRAL_PREFIX" ]; then
    mk_before="$(grep -roF "$KIT_CLASS_MARKER_KEY" "$root" 2>/dev/null | wc -l | tr -d ' ')"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      # kit-init.sh's protect/restore idiom run backwards, in one sed per file: hide the
      # marker key, restore the prefix, put the key back. `KIT-CLASS:` matches a bare `KIT-`
      # rewrite, and a split protect/restore could leave the sentinel behind on failure.
      sed -i.bak -E -e "s|${KIT_CLASS_MARKER_KEY}|${sentinel}|g" \
                    -e "s|${KIT_TREE_PREFIX}-|${KIT_PREFIX_PLACEHOLDER}-|g" \
                    -e "s|${sentinel}|${KIT_CLASS_MARKER_KEY}|g" "$f"
      rm -f "$f.bak"
    done < <(find "$root" -type f -name '*.md' | sort)
    mk_after="$(grep -roF "$KIT_CLASS_MARKER_KEY" "$root" 2>/dev/null | wc -l | tr -d ' ')"
    # BOTH DIRECTIONS. The restoration must happen AND must not be paid for out of
    # the classification markers; asserting only the first would let the sed that
    # defaces every marker report success.
    [ "$mk_before" = "$mk_after" ] \
      || _fixture_die "_kit_neutral_claude: restoring the prefix placeholder changed the number of '$KIT_CLASS_MARKER_KEY' markers under the sandbox's .claude/ (${mk_before} → ${mk_after}) — the marker's KEY was collateral damage, which is precisely what kit-init.sh's sentinel exists to prevent."
    grep -rqF "$sentinel" "$root" 2>/dev/null \
      && _fixture_die "_kit_neutral_claude: the protect/restore sentinel '$sentinel' survived in the sandbox's .claude/ tree — the restore expression did not run."
  fi

  # THE POSTCONDITION, asserted whether or not anything was restored: the fixture reached
  # ship state on the shipped frame and on an adopted one alike.
  tpl="$root/templates/ISSUE.template.md"
  if [ -f "$tpl" ]; then
    grep -qF "$KIT_PREFIX_PLACEHOLDER" "$tpl" \
      || _fixture_die "_kit_neutral_claude: the sandbox's .claude/templates/ISSUE.template.md does not carry the shipped prefix placeholder '$KIT_PREFIX_PLACEHOLDER' after neutralizing (this tree's ISSUE_PREFIX reads '${KIT_TREE_PREFIX:-<unreadable>}'). The fixture did NOT reach ship state: kit-init inside the sandbox would find nothing to substitute, and every case asserting the stamped id would redden as though kit-init were broken."
  fi
}

# _neu_roles — reset the sandbox's ROLE SET to the kit's shipped alternation, across the
# same seams kit-init stamps and by the same substitution run backwards. The seam list is
# DERIVED, as kit-init derives it.
#
# The sandbox must own its role vocabulary: every --role argument and role-tagged subject in
# the harness is a literal judged against the sandbox's set, and a derived literal cannot
# work, because the hand-off cases need two distinct roles and an adopter's set may have one.
_neu_roles() {
  local cm="$SB_WORK/scripts/githooks/commit-msg" cur f
  [ -f "$cm" ] || return 0
  # FALLBACK POLICY HERE: _fixture_die. See lib/role-set.sh for the canonical read; the
  # EXPRESSION is shared by declaration, the POLICY is each caller's and they differ.
  cur="$(sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$cm" | head -1)"
  [ -n "$cur" ] \
    || _fixture_die "_neu_roles: no ROLE_PREFIXES line in the sandbox's commit-msg — the seam was renamed or moved, so the role vocabulary was NOT neutralized and every --role literal in this harness would be judged against whatever the adopter declared."
  local seams=""
  if [ "$cur" != "$KIT_NEUTRAL_ROLE_PREFIXES" ]; then
    # NON-RECURSIVE, for kit-init's reason: a recursive sweep would also rewrite the
    # harness's own assertions. QUOTED, unlike kit-init's: an adopted set may be a substring
    # of the shipped one ('PM|Dev|QA'), and every seam holds it as '<set>'.
    seams="$( { grep -lF -- "'$cur'" "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null || true; } )"
    [ -n "$seams" ] \
      || _fixture_die "_neu_roles: the sandbox's commit-msg declares '$cur' but NO file under scripts/ carries it — the derivation found nothing to reset, so the role vocabulary is not neutralized and every --role literal in this harness would be judged against whatever the adopter declared."
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      # The '@' delimiter is kit-init's, for kit-init's reason: the value is a
      # '|'-separated ERE alternation and would cut an s|…|…| in half with its own data.
      NEU_CUR="$cur" NEU_NEW="$KIT_NEUTRAL_ROLE_PREFIXES" \
        perl -i -pe 's@\x27\Q$ENV{NEU_CUR}\E\x27@\x27$ENV{NEU_NEW}\x27@g' "$f"
    done <<NEU_SEAM_EOF
$seams
NEU_SEAM_EOF
  fi
  # POSTCONDITION, asserted whether or not anything was rewritten — the anchor-and-property
  # shape, not "something changed": on the kit's own tree the set already IS the shipped
  # one and the correct behaviour is to change nothing.
  grep -qF "ROLE_PREFIXES='$KIT_NEUTRAL_ROLE_PREFIXES'" "$cm" \
    || _fixture_die "_neu_roles: the sandbox's commit-msg does not carry the shipped role set after the reset (it reads '$cur')."
  # AND EVERY OTHER SEAM, not just the one the set is read from: a --role whitelist elsewhere
  # could still enforce the adopter's set.
  if [ -n "$seams" ]; then
    local still
    still="$( { grep -lF -- "'$cur'" "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null || true; } )"
    [ -z "$still" ] \
      || _fixture_die "_neu_roles: $(printf '%s' "$still" | tr '\n' ' ')still carr(y|ies) the adopter's role set '$cur' after the reset — the neutralization reached some seams and not others, and the cases judging --role literals against the shipped set would redden as though the tools were broken."
  fi
  # ── AND A SECOND DERIVATION THAT SHARES NO MATCHER WITH THE REWRITE. The check above uses
  #    the same `grep -lF` that chose what to rewrite, so it cannot see a copy of the set in
  #    another shape, such as a space-padded alternation. This one is shape-insensitive and
  #    keyed on the property: any alternation of capitalized words that shares a member with
  #    the shipped set and is not the shipped set. The rewrite stays literal on purpose:
  #    narrow to CHANGE, wide to CHECK.
  local shaped
  shaped="$(
    { grep -rnoE '[A-Z][A-Za-z]+([[:space:]]*\|[[:space:]]*[A-Z][A-Za-z]+){1,}' \
           "$SB_WORK"/scripts/*.sh "$SB_WORK"/scripts/githooks/* 2>/dev/null || true; } \
    | awk -v ok="$KIT_NEUTRAL_ROLE_PREFIXES" '
        BEGIN { n = split(ok, M, "|"); for (i = 1; i <= n; i++) mem[M[i]] = 1 }
        { a = $0; sub(/^[^:]*:[^:]*:/, "", a)
          gsub(/[[:space:]]*\|[[:space:]]*/, "|", a)
          if (a == ok) next
          k = split(a, T, "|")
          for (i = 1; i <= k; i++) if (T[i] in mem) { print; next } }' \
    | sort -u )"
  [ -z "$shaped" ] \
    || _fixture_die "_neu_roles: a role-set alternation survives the reset in a shape the literal matcher cannot see, so the rewrite missed it AND the check above passed: $(printf '%s' "$shaped" | sed "s@$SB_WORK/@@g" | tr '\n' ' ' | cut -c1-300) — the cases judging --role literals against the shipped set would redden as though the tools were broken."
}

_kit_neutral_config() {
  local c="$SB_WORK/scripts/config.sh"
  local v="$SB_WORK/scripts/verify.sh"
  local r="$SB_WORK/scripts/release.sh"

  # ── config.sh: the three values kit-init.sh stamps on day one. The exact line
  #    SHAPE matters, not just the value — kit-init parses these with anchored
  #    seds (`^ISSUE_PREFIX="\${ISSUE_PREFIX:-\([^}]*\)}"`), so the
  #    `${VAR:-default}` form has to survive verbatim.
  _neu_scalar "$c" ISSUE_PREFIX "ISSUE_PREFIX=\"\${ISSUE_PREFIX:-${KIT_NEUTRAL_PREFIX}}\""
  _neu_scalar "$c" PRD_PREFIX   "PRD_PREFIX=\"\${PRD_PREFIX:-${KIT_NEUTRAL_PRD_PREFIX}}\""
  _neu_scalar "$c" PROJECT_NAME "PROJECT_NAME=\"\${PROJECT_NAME:-${KIT_NEUTRAL_PROJECT_NAME}}\""
  # CODE_GLOBS: this repository's own declared code paths must never leak into a sandbox —
  # every case that wants one declares it itself (case_pre_commit_allows_code_on_a_branch).
  _neu_array "$c" CODE_GLOBS

  # kit-init's appended stamp receipt: remove it, or every kit-init case meets the
  # ALREADY-LIVED refusal on a sandbox that has not lived. No assertion that a line
  # was removed — an unstamped config.sh (this repository's) has none to remove, and
  # that is the healthy state. The POSTCONDITION is what is asserted: absent.
  perl -i -ne 'BEGIN{$m=shift} print unless /^\Q$m\E/' "$KIT_STAMP_MARK" "$c"
  grep -q "^$KIT_STAMP_MARK" "$c" \
    && _fixture_die "_kit_neutral_config: config.sh still carries kit-init's stamp receipt ('$KIT_STAMP_MARK') — every kit-init case would hit the already-lived refusal."

  # ── the role set, across the seams that carry it (derived, as kit-init derives them).
  _neu_roles

  # ── verify.sh: the gate table and the guard floor.
  _neu_array "$v" GATES
  _neu_array "$v" GUARD_SET
  # GUARD_ENUM is a SCALAR, so _neu_array cannot see it — and without this reset a
  # stamped adopter's enumerator command would be carried into every sandbox and every
  # reconciliation case would run against their tree instead of the frame.
  _neu_scalar "$v" GUARD_ENUM 'GUARD_ENUM=""'

  # ── release.sh: four declared arrays and the publish/version scalars. Optional —
  #    release.sh is a capability this harness probes for (has_release), so a kit
  #    without it neutralizes what is there and says nothing about what is not.
  if [ -f "$r" ]; then
    _neu_array "$r" VERSION_FILES
    _neu_array "$r" PREFLIGHT_GATES
    _neu_array "$r" RELEASE_DOCS
    _neu_array "$r" DIST_DOCS
    _neu_scalar "$r" RELEASE_PUBLISH     'RELEASE_PUBLISH=false'
    _neu_scalar "$r" VERSION_IN_TAG_ONLY 'VERSION_IN_TAG_ONLY=false'
    _neu_scalar "$r" DIST_ARTIFACT_GLOB  'DIST_ARTIFACT_GLOB=""'
    _neu_scalar "$r" BUILD_COMMAND       'BUILD_COMMAND="${RELEASE_BUILD_CMD:-}"'
    _neu_scalar "$r" DIST_BRANCH         'DIST_BRANCH="${RELEASE_DIST_BRANCH:-dist}"'
    # An adopter's SHIP_MANIFEST names files that exist only in their tree, so every release
    # case would refuse at gate (g).
    _neu_scalar "$r" SHIP_MANIFEST       'SHIP_MANIFEST=""'
  fi
}

# seed_scaffolding_tree [--no-project]
#
# THE DAY-ONE TREE, stated once. `--no-project` omits PROJECT.md, for a case that needs
# check-board's REPLACE finding without the FILL one. The sentinel is the harness's declared
# KIT_SCAFFOLD_MARK, never derived from check-board.sh's probe (the consumer): a fixture
# derived from the tool agrees with it by construction. It writes the WHOLE shipped line.
seed_scaffolding_tree() {
  local want_project=true
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-project) want_project=false; shift ;;
      *) _fixture_die "seed_scaffolding_tree: unknown argument '$1'" ;;
    esac
  done
  # BOTH HALVES, because arm (g1) needs both: the declaration puts the file in the REPLACE
  # population and the sentinel is the test applied to it (process/EXTRACTION.md § The
  # KIT-DISPOSITION: marker).
  for _sf in CLAUDE.md README.md; do
    {
      printf '<!-- KIT-CLASS: KIT — synthetic scaffolding for the harness.\n'
      printf '     %s — the notice itself is the line below, in the body. -->\n' "$KIT_REPLACE_DISPOSITION"
      printf '%s\n# scaffolding\n' "$KIT_SCAFFOLD_MARK"
    } > "$SB_WORK/$_sf"
  done
  if [ "$want_project" = true ]; then
    # THE DECLARATION FIRST, then the blank: (g2) measures only a sheet that declares FILL.
    printf '<!-- %s — synthetic fill sheet. -->\n# PROJECT.md\n\nTrunk: <trunk>\n' \
      "$KIT_FILL_DISPOSITION" > "$SB_WORK/PROJECT.md"
  fi
}

# Publish the seeded board to the trunk + the remote. Call after seed_issue(s).
publish_sandbox() {
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] seed sandbox board" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" remote add origin "$SB_ORIGIN" >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-head origin "$SB_TRUNK" >/dev/null 2>&1
}

# probe_pick <find-args…> — the FIRST match, WITHOUT a pipe. `find … | head -1` breaks
# run.sh's PIPEFAIL RULE: the value is right and the status is find's SIGPIPE. Callers
# still owe the empty test: a find that fails returns empty and nonzero.
probe_pick() { local all; all="$(find "$@")" || return 1; printf '%s' "${all%%$'\n'*}"; }

# _control_did_not_run <what> — ONE spelling of the refusal that says a control was skipped,
# ending "so the green above is unproven". The noun phrase is the caller's.
_control_did_not_run() {
  cf "(control) could not $1 — the control did not run, so the green above is unproven"
}

# THE ONE FETCH THE THREE origin_* READERS SHARE, AND ITS FAILURE IS A FIXTURE FAILURE.
#
# A STALE remote-tracking ref AND a FAILED fetch together make a reader report a file absent
# from the trunk while the push that put it there landed — a false red about the subject. So
# an unexpected fetch failure dies (_fixture_die) instead of reading as a finding.
#
# A remote the case CHOSE to break is not unexpected: some cases point origin at a local path
# that does not exist, then read the trunk through the cached ref, which is correct. So a
# local URL whose path is absent skips the fetch; a URL that exists and still will not fetch
# dies. A relative URL resolves against the WORKTREE (`../origin.git` exists and is fetched).
origin_fetch_or_die() {
  local url path err
  url="$(git -C "$SB_WORK" remote get-url origin 2>/dev/null || true)"
  case "$url" in
    ''|http*|git@*|ssh:*|git:*) : ;;   # nothing local to stat — let the fetch itself answer
    *)
      path="${url#file://}"
      case "$path" in /*) : ;; *) path="$SB_WORK/$path" ;; esac
      [ -e "$path" ] || return 0       # deliberately unreachable: skip the fetch, read the cache
      ;;
  esac
  err="$(git -C "$SB_WORK" fetch origin "$SB_TRUNK" --quiet 2>&1)" && return 0
  _fixture_die "origin_fetch_or_die: origin resolves to '$path' and the fetch of $SB_TRUNK still failed, so every read of the trunk below would report ABSENT whether or not the content is there — a fixture failure reported as a finding about the subject. git said: $(printf '%s' "$err" | tr '\n' '|' | cut -c1-200)"
}

# On the remote's trunk: does path exist in the tree?
origin_has_path() {
  origin_fetch_or_die
  local paths  # ls-tree grows with the board; the reader below must DRAIN it (header: THE PIPEFAIL RULE)
  paths="$(git -C "$SB_WORK" ls-tree -r --name-only "origin/$SB_TRUNK" 2>/dev/null)"
  printf '%s\n' "$paths" | grep -xF "$1" >/dev/null
}
origin_file_contains() {  # <path> <pattern>
  origin_fetch_or_die
  local body  # the file may be a log that grows; the reader below must DRAIN it (header: THE PIPEFAIL RULE)
  body="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:$1" 2>/dev/null)"
  printf '%s\n' "$body" | grep "$2" >/dev/null
}
origin_log_has_subject() {  # <pattern>
  # THE READER MUST DRAIN ITS INPUT — never `grep -q` behind a pipe (run.sh's PIPEFAIL RULE):
  # `git log` grows with the trunk, and capturing it into `$subjects` does not fix that.
  local subjects
  origin_fetch_or_die
  subjects="$(git -C "$SB_WORK" log "origin/$SB_TRUNK" --format='%s' 2>/dev/null)"
  printf '%s\n' "$subjects" | grep "$1" >/dev/null
}
# A real branch with a real net change, pushed. <id> <slug> <marker-file>
seed_branch() {
  local id="$1" slug="$2" marker="$3"
  git -C "$SB_WORK" checkout -b "feature/${id}-${slug}" "$SB_TRUNK" --quiet >/dev/null 2>&1
  echo "a real change" > "$SB_WORK/$marker"
  git -C "$SB_WORK" add "$marker" >/dev/null 2>&1
  sbcommit -m "[Dev] ${id}: add a real change" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -u origin "feature/${id}-${slug}" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" checkout "$SB_TRUNK" --quiet >/dev/null 2>&1
}
# The stub-marker environment finish-pr.sh honours ONLY for this harness.
FPR_STUB=(FINISH_PR_TEST_ALLOW_STUB=1 FINISH_PR_VERIFY_CMD=true FINISH_PR_PREMERGE_CMD=true)

# _plant_in_function <file> <function-name> <line> <case-name>
#
# THE OTHER ANCHOR FAMILY: plant after `name() {` in a sourced library, then `bash -n` it,
# which tells "the plant changed the behaviour" from "the library no longer loads". The case
# name is an argument so a fixture failure names its own subject.
_plant_in_function() {
  local f="$1" fn="$2" line="$3" who="$4"
  grep -qxF "$fn() {" "$f" \
    || _fixture_die "$who: no '$fn() {' line in ${f##*/} — the anchor moved, so NOTHING was planted and every assertion downstream would be about the unplanted library."
  # Exact-line comparison, not a regex: a function name is matched as a STRING here, so
  # no quoting question arises and no metacharacter can silently match nothing.
  perl -i -pe 'BEGIN{$a=shift; $r=shift} $_ .= "$r\n" if $_ eq "$a() {\n"' "$fn" "$line" "$f"
  grep -qxF "$line" "$f" \
    || _fixture_die "$who: the plant into $fn did not take."
  bash -n "$f" \
    || _fixture_die "$who: the mutated ${f##*/} no longer parses — every consumer would fail to LOAD it, and this case would measure a load error instead of the behaviour under test."
}
