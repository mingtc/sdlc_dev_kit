# KIT-CLASS: MIXED — self-test harness, kit-init and creation cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/kit-init.sh — sourced by scripts/test/run.sh, never run on its own.
# kit-init.sh, the creation scripts and the role set: first mile, option parsing, minted
# cards, role enforcement — and kit_init_sandbox / has_issue_template, which other families call.
# =============================================================================

# =============================================================================
# POST-INIT, THE KIT-CLASS MARKERS ARE INTACT — not rewritten and not deleted
# =============================================================================
# WHY BOTH DIRECTIONS, and this is the raising leg's point: EITHER CHECK ALONE PASSES ON
# A TREE WHERE THE MARKERS WERE DELETED. "No <PREFIX>-CLASS survives" is satisfied by a
# file with no marker at all; "KIT-CLASS is present" is satisfied by a tree where one
# file kept its marker and the rest were rewritten. The pair is the assertion.
#
# The defect: the initializer's prefix substitution rewrote the marker's KEY, so a
# stamped file came out `<!-- SBX-CLASS: KIT — … -->` and every later grep for KIT-CLASS
# found nothing — the classification silently leaving the tree it classifies.
case_kit_init_markers_intact() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: KIT-CLASS markers survive the stamp" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: KIT-CLASS markers survive the stamp" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # THE SAME SETUP THE SIBLING kit-init CASE USES, derived from it rather than
  # re-invented: kit-init needs a prepared .claude/ and a published trunk, and a bare
  # make_sandbox gives neither — it exits 1 with no output, which reads as a defect in
  # the subject rather than in the fixture.
  kit_init_sandbox
  publish_sandbox

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { cf "kit-init exited $rc: $out"; finish "kit-init: KIT-CLASS markers survive the stamp"; teardown; return; }

  local dirs=() d
  for d in "$SB_WORK/.claude/templates" "$SB_WORK/.claude/roles"; do [ -d "$d" ] && dirs+=("$d"); done
  [ "${#dirs[@]}" -gt 0 ] || cf "neither .claude/templates nor .claude/roles exists post-init — the assertion has no operand"

  if [ "${#dirs[@]}" -gt 0 ]; then
    # DIRECTION 1 — the marker is still THERE. Catches deletion, and catches a rewrite.
    local kept; kept="$(grep -rl 'KIT-CLASS' "${dirs[@]}" 2>/dev/null | wc -l | tr -d ' ')"
    [ "$kept" -gt 0 ] \
      || cf "post-init, NO file under .claude/{templates,roles} carries a KIT-CLASS marker — the stamp removed or rewrote the classification off every one"

    # DIRECTION 2 — no PREFIXED variant exists. Names the rewrite specifically; without
    # it, direction 1 alone reports "markers gone" and not "the key was substituted".
    local rewritten; rewritten="$(grep -rn 'SBX-CLASS' "${dirs[@]}" 2>/dev/null || true)"
    [ -z "$rewritten" ] \
      || cf "the prefix substitution rewrote the marker's KEY — a grep for KIT-CLASS will find nothing:
$(printf '%s' "$rewritten" | sed 's/^/      /')"

    # ── REDDENING CONTROL, on a COPY: reproduce the substitution and confirm BOTH arms
    #    fire. Without this the two greens above are compatible with a check that cannot
    #    see the defect at all.
    local probe="$SB_TMP/mkprobe"; rm -rf "$probe"; mkdir -p "$probe"
    cp -R "${dirs[0]}" "$probe/" 2>/dev/null || true
    local pd; pd="$(probe_pick "$probe" -mindepth 1 -maxdepth 1 -type d)"
    if [ -z "$pd" ]; then
      _control_did_not_run "copy a marker directory to plant into"
    else
      find "$pd" -type f -name '*.md' -exec sed -i.bak 's/KIT-CLASS/SBX-CLASS/g' {} \; 2>/dev/null
      find "$pd" -name '*.bak' -delete 2>/dev/null
      [ -z "$(grep -rl 'KIT-CLASS' "$pd" 2>/dev/null)" ] \
        || cf "(control) the planted substitution left KIT-CLASS behind — the control did not reproduce the defect"
      [ -n "$(grep -rn 'SBX-CLASS' "$pd" 2>/dev/null)" ] \
        || cf "(control) the planted substitution produced no SBX-CLASS — direction 2 would never fire"
    fi
  fi

  finish "kit-init: KIT-CLASS markers survive the stamp — present under .claude/{templates,roles} AND no <PREFIX>-CLASS variant (both directions, deletion and rewrite)"
  teardown
}

# =============================================================================
# A MINTED CARD IS UNMARKED, AND ITS FILL INSTRUCTION SURVIVES THE STRIP
# =============================================================================
# The item templates carry a KIT-CLASS: marker because a template travels. A card minted FROM one
# does not: process/EXTRACTION.md § The marker and graduation says a file whose class has become
# PROJECT loses its marker, and a card's class becomes PROJECT at the moment of minting. The minting
# scripts used to `cp` the template wholesale, so every live card opened by calling itself a template.
#
# BOTH DIRECTIONS ARE ASSERTED AND THE SECOND IS THE ONE THAT MATTERS. The template's marker block
# also carried a FILL instruction -- never leave an angle bracket in a live card -- which is still in
# force while the author fills the card, and which is stated NOWHERE ELSE in the kit. So a case that
# asserted only "the marker is gone" would pass over a strip that deleted the guidance with it. The
# scripts REPLACE the block for that reason; this case is what holds them to it.
#
# THE ASSERTION IS ANCHORED AT LINE START (`^<!-- KIT-CLASS:`), not a bare substring, because the
# replacement head talks ABOUT classification. An unanchored match on the marker key would redden on
# a correct card -- and the head is deliberately worded to avoid the key at all, so this anchoring is
# a second belt rather than the only one.
case_minted_card_is_unmarked() {
  cf_reset
  # THE FIXTURE IS kit_init_sandbox, NOT make_sandbox, and this is a measured correction rather than
  # a preference: a bare sandbox carries no .claude/templates/, so every creation script exits 1 and
  # the case fails on SETUP while looking like a finding. This file already records that trap at the
  # creation-script fixtures ("against a sandbox with no templates — and every creation script then
  # exited 1"); the first version of this case walked into it, and BOTH its ablation controls failed
  # identically, which is how it was caught — a case whose red and its control's red are the same
  # red is measuring nothing.
  if ! has_kit_init; then
    skp "minted card: no travel marker, fill instruction kept" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "minted card: no travel marker, fill instruction kept" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local out rc card id="$SB_PREFIX-701"
  out="$(cd "$SB_WORK" && ./scripts/new-issue.sh unmarked-probe --id "$id" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { cf "new-issue.sh exited $rc minting $id: $out"; finish "minted card: no travel marker, fill instruction kept"; teardown; return; }
  card="$SB_WORK/progress/todo/$id-unmarked-probe.md"
  [ -f "$card" ] || { cf "new-issue.sh did not create progress/todo/$id-unmarked-probe.md: $out"; finish "minted card: no travel marker, fill instruction kept"; teardown; return; }

  # (1) THE CLASSIFICATION IS GONE.
  ! grep -qE '^<!-- KIT-CLASS:' "$card" \
    || cf "the minted card still opens with a KIT-CLASS: marker — it is a live card, not a template, and its class became PROJECT at mint"

  # (2) THE STILL-IN-FORCE INSTRUCTION SURVIVED. This is the half a blind strip breaks.
  grep -qi 'never leave one in a live card' "$card" \
    || cf "the minted card lost the fill instruction that came with the marker block — a blind strip took the guidance with the classification, and no other file in the kit states it"

  # (3) THE CARD DECLARES ITS OWN UNMARKED-NESS, so a bare absence is not mistaken for an oversight.
  grep -qi 'no travel-classification marker' "$card" \
    || cf "the minted card does not say its lack of a marker is deliberate — an absence nobody declared reads as a file somebody forgot"

  # (4) THE TEMPLATE IS UNTOUCHED. The strip must not reach back into the thing that travels.
  grep -qE '^<!-- KIT-CLASS:' "$SB_WORK/.claude/templates/ISSUE.template.md" \
    || cf "the template LOST its own marker — a template travels and must keep it; the strip reached the wrong file"

  # (5) EVERY MINTING SCRIPT CARRIES THE RE-HEAD, with a control on the extractor. Driving all five
  # in one case would be slow; a script that silently loses the block is the regression to catch, and
  # zero-found must not read as clean.
  local mfound=0 msh
  for msh in new-issue.sh new-bug.sh new-prd.sh new-refactor.sh subtask.sh; do
    [ -f "$SB_WORK/scripts/$msh" ] || continue
    mfound=$(( mfound + 1 ))
    # THE ASSERTION FOLLOWS THE AUTHORING SITE. It used to look for the comment 'RE-HEAD
    # THE CARD', which each script carried because each script carried the whole block.
    # The block is one library now, so the thing to assert is that the script CALLS it —
    # a census keyed to text that moved is a census of nothing.
    grep -q 'kit_rehead_card' "$SB_WORK/scripts/$msh" \
      || cf "scripts/$msh does not re-head the card it mints — its cards will open by calling themselves templates"
    # NON-COMMENT LINES ONLY. Measured while building this: every one of these scripts
    # MENTIONS the library in a comment, so a bare grep passes on a script whose sourcing
    # has been deleted — which is precisely the regression this arm exists for.
    awk '!/^[[:space:]]*#/ && /card-head\.sh/ { found=1 } END { exit !found }' "$SB_WORK/scripts/$msh" \
      || cf "scripts/$msh calls kit_rehead_card and never SOURCES scripts/lib/card-head.sh (a comment mentioning it does not count) — it would fail at mint time with 'command not found', after the card is already written"
  done
  [ "$mfound" -ge 5 ] \
    || cf "the extractor found only $mfound minting script(s) — expected at least 5. A count this low means the list stopped matching the tree, NOT that the tree is clean."

  finish "minted card: no travel marker, fill instruction kept, template untouched ($mfound minting script(s) checked)"
  teardown
}

# =============================================================================
# CASE — the day-one path THE KIT'S OWN DOCUMENTATION PRINTS
#
# WHY NO EXISTING CASE COULD REACH THE BROKEN PATH, which is the reason this one
# exists rather than a wider assertion somewhere else: every sandbox commit goes
# through sbcommit and every subject the harness writes carries a role prefix —
# "[PM] seed sandbox board", "[Dev] <id>: add a real change", "[Architect] graduate,
# unpublished". Arm (e) therefore never fires in a sandbox, the verdict is always
# clean, and kit-init always takes its first branch. The suite could not have caught
# the regression and cannot catch a recurrence without a case that commits THE WAY
# THE DOCUMENTATION SAYS TO.
#
# GIT-HOSTING § 3 step 2 prints `git commit --allow-empty -m '<init>'` and says that
# wiring the hooks after the first commit "avoids the question entirely" — so the
# documented day-one sequence is an unprefixed subject with hooks unwired, and that
# is the state this case reproduces. publish_sandbox is deliberately NOT used: its
# "[PM] seed sandbox board" subject is exactly what masked this everywhere else, and
# using the helper here would delete the case's premise while leaving it green.
# =============================================================================
case_kit_init_survives_the_documented_first_commit() {
  cf_reset
  if ! has_kit_init; then
    skp "kit-init: the documented day-one first commit" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "kit-init: the documented day-one first commit" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  # SEED THE ROOT DOCUMENTS, because make_sandbox does not and a real day-one tree does.
  # THIS IS THE HALF THAT MAKES THE CASE ABLE TO FAIL, and it was measured: without it
  # the case passes even against the pre-fix initializer. The regression needed BOTH a
  # dirty verdict AND arm [g] reporting, and [g] only reports when it finds these files —
  # `[ -f ] || continue` for the REPLACE pair, "no PROJECT.md to read (skipped)" for FILL.
  # A sandbox with no root documents therefore produces no advisory lines, leaves the
  # pre-fix filter nothing to trip over, and turns this case into a green about nothing.
  # An unzipped kit HAS all three; the sandbox is the synthetic tree, so it is the one
  # that has to be brought up to the day-one state.
  seed_scaffolding_tree

  # The documented first commit, verbatim in shape: unprefixed subject, hooks unwired.
  # The `remote add` is publish_sandbox's job and this case does not call it, so the
  # remote is added here — kit-init's preflight refuses outright without an origin,
  # which is a refusal about the fixture rather than about the subject under test.
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -q -m 'init' >/dev/null 2>&1
  git -C "$SB_WORK" remote add origin "$SB_ORIGIN" >/dev/null 2>&1
  git -C "$SB_WORK" push -q -u origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" remote set-head origin "$SB_TRUNK" >/dev/null 2>&1
  # ASSERT THE FIXTURE REACHED THE STATE THE CASE IS ABOUT, or a preflight refusal
  # about a missing remote reads exactly like the regression this case exists for.
  git -C "$SB_WORK" remote get-url origin >/dev/null 2>&1 \
    || _fixture_die "case_kit_init_survives_the_documented_first_commit: no origin remote in the sandbox — kit-init would refuse at preflight and the case would blame the commit subject."
  # The other half of the premise — arm [g] must actually be reporting — CANNOT be
  # asserted here, and the reason is the arm's own enabling condition: [g] reports only
  # once scripts/config.sh carries the stamp receipt, and the receipt is written BY the
  # run this case is about. Before it, [g] correctly skips. So the premise is checked
  # after the run, below, where it is true or the case has no subject.
  # ASSERT THE PREMISE. If the subject were prefixed after all, arm (e) never fires,
  # the verdict stays clean and this case passes while exercising nothing.
  git -C "$SB_WORK" log -1 --format='%s' | grep -E '^\[' >/dev/null \
    && _fixture_die "case_kit_init_survives_the_documented_first_commit: the first commit's subject IS role-prefixed, so arm (e) cannot fire and this case has no premise."

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?

  # (a) THE REGRESSION: an unprefixed first commit must not fail the install.
  [ "$rc" -eq 0 ] \
    || cf "kit-init FAILED (rc=$rc) on the first-commit subject GIT-HOSTING § 3 step 2 prints: $out"
  printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null \
    || cf "no COMPLETE-and-PROVEN line on the documented day-one path: $out"

  # (b) AND THE BOARD CHECK MUST NOT BE THE THING THAT FAILED — "passes" vs "passes
  #     for the right reason". NOT keyed on the text of [g]'s advisories: a healthy
  #     run PRINTS those, under an explicit "for context — not the basis of the result
  #     above" heading, so matching them would fire on correct output. That is the
  #     same mistake as reading `grep -qi 'not measured'` for the DELETE-IF-UNUSED
  #     class, measured once already in this file. Key on the FAILURE marker instead.
  printf '%s\n' "$out" | grep '✗ check-board.sh reported drift' >/dev/null \
    && cf "kit-init's self-check failed its board arm on a correct day-one tree: $out"
  printf '%s\n' "$out" | grep '✓ check-board.sh' >/dev/null \
    || cf "the self-check's board arm did not report a result at all — it was skipped or renamed: $out"

  # (c) THE PREMISE, CHECKED WHERE IT CAN BE TRUE. The regression needed the board report
  #     to carry arm [g]'s advisories at self-check time; [g] only reports once the stamp
  #     receipt exists, and this run is what wrote it. Asserting it against check-board
  #     directly — not against kit-init's rendering of it — keeps this independent of how
  #     the initializer chooses to echo context. Without this, a sandbox that produced no
  #     advisories would pass (a) and (b) while exercising nothing, which is measured: it
  #     is exactly what this case did before the root documents above were seeded.
  CB_OUT="$(cb_run)"   # capture, then test — cb_run grows with the board
  printf '%s\n' "$CB_OUT" | _cb_g_section | grep -i 'still scaffolding' >/dev/null \
    || cf "arm [g] reports no advisory on the post-init tree, so the failure mode this case exists for was never reachable and its green means nothing"

  finish "kit-init: the first-commit subject GIT-HOSTING § 3 step 2 prints does not fail the install, the board arm is not what fails, and arm [g] WAS reporting while it ran"
  teardown
}

# =============================================================================
# CASE — kit-init REFUSES while shipped kit paths are on disk but untracked
#
# The remote + trunk recipe kit-init printed on refusal used to make the first commit
# `--allow-empty`. Followed literally from an unzip, kit-init then committed only its own
# allow-list and printed COMPLETE and PROVEN with README.md, PROJECT.md, CLAUDE.md,
# AGENTS.md, setup.sh, .env.example, consumers/ and docs/ untracked — on disk, absent from
# the trunk (measured 2026-09-26). The preflight now refuses that state, reading the
# shipped process/KIT-MANIFEST.
#
# THREE STATES, because a refusal tested only where it fires is half a test:
#   (a) an empty first commit, the kit on disk      ⇒ refused, NOTHING written
#   (b) the kit committed as unzipped               ⇒ no such refusal; COMPLETE
#   (c) a shipped file deleted before that commit   ⇒ no such refusal; COMPLETE
#       (a deletion is the adopter's decision — the check is "on disk and not tracked",
#        never "absent from HEAD")
#   (d) the kit committed, but a shipped file IGNORED ⇒ refused, naming it as IGNORED
#       (by .git/info/exclude here; a global core.excludesFile is the usual real cause —
#        the first version asked only about untracked NON-ignored files and passed this)
#   (e) the kit committed, .claude/ IGNORED        ⇒ refused BEFORE stamping, naming .claude
#       (every file under it tracked — committed with -f — so (d)'s check is satisfied; the
#        commit step's `git add -A -- .claude` still fails on the ignored pathspec. Before the
#        fix kit-init stamped config.sh, the role docs and core.hooksPath, THEN died, and the
#        next run refused as already-lived: half-initialized, no resume path)
# make_sandbox copies no process/, so the manifest is copied in here. Without it the
# check is SKIPPED, and (a) would fail for the wrong reason while (b) and (c) passed
# about nothing — so the premise is asserted, not assumed.
# =============================================================================
case_kit_init_refuses_an_uncommitted_kit() {
  cf_reset
  local T="kit-init: refuses, writing nothing, while shipped kit paths are on disk but not committed"
  if ! has_kit_init; then skp "$T" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "$T" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -f "$REAL_REPO_ROOT/process/KIT-MANIFEST" ]; then skp "$T" "process/KIT-MANIFEST absent from this tree"; return; fi
  local state out rc head0 hp0
  for state in empty committed deleted ignored claude-ignored; do
    kit_init_sandbox
    mkdir -p "$SB_WORK/process"
    cp "$REAL_REPO_ROOT/process/KIT-MANIFEST" "$SB_WORK/process/KIT-MANIFEST"
    # PREMISE: the manifest names a shipped path this sandbox holds on disk — else (a) has
    # nothing to find — and setup.sh is one of them, or (c) deletes nothing shipped.
    # DRAINED, never `| grep -q` — this file's pipefail rule (a reader that exits early turns the
    # producer's SIGPIPE into the pipeline's status).
    awk -F'  ' '!/^#/ && NF>=2 {print $2}' "$SB_WORK/process/KIT-MANIFEST" | grep -x 'setup.sh' >/dev/null \
      && [ -f "$SB_WORK/setup.sh" ] \
      || _fixture_die "case_kit_init_refuses_an_uncommitted_kit: the manifest does not name setup.sh, or the sandbox does not hold it — states (a) and (c) would have no subject."
    case "$state" in
      empty)     sbcommit -q --allow-empty -m 'init' >/dev/null 2>&1 ;;
      committed) git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m 'init' >/dev/null 2>&1 ;;
      deleted)   rm -f "$SB_WORK/setup.sh"
                 git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m 'init' >/dev/null 2>&1 ;;
      ignored)   printf 'setup.sh\n' >> "$SB_WORK/.git/info/exclude"
                 git -C "$SB_WORK" add -A >/dev/null 2>&1; sbcommit -q -m 'init' >/dev/null 2>&1
                 git -C "$SB_WORK" ls-files --error-unmatch setup.sh >/dev/null 2>&1 \
                   && _fixture_die "case_kit_init_refuses_an_uncommitted_kit (ignored): setup.sh was committed although excluded — state (d) has no subject." ;;
      claude-ignored)
                 printf '.claude/\n' >> "$SB_WORK/.git/info/exclude"
                 git -C "$SB_WORK" add -A >/dev/null 2>&1; git -C "$SB_WORK" add -f .claude >/dev/null 2>&1
                 sbcommit -q -m 'init' >/dev/null 2>&1
                 { git -C "$SB_WORK" check-ignore --no-index -q .claude \
                   && [ -n "$(git -C "$SB_WORK" ls-files .claude)" ]; } \
                   || _fixture_die "case_kit_init_refuses_an_uncommitted_kit (claude-ignored): .claude is not both ignored and committed — state (e) has no subject." ;;
    esac
    git -C "$SB_WORK" remote add origin "$SB_ORIGIN" >/dev/null 2>&1
    git -C "$SB_WORK" push -q -u origin "$SB_TRUNK" >/dev/null 2>&1
    git -C "$SB_WORK" remote set-head origin "$SB_TRUNK" >/dev/null 2>&1
    git -C "$SB_WORK" rev-parse --verify --quiet "refs/remotes/origin/$SB_TRUNK" >/dev/null \
      || _fixture_die "case_kit_init_refuses_an_uncommitted_kit ($state): the trunk was not published — kit-init would refuse on the remote, and the case would blame the kit check."
    head0="$(git -C "$SB_WORK" rev-parse HEAD)"
    hp0="$(git -C "$SB_WORK" config core.hooksPath || true)"   # make_sandbox sets its own; compare, do not assume empty
    out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
    case "$state" in
      claude-ignored)
        [ "$rc" -ne 0 ] \
          || cf "(e) kit-init did not refuse with .claude/ ignored (rc=0): $out"
        printf '%s\n' "$out" | grep 'kit-init commits are IGNORED: .claude' >/dev/null \
          || cf "(e) the refusal did not name .claude as an ignored path kit-init commits: $out"
        grep -q 'Stamped by scripts/kit-init.sh' "$SB_WORK/scripts/config.sh" 2>/dev/null \
          && cf "(e) config.sh was STAMPED — kit-init wrote before it refused (the half-initialized state)"
        [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ] \
          || cf "(e) HEAD moved — the refusal wrote a commit" ;;
      ignored)
        [ "$rc" -ne 0 ] \
          || cf "(d) kit-init did not refuse a committed kit with a shipped file IGNORED and uncommitted (rc=0): $out"
        printf '%s\n' "$out" | grep 'IGNORED (setup.sh' >/dev/null \
          || cf "(d) the refusal did not name setup.sh as IGNORED: $out"
        [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ] \
          || cf "(d) HEAD moved — the refusal wrote a commit" ;;
      empty)
        [ "$rc" -ne 0 ] \
          || cf "(a) kit-init did not refuse an empty first commit with the kit on disk and untracked (rc=0): $out"
        printf '%s\n' "$out" | grep 'shipped kit path(s) are on disk but NOT COMMITTED' >/dev/null \
          || cf "(a) the refusal did not name the uncommitted kit — it refused for some other reason, or not at all: $out"
        printf '%s\n' "$out" | grep 'NOTHING WAS WRITTEN' >/dev/null \
          || cf "(a) the refusal did not say NOTHING WAS WRITTEN: $out"
        [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$head0" ] \
          || cf "(a) HEAD moved — the refusal wrote a commit"
        [ "$(git -C "$SB_WORK" config core.hooksPath || true)" = "$hp0" ] \
          || cf "(a) core.hooksPath changed — the refusal wired the hooks" ;;
      committed|deleted)
        printf '%s\n' "$out" | grep 'NOT COMMITTED' >/dev/null \
          && cf "($state) the untracked-kit refusal fired on a tree whose kit IS committed: $out"
        printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null \
          || cf "($state) no COMPLETE-and-PROVEN line: $out" ;;
    esac
    teardown
  done
  finish "$T — (a) an empty first commit is refused and nothing is written; (b) the kit committed as unzipped and (c) a shipped file deleted before that commit both proceed to COMPLETE; (d) a shipped file IGNORED and so never committed is refused, named as ignored; (e) .claude/ ignored though committed is refused before anything is stamped"
}

# =============================================================================
# CASE — a REAL board finding must still fail the self-check, naming itself
#
# WITHOUT THIS, "tolerate more" is indistinguishable from "check nothing". The
# filter that let the day-one regression through was widened to fix it; this is the
# control that widening never had, and it is the reason the pair is worth more than
# either case alone.
#
# THE PLANT IS NOT AN ORDINARY CARD, AND THE REASON IS ITSELF A FINDING. kit-init's
# ALREADY-LIVED probe `find`s progress/*/*-[0-9]*.md in the WORKING TREE, so seeding
# two ordinary cards makes kit-init refuse before its self-check ever runs — the case
# would then pass its non-zero assertion for entirely the wrong reason and fail the
# one that names the cause. Measured 2026-08-28. So the duplicate is planted under
# filenames the lived-probe glob does not match, which leaves the id collision real,
# on the trunk, and reachable by the self-check.
#
# AND THE FINDING IS DELIBERATELY ONE PRINTED BELOW ITS SECTION HEADER — a choice that
# has since been vindicated, and the superseded reason is kept because it is the lesson.
# THIS PARAGRAPH USED TO READ, in the present tense: "kit-init's filter skips the header
# line of every section while deciding whether the section is advisory, so a finding
# rendered ON its header is currently invisible to it." That was true when written and is
# no longer: the `; next` that discarded every header was removed, and only headers that
# DECLARE themselves advisory are dropped now. The claim was a statement about another
# file's current behaviour, made in the present tense, in a file that ships — the shape
# that goes stale without anything noticing. What survives is the choice, and its reason
# is now the durable one: a below-header finding is what the arm's own contract promises
# to report, so this control rests on the contract rather than on a rendering detail.
# =============================================================================
case_kit_init_still_fails_on_a_real_finding() {
  cf_reset
  if ! has_kit_init; then
    skp "kit-init: a real board finding still fails the self-check" "scripts/kit-init.sh absent"; return
  fi
  if ! has_issue_template; then skp "kit-init: a real board finding still fails the self-check" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local dup="$SB_PREFIX-100" f
  for f in "progress/todo/dupe-one.md" "progress/done/dupe-two.md"; do
    printf -- '---\nid: %s\ntype: chore\nstatus: %s\ntitle: "duplicate plant"\npr: null\n---\n\n## Activity\n' \
      "$dup" "$(basename "$(dirname "$f")")" > "$SB_WORK/$f"
  done
  # BOTH HALVES OF THE PREMISE, asserted: the collision is real, and the plant does
  # NOT look like a lived board — a plant that trips the already-lived refusal tests
  # the refusal, not the self-check.
  [ "$(find "$SB_WORK/progress" -type f -name '*-[0-9]*.md' 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ] \
    || _fixture_die "case_kit_init_still_fails_on_a_real_finding: the planted files match kit-init's ALREADY-LIVED glob, so it would refuse before the self-check and this case would pass for the wrong reason."
  publish_sandbox

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  printf '%s\n' "$out" | grep 'already lived' >/dev/null \
    && _fixture_die "case_kit_init_still_fails_on_a_real_finding: kit-init took the ALREADY-LIVED refusal, so nothing here exercised the self-check."
  [ "$rc" -ne 0 ] \
    || cf "kit-init PASSED with a duplicate id on the board — the self-check tolerates a real finding: $out"
  printf '%s\n' "$out" | grep -i 'duplicate' >/dev/null \
    || cf "kit-init failed but did not NAME the finding that caused it: $out"

  finish "kit-init: a real board finding still fails the self-check, and the failure names that finding"
  teardown
}

# =============================================================================
# CASE — kit-init.sh end to end, against a NON-shipped prefix.
# The script's own self-check is its primary proof; this keeps it from ROTTING.
# =============================================================================
# THE ISSUE-TEMPLATE CAPABILITY PROBE — ONE AUTHORING SITE. Every case that needs a minted card
# carried its own copy of this path, in TWO spellings of the skip reason. (This said "eight cases"
# and was true when written; derive it —
#   awk '/^[A-Za-z_][A-Za-z0-9_]*\(\)/{fn=$1} /if ! has_issue_template/{print fn}' scripts/test/run.sh scripts/test/lib/*.sh scripts/test/cases/*.sh | sort -u | wc -l
# — rather than trusting a number here.) The path, the
# spelling policy below and the reason string are one decision, and a decision stated per case
# is eight places to amend and seven to forget.
#
# `.claude/` ONLY, DELIBERATELY, AND DO NOT WIDEN THIS TO THE DUAL SPELLING. The cases that call
# `kit_init_sandbox` exercise a BUILT kit — it copies `.claude/templates` and nothing else — so the
# maintainer repository's disarmed `_claude/` tree is not their operand and finding it would make
# them run against a tree they are not testing.
# (This said "these EIGHT cases"; derive the set with `cat scripts/test/run.sh scripts/test/lib/*.sh scripts/test/cases/*.sh | grep -c kit_init_sandbox` rather than
# trusting a number here — it was true when written and the population has since grown.)
#
# The sites elsewhere in this file that read
# whichever spelling exists are reading the SHIPPED tree in place, which is a different question;
# the header says why that is a convenience and not a supported mode.
ISSUE_TEMPLATE_REL='.claude/templates/ISSUE.template.md'
ISSUE_TEMPLATE_ABSENT="$ISSUE_TEMPLATE_REL absent (copy-list incomplete)"
has_issue_template() { [ -f "$REAL_REPO_ROOT/$ISSUE_TEMPLATE_REL" ]; }

# THE ROLE-FILE PATH, DERIVED FROM THE HOOKS THAT DECLARE IT. Both hooks keep `ROLE_REL` as a named
# variable on its own line, and both say in a comment that they do it "so a test fixture can DERIVE it
# (sed) instead of re-hardcoding a literal" — a promise `process/MANUAL.md` repeats. Nothing derived it:
# the one assertion about the path hardcoded the string, so all three statements were false.
#
# IT READS BOTH HOOKS AND REQUIRES THEM TO AGREE, which is what session-start.sh's own comment asks
# for: "a guard that derives the path from one hook and finds a literal in the other cannot check the
# pair." Deriving from one alone would leave the pair unchecked and still look like a derivation.
_role_rel() {   # -> the agreed ROLE_REL, or empty if the hooks disagree or either cannot be read
  local a b
  a="$(sed -n 's/^ROLE_REL="\(.*\)"$/\1/p' "$REAL_SCRIPTS/hooks/require-role.sh" 2>/dev/null)"
  b="$(sed -n 's/^ROLE_REL="\(.*\)"$/\1/p' "$REAL_SCRIPTS/hooks/session-start.sh" 2>/dev/null)"
  [ -n "$a" ] && [ "$a" = "$b" ] && printf '%s' "$a"
}

has_kit_init() { [ -f "$REAL_SCRIPTS/kit-init.sh" ]; }

kit_init_sandbox() {
  make_sandbox
  mkdir -p "$SB_WORK/.claude"
  if [ -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    cp -R "$REAL_REPO_ROOT/.claude/templates" "$SB_WORK/.claude/templates"
  fi
  # The role docs are IN the substitution pass, so the census has to have
  # something to count. Copying them is what makes the census assertion real
  # rather than vacuous.
  if [ -d "$REAL_REPO_ROOT/.claude/roles" ]; then
    cp -R "$REAL_REPO_ROOT/.claude/roles" "$SB_WORK/.claude/roles"
  fi
  # ...and take the adopter's stamp back out of what `cp` just carried in, exactly
  # as make_sandbox does for scripts/. AFTER both copies and never between them:
  # the neutralizer walks the whole .claude/ tree, so a call placed between the two
  # would leave the role docs stamped while reporting that it had run.
  _kit_neutral_claude
}

case_kit_init_happy() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: end-to-end init + self-check" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: end-to-end init + self-check" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc: $out"
  printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null || cf "no COMPLETE-and-PROVEN line: $out"
  printf '%s\n' "$out" | grep '✗' >/dev/null && cf "a self-check assertion failed: $out"
  # The prefix reached the TEMPLATE BODY — the check a silent substitution no-op fails.
  printf '%s\n' "$out" | grep "id: SBX-000" >/dev/null \
    || cf "the self-check did not report the stamped frontmatter id: $out"
  grep -q 'ISSUE_PREFIX:-SBX' "$SB_WORK/scripts/config.sh" || cf "scripts/config.sh was not stamped"
  grep -q 'SBX-' "$SB_WORK/.claude/templates/ISSUE.template.md" || cf "the ISSUE template body was not stamped"
  grep -q '<PREFIX>' "$SB_WORK/.claude/templates/ISSUE.template.md" \
    && cf "the angle-bracket prefix placeholder SURVIVED in the template"
  # The CENSUS is asserted, not promised.
  printf '%s\n' "$out" | grep "census — prefix placeholders" >/dev/null \
    || cf "the census did not report on prefix placeholders: $out"
  printf '%s\n' "$out" | grep -E "census — prefix placeholders[^:]*: 0 in" >/dev/null \
    || cf "the census did not report ZERO surviving prefix placeholders: $out"
  # A hat declaration is session state.
  printf '%s\n' "$out" | grep 'hat declaration is invisible to git status' >/dev/null \
    || cf "the self-check did not prove the session-role ignore entry: $out"
  # DERIVED, not re-typed — and the derivation is asserted, because an empty result would make the
  # grep below look for an empty string, match every line, and pass while checking nothing.
  local role_rel; role_rel="$(_role_rel)"
  [ -n "$role_rel" ] \
    || cf "(control) could not derive an AGREED ROLE_REL from the two hooks — either one of them no longer declares it on its own line, or they now name different paths; the .gitignore assertion below would otherwise search for an empty string and pass"
  [ -z "$role_rel" ] || grep -xF "$role_rel" "$SB_WORK/.gitignore" >/dev/null \
    || cf "$role_rel (derived from the hooks) was not written into the new repo's .gitignore"
  # The board is COMPLETE and left PRISTINE.
  local keeps leftovers
  keeps="$(find "$SB_WORK/progress" -name .gitkeep | wc -l | tr -d ' ')"
  # DERIVED FROM THE INITIALIZER'S OWN DECLARATION, NOT A HAND-TYPED DIGIT. This asserted
  # `= 7`, which is a census over a set the kit may legitimately grow: adding a status
  # column reddened THIS case rather than the property it protects (one .gitkeep per board
  # folder, none missing and none extra), and the number then had to be chased here as well
  # as at the seam. kit-init builds BOARD_FOLDERS as STATUS_FOLDERS + history and asserts
  # its own GITKEEP_EXPECTED against it, so the honest control here is the SAME arithmetic
  # read from the shipped source. The derivation is asserted non-empty first — an empty
  # expectation would make the comparison below vacuous, which is the trap the check-board
  # constant-derivation cases record.
  local kg_cols kg_expected
  kg_cols="$(sed -n 's/^STATUS_FOLDERS=(\(.*\))$/\1/p' "$SB_WORK/scripts/kit-init.sh" | head -1)"
  [ -n "$kg_cols" ] \
    || cf "(control) could not derive STATUS_FOLDERS from kit-init.sh — the declaration moved, and the .gitkeep count below would otherwise compare against an empty expectation"
  # + 1 for history/, which kit-init appends to BOARD_FOLDERS and which is NOT a status.
  kg_expected="$(( $(printf '%s\n' "$kg_cols" | tr ' ' '\n' | grep -c .) + 1 ))"
  [ "$keeps" = "$kg_expected" ] \
    || cf "expected $kg_expected .gitkeep files (STATUS_FOLDERS + history, derived from kit-init.sh), found $keeps"
  leftovers="$(find "$SB_WORK/progress" -type f -name '*.md' | wc -l | tr -d ' ')"
  [ "$leftovers" = "0" ] || cf "the board is not pristine — $leftovers issue file(s) left behind"
  grep -qE '^##[[:space:]]+Log' "$SB_WORK/progress.md" || cf "progress.md has no '## Log' heading"
  origin_has_path "progress/todo/.gitkeep" || cf "the board was not pushed to the trunk"
  # A second run must refuse rather than half-stamp.
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "the second run did NOT refuse"
  printf '%s\n' "$out" | grep 'already lived' >/dev/null || cf "the second-run refusal did not name what is stamped: $out"

  finish "kit-init: end-to-end init + self-check, census green, board pristine, re-run refuses"
  teardown
}

# WHY THIS CASE EXISTS, and why it asserts a PRE-STATE before it asserts anything else.
# `core.hooksPath` points git at a directory; git then runs what it finds there ONLY if the
# file is executable. When the bit is off git prints a *hint* to stderr and the commit
# SUCCEEDS — so a repository can be perfectly wired and completely unguarded, and the old
# self-check read that success as "core.hooksPath is not in effect", which is the wrong cause
# and sends an adopter to re-run wiring that already worked.
#
# A clone is where the bit goes missing: git records one execute bit per path, so a tree that
# was committed with the bit off hands every future clone an inert hook. kit-init runs BEFORE
# the trunk's first commit, which is the only moment a repair can reach every future clone —
# that is why the chmod lives there and not only in setup.sh.
#
# The pre-state assertion is the instrument check. Without it a chmod that silently did nothing
# — or a source tree that already ships the bit on — would let this case pass while proving
# nothing at all, which is this harness's own green-that-cannot-go-red trap.
case_kit_init_repairs_hook_mode() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: repairs a non-executable commit-msg hook" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: repairs a non-executable commit-msg hook" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local hook="$SB_WORK/scripts/githooks/commit-msg"
  if [ ! -f "$hook" ]; then
    cf "no commit-msg hook shipped at scripts/githooks/"
    finish "kit-init: repairs a non-executable commit-msg hook"; teardown; return
  fi
  # THE DAMAGE GOES IN BEFORE THE COMMIT, and that ordering is the whole fidelity of this case.
  # Clearing the bit AFTER publish_sandbox makes the worktree dirty, and kit-init's preflight
  # refuses a dirty tree — so the case would fail for a reason that has nothing to do with the
  # hook. The real defect is a bit that is off IN THE COMMIT, which leaves the worktree clean
  # and hands the inert hook to every future clone. That is what is modelled here.
  chmod 0644 "$hook"
  publish_sandbox

  # INSTRUMENT CHECK: assert the recorded mode, not the filesystem bit — git tracks exactly one
  # execute bit per path, and it is the INDEX's copy that travels. If this reads 100755 the
  # damage never landed and every assertion below would pass while proving nothing.
  local pre
  pre="$(git -C "$SB_WORK" ls-files -s scripts/githooks/commit-msg 2>/dev/null | awk '{print $1}')"
  [ "$pre" = "100644" ] || cf "the sandbox did not record a non-executable hook (mode $pre) — this case would pass vacuously"

  local out rc flat
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  # cf renders one line, and kit-init speaks in paragraphs: flatten, or the diagnosis is lost.
  flat="$(printf '%s' "$out" | tr '\n' ' ')"
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc against a non-executable hook: $flat"
  [ -x "$hook" ] || cf "kit-init did NOT restore the hook's execute bit in the worktree"

  # THE ASSERTION THAT CARRIES THE CHANGE. kit-init runs before the trunk's first commit, so a
  # repair it makes reaches the trunk and therefore every future clone. setup.sh cannot have this
  # property — it runs after the clone exists. Reading the mode back off the REMOTE's trunk is
  # what distinguishes "kit-init fixed my checkout" from "kit-init fixed the repository".
  local shipped
  shipped="$(git -C "$SB_ORIGIN" ls-tree "$SB_TRUNK" scripts/githooks/commit-msg 2>/dev/null | awk '{print $1}')"
  [ "$shipped" = "100755" ] \
    || cf "the repaired bit did not reach the trunk (origin records mode ${shipped:-<absent>}) — a fresh clone would still get an inert hook"

  # The bit is only worth anything if the guard is then LIVE, so assert the effect too.
  printf '%s\n' "$out" | grep 'commit-msg hook REJECTED a prefix-less subject' >/dev/null \
    || cf "the hook was not proven live after the repair: $flat"
  # And the wrong diagnosis must not be what an adopter hears.
  printf '%s\n' "$out" | grep 'core.hooksPath is not in effect' >/dev/null \
    && cf "kit-init blamed core.hooksPath for a mode problem: $flat"

  finish "kit-init: repairs a non-executable commit-msg hook, the repair reaches the trunk, and hooksPath is not blamed"
  teardown
}

# =============================================================================
# CASE — kit-init --roles LEAVES NO SEAM BEHIND.
#
# THE STAMPING LOOP WAS ENTIRELY UNTESTED. Measured before this case was written:
# `--roles` appeared in this file four times, every one of them inside a comment.
#
# What that cost: the loop's seam list was hand-typed, and subtask.sh sat outside it
# while its --role whitelist enforced the shipped set — so a project that renamed its
# roles got a subtask tool that rejected every role it had just declared. The list is
# now derived, and this case is what makes the derivation's completeness assertable
# instead of argued.
#
# THE CONSEQUENCE PROBE IS THE POINT. "Every file carries the new string" is a text
# match, and a text match cannot tell a stamped whitelist from a stamped comment.
# subtask.sh validates --role BEFORE kwt_resolve, so a nonexistent card cannot
# short-circuit it, which makes the whitelist reachable without building a real card.
# =============================================================================
case_kit_init_roles_leave_no_seam() {
  cf_reset
  if ! has_kit_init; then skp "kit-init --roles: no seam keeps the old set" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init --roles: no seam keeps the old set" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local old="$KIT_NEUTRAL_ROLE_PREFIXES" new='Alpha|Beta|Gamma' before f out rc=0

  # THE OPERAND, ASSERTED BEFORE THE ACT — which files carry the set is the question
  # this case is about, so it is measured rather than assumed. Empty means the probe
  # lost its subject and every assertion below would pass over nothing.
  before="$( cd "$SB_WORK" && { grep -lF -- "$old" scripts/*.sh scripts/githooks/* 2>/dev/null || true; } | sort )"
  # A `cf` HERE WOULD CHARGE THE WRONG PARTY. An empty derivation is not a finding about the
  # initializer — it is a probe that lost its subject, and every arm below would then pass over
  # nothing. So it aborts rather than reporting.
  [ -n "$before" ] \
    || _fixture_die "case_kit_init_roles_leave_no_seam: no shipped script carries the role set before kit-init ran, so the derivation found nothing to stamp and every assertion below would pass over an empty population."
  # AND NO FAVOURITE FILE. This arm used to require scripts/subtask.sh to be a member of the set
  # the line above has just DERIVED — a hand-typed operand inside a case whose whole subject is
  # that the seams are derived rather than listed. It also goes red for the wrong reason the day a
  # change legitimately removes that file's copy, which is a change this repository has already
  # made once.

  # THE HAT IS NAMED, because this set does not contain the pre-role hat and kit-init refuses to
  # sign its own commits with a hat the set would reject (it names KIT_INIT_ROLE when it does).
  out="$(KIT_INIT_ROLE="$(printf '%s' "$new" | cut -d'|' -f1)" "$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --roles "$new" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init --roles exited $rc: $(printf '%s' "$out" | tr '\n' '|')"

  # THE EFFECT, PER SEAM: everything that carried the old set carries the new one, and
  # nothing keeps the old. Both directions — "carries the new" alone is satisfied by a
  # file that carries both.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qF -- "$new" "$SB_WORK/$f" \
      || cf "$f carried the role set before kit-init --roles and does not carry the new one after it — this seam was left out of the stamping list"
    grep -qF -- "$old" "$SB_WORK/$f" \
      && cf "$f still carries the SHIPPED set after kit-init --roles — the substitution did not reach it"
  done <<SEAM_EOF
$before
SEAM_EOF

  # THE RECEIPT NAMES WHAT IT STAMPED, rather than a sentence somebody typed once — and it is now
  # checked against EVERY member of the derived set instead of one file somebody chose. The named
  # form passed while the receipt reported its favourite file and silently omitted a different
  # member, which is precisely the state this arm exists to catch.
  local unreported=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\n' "$out" | grep -F "$f" >/dev/null || unreported="$unreported $f"
  done <<RECEIPT_EOF
$before
RECEIPT_EOF
  [ -z "$unreported" ] \
    || cf "the run's role-set receipt does not name$unreported among the seams it stamped, although the derivation says they carried the set — a receipt reporting a subset is how a seam gets stamped and not reported, or reported and not stamped: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # THE CONSEQUENCE THE LOOP'S OWN COMMENT RECORDS, as behaviour and not as text. The
  # names are BUILT, never written: this file is scanned for `--role <Name>` literals by
  # case_role_literals_are_declared, and a typed one would redden that case on this
  # case's control text. (Measured, on an earlier control's first draft.)
  local mine outsider accepted refused
  mine="$(printf '%s' "$new" | cut -d'|' -f1)"
  outsider="$(printf '%s' "$old" | cut -d'|' -f1)"
  accepted="$( cd "$SB_WORK" && ./scripts/subtask.sh move SBX-001-s1 in_progress --role "$mine" --note n 2>&1 || true )"
  printf '%s' "$accepted" | grep -- '--role must be' >/dev/null \
    && cf "subtask.sh refused '$mine', a member of the set kit-init just declared — its whitelist was not stamped"
  # INSTRUMENT: the probe above is a NEGATIVE and is satisfied by any unreachable code
  # path. The same probe must FIRE on a role the project no longer declares.
  refused="$( cd "$SB_WORK" && ./scripts/subtask.sh move SBX-001-s1 in_progress --role "$outsider" --note n 2>&1 || true )"
  printf '%s' "$refused" | grep -- '--role must be' >/dev/null \
    || cf "(control) subtask.sh did NOT refuse '$outsider', which the project's declared set no longer contains — the probe above cannot tell an accepted role from a whitelist it never reached"

  finish "kit-init --roles: every seam that carried the role set carries the new one and none keeps the old, the receipt names them, and subtask.sh's whitelist follows (accepts a declared role, refuses a withdrawn one)"
  teardown
}

# =============================================================================
# CASE — kit-init SIGNS ITS OWN COMMITS WITH THE PRE-ROLE HAT, never with whichever role
#        sorts first.
#
# It derived the tag as `${ROLES%%|*}` — the first member of the set — which
# scripts/lib/role-set.sh's header forbids by name: a derived tag "writes a FALSE SEAT into
# git history, permanently". On the shipped set the first member happens to be the pre-role
# hat, so every shipped tree looked right and the rule was broken only where it could not be
# seen: a project whose set lists another role first got its first attributed commits in
# that role's name.
#
#   (a) a set whose FIRST member is not the hat — every kit-init commit carries the hat;
#   (b) KIT_INIT_ROLE names another member — every commit carries that one (the knob);
#   (c) a set WITHOUT the hat and no knob — REFUSED before anything is written, naming the
#       knob, as role-set.sh refuses;
#   (d) the default in kit-init.sh equals role-gate.md § 2a's declared default — the seam
#       has one value, and this is what holds its two copies together.
# THE NAMES ARE BUILT, NEVER TYPED: case_role_literals_are_declared scans this file for role
# literals, and the hat is read from the contract rather than written here.
# =============================================================================
_ki_hat_doc() {
  sed -n 's/^- \*\*The default pre-role hat:\*\* `\([^`]*\)`.*/\1/p' \
    "$REAL_REPO_ROOT/process/contracts/role-gate.md" 2>/dev/null | head -1
}
_ki_run_subjects() {  # <roles> [KEY=VAL…] — fresh sandbox, run kit-init, set _ki_out _ki_rc _ki_subj
  local roles="$1"; shift
  kit_init_sandbox
  publish_sandbox
  local pre; pre="$(git -C "$SB_WORK" rev-parse HEAD)"
  _ki_rc=0
  _ki_out="$( cd "$SB_WORK" && env "$@" ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" --roles "$roles" 2>&1 )" || _ki_rc=$?
  git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
  _ki_subj="$(git -C "$SB_WORK" log --format=%s "$pre..origin/$SB_TRUNK" 2>/dev/null)"
}
case_kit_init_signs_with_the_pre_role_hat() {
  cf_reset
  if ! has_kit_init; then skp "kit-init signs with the pre-role hat" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init signs with the pre-role hat" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local hat other third set_ n bad
  hat="$(_ki_hat_doc)"
  [ -n "$hat" ] || { cf "could not read the default pre-role hat out of process/contracts/role-gate.md § 2a — nothing below has an operand"; finish "kit-init signs with the pre-role hat"; return; }
  # Two other members of the kit's neutral set, neither of them the hat.
  other="$(printf '%s' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -vx "$hat" | sed -n 1p)"
  third="$(printf '%s' "$KIT_NEUTRAL_ROLE_PREFIXES" | tr '|' '\n' | grep -vx "$hat" | sed -n 2p)"
  set_="$other|$hat|$third"

  # (a) first member is not the hat
  _ki_run_subjects "$set_"
  if [ "$_ki_rc" -ne 0 ]; then
    cf "(a) kit-init exited $_ki_rc with the hat in the set: $(printf '%s' "$_ki_out" | tail -8 | tr '\n' '|')"
  else
    n="$(printf '%s\n' "$_ki_subj" | grep -c 'kit-init\|SBX-000' || true)"
    [ "$n" -gt 0 ] || cf "(a) no kit-init commit reached the trunk — nothing was measured: $_ki_subj"
    bad="$(printf '%s\n' "$_ki_subj" | grep 'kit-init\|SBX-000' | grep -vF "[$hat]" || true)"
    [ -z "$bad" ] || cf "(a) with '$other' listed first, kit-init signed commits with another hat than the pre-role hat [$hat]: $(printf '%s' "$bad" | tr '\n' '|')"
  fi
  teardown

  # (b) the knob names another member
  _ki_run_subjects "$set_" KIT_INIT_ROLE="$third"
  if [ "$_ki_rc" -ne 0 ]; then
    cf "(b) kit-init exited $_ki_rc with KIT_INIT_ROLE=$third, a member of the set: $(printf '%s' "$_ki_out" | tail -8 | tr '\n' '|')"
  else
    bad="$(printf '%s\n' "$_ki_subj" | grep 'kit-init\|SBX-000' | grep -vF "[$third]" || true)"
    [ -n "$(printf '%s\n' "$_ki_subj" | grep 'kit-init')" ] && [ -z "$bad" ] \
      || cf "(b) KIT_INIT_ROLE=$third was not the hat on every kit-init commit: $(printf '%s' "${bad:-$_ki_subj}" | tr '\n' '|')"
  fi
  teardown

  # (c) a set without the hat, no knob -> refused before anything is written
  _ki_run_subjects "$other|$third"
  [ "$_ki_rc" -ne 0 ] || cf "(c) kit-init ran with a role set that does not contain its hat [$hat] — its own commits would carry a hat the hook rejects"
  printf '%s\n' "$_ki_out" | grep 'NOTHING WAS WRITTEN' >/dev/null \
    || cf "(c) the refusal did not say nothing was written: $(printf '%s' "$_ki_out" | tail -8 | tr '\n' '|')"
  printf '%s\n' "$_ki_out" | grep 'KIT_INIT_ROLE' >/dev/null \
    || cf "(c) the refusal does not name the knob that fixes it"
  grep -q 'Stamped by scripts/kit-init.sh' "$SB_WORK/scripts/config.sh" \
    && cf "(c) the refused run stamped scripts/config.sh"
  teardown

  # (d) one value, two copies, held together
  local lit; lit="$(sed -n "s/^KIT_INIT_ROLE_DEFAULT='\([^']*\)'.*/\1/p" "$REAL_SCRIPTS/kit-init.sh" | head -1)"
  [ "$lit" = "$hat" ] \
    || cf "(d) kit-init.sh's KIT_INIT_ROLE_DEFAULT is '${lit:-<absent>}' and role-gate.md § 2a declares '$hat' — the pre-role hat has two values"

  finish "kit-init signs its own commits with the pre-role hat [$hat] even when another role is listed first (a), honours KIT_INIT_ROLE (b), refuses before writing when the hat is not in the set (c), and its default is role-gate.md § 2a's (d)"
}

# =============================================================================
# CASE — THE RUNNER kit-init GENERATES SPEAKS THE FRAME'S STATUS VOCABULARY, not its gate's.
#
# `kit-init --gate-command <C>` on a tree with no scripts/verify.sh writes a one-gate runner.
# It passed the gate's own exit status straight through — so a gate that could not start
# printed FAIL and exited 127, and, once the frame gave 2 and 3 meanings (refused; nothing
# failed but a gate could not run), a project gate whose own failure code was 3 reached the
# landing script as "COULD NOT RUN — nothing was measured". It refused either way; the
# diagnosis was false. It also printed no count line, so nothing could read its summary.
#
# DRIVEN THROUGH kit-init, NEVER FROM A COPY: the runner under test is the one kit-init
# writes, so an edit to the heredoc is what this case sees. ONE generation, many runs: the
# gate command is a sandbox script whose exit code comes from the environment.
# THE SUMMARY SHAPE IS DERIVED FROM THE FRAME, not typed here: the frame is run with one
# green gate, its count line has its digits replaced, and the generated runner's green
# count line must match it exactly.
# =============================================================================
case_kit_init_generated_runner_speaks_the_frame() {
  cf_reset
  if ! has_kit_init; then skp "kit-init's generated runner speaks the frame's vocabulary" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init's generated runner speaks the frame's vocabulary" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local frame_shape out rc v line want_rc want_word row

  # The frame's count-line shape, from the frame itself.
  make_sandbox
  _neu_array "$SB_WORK/scripts/verify.sh" GATES
  _declare_gate 'g|core|/bin/echo ok'
  frame_shape="$( cd "$SB_WORK" && ./scripts/verify.sh 2>&1 | grep '^gates declared:' | sed 's/[0-9][0-9]*/N/g' )"
  teardown
  [ -n "$frame_shape" ] || { cf "(control) the frame printed no 'gates declared:' line — there is no shape to hold the generated runner to"; finish "kit-init's generated runner speaks the frame's vocabulary"; return; }

  # Generate the runner through kit-init, on a tree with no verify.sh.
  kit_init_sandbox
  rm -f "$SB_WORK/scripts/verify.sh"
  printf '#!/usr/bin/env bash\n# sandbox gate: its exit code comes from SBG_RC; 127 is a command that cannot start\nif [ "${SBG_RC:-0}" = 127 ]; then /nonexistent-dir-for-the-harness/interpreter; exit $?; fi\nexit "${SBG_RC:-0}"\n' > "$SB_WORK/sandbox-gate"
  chmod +x "$SB_WORK/sandbox-gate"
  publish_sandbox
  rc=0; out="$( cd "$SB_WORK" && ./scripts/kit-init.sh --prefix SBX --trunk "$SB_TRUNK" --gate-command ./sandbox-gate --skip-self-check 2>&1 )" || rc=$?
  v="$SB_WORK/scripts/verify.sh"
  if [ "$rc" -ne 0 ] || ! grep -q 'GENERATED by kit-init.sh' "$v" 2>/dev/null; then
    cf "(control) kit-init did not generate a runner (rc=$rc): $(printf '%s' "$out" | tail -6 | tr '\n' '|')"
    finish "kit-init's generated runner speaks the frame's vocabulary"; teardown; return
  fi

  # gate rc -> runner status, per-gate word, count line
  # 127 is REAL (a command that is not there); 126 is the gate reporting it, the same to the runner.
  for row in "0 0 PASS" "1 1 FAIL" "2 1 FAIL" "3 1 FAIL" "126 3 UNRUNNABLE" "127 3 UNRUNNABLE"; do
    set -- $row; local g="$1"; want_rc="$2"; want_word="$3"
    rc=0; out="$( cd "$SB_WORK" && SBG_RC="$g" ./scripts/verify.sh 2>&1 )" || rc=$?
    [ "$rc" -eq "$want_rc" ] || cf "(gate exits $g) the runner exited $rc, expected $want_rc — the gate's own code passed through as the runner's"
    line="$(printf '%s\n' "$out" | grep -E '^(PASS|FAIL|UNRUNNABLE)  ' | head -1)"
    printf '%s\n' "$line" | grep "^$want_word  " >/dev/null \
      || cf "(gate exits $g) the per-gate line is not $want_word: ${line:-none}"
    [ "$g" = 0 ] || printf '%s\n' "$line" | grep "rc=$g" >/dev/null \
      || cf "(gate exits $g) the per-gate line does not keep the gate's own code (rc=$g): $line"
    printf '%s\n' "$out" | grep '^gates declared:' >/dev/null \
      || cf "(gate exits $g) no 'gates declared:' count line"
  done
  # the count line has the frame's shape, and its counts agree with the word
  rc=0; out="$( cd "$SB_WORK" && SBG_RC=0 ./scripts/verify.sh 2>&1 )" || rc=$?
  [ "$(printf '%s\n' "$out" | grep '^gates declared:' | sed 's/[0-9][0-9]*/N/g')" = "$frame_shape" ] \
    || cf "the generated count line does not have the frame's shape — frame: '$frame_shape'; generated: '$(printf '%s\n' "$out" | grep '^gates declared:')'"
  rc=0; out="$( cd "$SB_WORK" && SBG_RC=127 ./scripts/verify.sh 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep '^gates declared:' | grep -F 'failed: 0 · could not run: 1' >/dev/null \
    || cf "(127) the count line does not say failed: 0 · could not run: 1: $(printf '%s\n' "$out" | grep '^gates declared:')"
  rc=0; out="$( cd "$SB_WORK" && SBG_RC=3 ./scripts/verify.sh 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep '^gates declared:' | grep -F 'failed: 1 · could not run: 0' >/dev/null \
    || cf "(3) the count line does not say failed: 1 · could not run: 0: $(printf '%s\n' "$out" | grep '^gates declared:')"

  finish "kit-init's generated runner maps its gate to the frame's statuses (0→0, 127→3 UNRUNNABLE, 1/2/3→1 FAIL, the gate's own code kept in the line) and prints the frame's count line, its shape derived from the frame"
  teardown
}

# =============================================================================
# CASE — every tool that PROMISES to render the role set has a --help that AGREES with its
#        --role enforcement. Population DERIVED from the promise, not listed.
#
# THE DEFECT THIS IS NAMED FOR SHIPPED, and nothing was red. The header
# carried the set SPACE-PADDED and the enforcement arm carried it unpadded. `kit-init
# --roles` finds the seams to stamp with `grep -lF` on the unpadded shape, so it rewrote
# the enforcement and COULD NOT SEE the header. Every adopter who narrowed their role set
# got a `move-issue.sh --help` advertising four roles the same script refuses — and the
# usage text is the one place an operator looks to find out what is legal.
#
# AND THE CASE THAT LOOKS LIKE IT ALREADY COVERS THIS CANNOT, WHICH IS THE POINT.
# case_kit_init_roles_leave_no_seam asserts exactly the right thing — "no seam keeps the
# old set" — and then derives WHICH FILES ARE SEAMS with `grep -lF -- "$old"`, the same
# matcher the initializer uses. The instrument and the subject share a blind spot BY
# CONSTRUCTION, so that case can never see anything the initializer misses. Verifying
# with the subject's own derivation is the defect process/doctrine/instruments.md states: derive
# twice, independently, and compare.
#
# SO THE TWO OPERANDS HERE ARE READ FROM OUTSIDE BOTH.
#   * the DECLARED set is what kit-init was TOLD on its command line — not read back
#     through any expression the kit ships, so no shared expression can hide a failure;
#   * the ADVERTISED set is parsed out of what `--help` actually PRINTS — the operator's
#     view, not the file's text.
# A padded copy, a stale copy, or a copy in a shape nobody has thought of yet fails here,
# because neither derivation reads the other. A TEXT match on the file could not do this:
# it cannot tell a stamped whitelist from a stamped comment, and it is satisfied by a file
# that carries the new set AND the old one.
#
# NOT COVERED, and named because an instrument that does not name its span is the class
# this case belongs to.
#   * WHETHER THE ENFORCEMENT'S LIST IS ITSELF DERIVED. It is a stamped literal, so a
#     hand-edited hook moves the help text and leaves the enforcement behind — the same
#     disagreement in the other direction. Unfixed, and unsupported rather than harmless:
#     kit-init refuses a tree that has already lived, and the hook still refuses the commit,
#     but refusing BEFORE the git mv is the whitelist's whole value.
#   * ROLE SETS IN FILES WITH NO HELP WINDOW AT ALL. The negative census below scans the
#     comment block lib/usage.sh renders and nothing else, so a role set in a script's body,
#     in a template, or in a document is invisible to it. That is a deliberate scope and not
#     an exemption: the authority's own declaration lives in a body, and an arm that flagged
#     bodies would flag the authority.
#
# THE POPULATION USED TO BE ONE FILE AND IS NOW DERIVED, and the reason it was one file is
# kept because it was a good reason. This case judged move-issue.sh alone and NAMED that as a
# hole, deliberately not widening: scripts/subtask.sh carried the same defect in a THIRD shape
# (a partial subset in its own order, which `grep -lF` cannot match either), and widening
# before that file was fixed would have made this case red about something its own change did
# not repair — which teaches a reader to ignore it. Both landed together instead. The
# population is now every tool carrying the @ROLE_SET@ token, and a SECOND census asserts that
# no help window anywhere under scripts/ still carries a literal, in ANY shape.
#
# WHY A NEGATIVE CENSUS RATHER THAN A FOURTH SHAPE FOR THE MATCHER. Three shapes have been
# found: the full set unpadded, which the initializer does rewrite; the full set space-padded,
# which it cannot see; and a partial subset in its own order, which it also cannot see. Two of
# the three were found by accident. Enumerating shapes is a losing game — asserting that no
# literal survives anywhere is not, and it is the same move as deriving a population instead
# of listing one.
# =============================================================================
case_help_advertises_exactly_what_the_role_arm_accepts() {
  cf_reset
  if ! has_kit_init; then skp "--help advertises exactly what the --role arm accepts" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "--help advertises exactly what the --role arm accepts" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  # A NARROWING THAT REMOVES MEMBERS. A set equal to the shipped one would be satisfied by
  # both sides carrying the shipped list, which is the state the defect lived in.
  local shipped="$KIT_NEUTRAL_ROLE_PREFIXES" declared='PM|Dev|Architect' out rc=0
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --roles "$declared" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] \
    || _fixture_die "case_help_advertises_exactly_what_the_role_arm_accepts: kit-init --roles exited $rc, so nothing below is about a narrowed tree: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # ── THE WITHDRAWN MEMBERS ARE DERIVED, never typed. A typed name goes stale the day the
  #    shipped set changes, and case_role_literals_are_declared scans this file for
  #    `--role <Name>` literals — a name written here would redden that case on this
  #    case's own text. (Measured on an earlier control in this suite.)
  local withdrawn
  withdrawn="$(printf '%s\n' "$shipped" | tr '|' '\n' \
               | grep -vxF -f <(printf '%s\n' "$declared" | tr '|' '\n') || true)"
  [ -n "$withdrawn" ] \
    || _fixture_die "case_help_advertises_exactly_what_the_role_arm_accepts: the narrowing removed no member, so 'advertised == declared' would be satisfied by either side carrying the shipped set."

  # ── POPULATION 1, DERIVED FROM THE DECLARATION SITE: every shipped tool that carries the
  #    @ROLE_SET@ token is a tool PROMISING to render the role set from the seam, and this case
  #    holds it to that promise. Keyed on the token rather than on a list of filenames, so a tool
  #    that adopts the pattern joins by adopting it. This is the same exception the config-seam
  #    census records: an implementation shape is the right key when the shape IS the property's
  #    declaration, which a placeholder in a help window unambiguously is.
  local tools
  tools="$(cd "$SB_WORK/scripts" && grep -lF '@ROLE_SET@' ./*.sh 2>/dev/null | sed 's@^\./@@' | sort)"
  [ -n "$tools" ] \
    || _fixture_die "case_help_advertises_exactly_what_the_role_arm_accepts: no shipped tool carries the @ROLE_SET@ token, so every arm below would pass over an empty population."

  # ── POPULATION 2, DERIVED, AND IT MUST BE EMPTY. Any shipped file whose HELP WINDOW carries an
  #    alternation of declared role names is carrying a SECOND COPY of the role set, in whatever
  #    shape its author typed. This is the arm that catches a shape nobody has thought of yet, and
  #    it exists because three shapes have already been found: the full set unpadded (which the
  #    initializer's `grep -lF` does rewrite), the full set SPACE-PADDED (which it cannot see), and
  #    a PARTIAL SUBSET IN ITS OWN ORDER (which it also cannot see). Enumerating shapes is a losing
  #    game; asserting that no literal survives anywhere is not.
  #
  #    NO EXEMPTION LIST, and that is a measured property rather than an omission: the window is
  #    the comment block lib/usage.sh renders, so the AUTHORITY's own declaration
  #    (ROLE_PREFIXES in scripts/githooks/commit-msg) is out of scope by construction — it is code,
  #    not a help window — and so is every role name in a script's body. Measured empty over
  #    scripts/*.sh, scripts/test/run.sh, scripts/lib/*.sh and scripts/githooks/* on a narrowed tree.
  #
  #    THE SELECTOR IS REDDENED IN FIVE DIRECTIONS, because an empty result is also what a broken
  #    selector returns. Planted into a help window and re-run: the unpadded narrowed set is found,
  #    the PADDED set is found, a partial subset out of order is found; a non-role alternation
  #    (folder names) is correctly NOT found, and a role alternation placed AFTER the code is
  #    correctly out of scope. The three positives are the three shapes actually observed in this
  #    tree; the two negatives are what stops this arm reddening on prose.
  #    AND THE SELECTOR IS CONTROLLED HERE, not only in the record that added it. Those five
  #    directions were measured by hand once; that is evidence about a tree on a past day and not
  #    about THIS run. An empty result from a selector that stopped matching is indistinguishable
  #    from a clean corpus, so the selector runs first against a window built to be found.
  local kb="$SB_TMP/known-bad-window.sh"
  { echo '#!/usr/bin/env bash'
    echo '# KIT-CLASS: KIT — a fixture. See process/EXTRACTION.md.'
    echo '#   roles: PM | Dev | QA'
    echo 'set -eu'; } > "$kb"
  local kb_start kb_hit
  kb_start="$(awk 'NR<=12 && /EXTRACTION\.md/{print NR+1; exit}' "$kb")"
  kb_hit="$(awk -v s="${kb_start:-0}" 'NR>=s { if ($0 ~ /^#/) print; else exit }' "$kb" \
            | grep -oE '[A-Z][A-Za-z]+([[:space:]]*\|[[:space:]]*[A-Z][A-Za-z]+){1,}' \
            | awk -v ok="$shipped" 'BEGIN{n=split(ok,M,"|"); for(i=1;i<=n;i++) mem[M[i]]=1}
                 { a=$0; gsub(/[[:space:]]*\|[[:space:]]*/,"|",a)
                   k=split(a,T,"|"); for(i=1;i<=k;i++) if (T[i] in mem) { print a; next } }')"
  [ -n "$kb_hit" ] \
    || _fixture_die "case_help_advertises_exactly_what_the_role_arm_accepts: the literal-census selector does not match a SPACE-PADDED role alternation in a known-bad help window, so it would report a clean corpus whatever the shipped tree carries. Every census result below is vacuous until this passes."
  rm -f "$kb"

  local f start hit literal_carriers=''
  # The harness is read from the real tree: make_sandbox removes scripts/test/, and only run.sh renders --help.
  for f in "$SB_WORK"/scripts/*.sh "$REAL_SCRIPTS"/test/run.sh "$SB_WORK"/scripts/lib/*.sh "$SB_WORK"/scripts/githooks/*; do
    [ -f "$f" ] || continue
    start="$(awk 'NR<=12 && /EXTRACTION\.md/{print NR+1; exit}' "$f")"
    [ -n "${start:-}" ] || continue
    hit="$(awk -v s="$start" 'NR>=s { if ($0 ~ /^#/) print; else exit }' "$f" \
           | grep -oE '[A-Z][A-Za-z]+([[:space:]]*\|[[:space:]]*[A-Z][A-Za-z]+){1,}' \
           | awk -v ok="$shipped" 'BEGIN{n=split(ok,M,"|"); for(i=1;i<=n;i++) mem[M[i]]=1}
                { a=$0; gsub(/[[:space:]]*\|[[:space:]]*/,"|",a)
                  k=split(a,T,"|"); for(i=1;i<=k;i++) if (T[i] in mem) { print a; next } }' \
           | sort -u | tr '\n' ' ')"
    [ -n "$hit" ] && literal_carriers="$literal_carriers$(basename "$f")[$hit] "
  done
  [ -z "$literal_carriers" ] \
    || cf "a help window still carries a role-set LITERAL, which is a second copy of the set in a shape the initializer's matcher may not be able to rewrite: $literal_carriers— render it from the seam with the @ROLE_SET@ token instead"

  # ── PER MEMBER. Every arm below runs for every member of population 1, so a tool that adopts
  #    the token inherits the whole case rather than only the parts somebody remembered.
  local t tool_path help_out advertised adv_n dec_n
  dec_n="$(printf '%s\n' "$declared" | tr '|' '\n' | sed 's/[[:space:]]//g' | grep -c . || true)"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    tool_path="$SB_WORK/scripts/$t"
    [ -f "$tool_path" ] \
      || _fixture_die "case_help_advertises_exactly_what_the_role_arm_accepts: $t is in the derived population but absent from the sandbox — the subject is gone."

    # ── ARM (a) THE ADVERTISED SET IS THE DECLARED SET, both directions.
    help_out="$( cd "$SB_WORK" && "./scripts/$t" --help 2>&1 )"; rc=$?
    [ "$rc" -eq 0 ] \
      || cf "($t a) --help exited $rc — a usage request must ALWAYS succeed (issue-creation.md § 3), and this one renders derived content, which is the path that can fail"
    printf '%s' "$help_out" | grep -F '@ROLE_SET@' >/dev/null \
      && cf "($t a) --help printed the @ROLE_SET@ token itself — the placeholder reached the operator unexpanded, so the tool advertises nothing at all"
    advertised="$(printf '%s\n' "$help_out" | sed -n 's/^[[:space:]]*<R> = //p' | head -1)"
    [ -n "$advertised" ] \
      || _fixture_die "case_help_advertises_exactly_what_the_role_arm_accepts: $t carries the token but --help prints no '<R> = ' line, so there is no advertised set to compare and every arm below would pass over nothing."

    # Compared as SETS, on normalized whitespace: the presentation may legitimately pad with
    # spaces, and the defect was never about presentation — it was about MEMBERSHIP.
    adv_n="$(printf '%s\n' "$advertised" | tr '|' '\n' | sed 's/[[:space:]]//g' | grep -c . || true)"
    diff <(printf '%s\n' "$advertised" | tr '|' '\n' | sed 's/[[:space:]]//g' | grep . | sort) \
         <(printf '%s\n' "$declared"   | tr '|' '\n' | sed 's/[[:space:]]//g' | grep . | sort) >/dev/null 2>&1 \
      || cf "($t a) --help advertises a role set that is not the one this project declares. advertised ($adv_n): '$advertised' — declared ($dec_n): '$declared'. The usage text is where an operator learns what is legal, so this is a tool lying about itself"

    # ── ARM (b) THE CONSEQUENCE, not the text. A withdrawn role must be REFUSED, and a
    #    declared one must not be — otherwise (a) is satisfied by a help line that agrees
    #    with a whitelist neither of them reaches.
    #
    #    THE INVOCATION IS DECLARED PER TOOL, NEVER GUESSED. A catch-all here would run each new
    #    member with arguments nobody chose for it; it would exit non-zero for an ARITY reason and
    #    every "it refused" assertion would pass on a refusal that has nothing to do with the role
    #    set. That is the vacuous-satisfaction shape the config-seam census was repaired for, and
    #    the fix is the same: name the members, and die on one that is not named.
    #    THE DISPATCH IS OUTSIDE ANY COMMAND SUBSTITUTION, and that placement is the whole point
    #    rather than a style choice. `_fixture_die` ends in `exit 1`; inside `$( … )` that exits the
    #    SUBSHELL and the harness carries on with the die message captured as the probe's output —
    #    so a catch-all written there is a guard that cannot fire, which is the defect class this
    #    case belongs to. The invocation is therefore built ONCE, here, as an argv array with
    #    `--role` last so the role is appended; every probe below reuses it.
    local r probe_out kept
    local -a probe_cmd
    kept="$(printf '%s' "$declared" | cut -d'|' -f1)"
    case "$t" in
      move-issue.sh) probe_cmd=(./scripts/move-issue.sh SBX-001 in_progress --note n --role) ;;
      # subtask.sh takes a `move` SUBCOMMAND and a <PARENT>-sM id. --role is validated before the
      # subtask tree is resolved, verified by running it: a declared role on a nonexistent tree
      # reaches "no subtask tree at …", which is past the whitelist.
      subtask.sh)    probe_cmd=(./scripts/subtask.sh move SBX-001-s1 in_progress --note n --role) ;;
      *) _fixture_die "case_help_advertises_exactly_what_the_role_arm_accepts: '$t' joined the derived population and no invocation is declared for it. Add its arm — a case that cannot exercise a member knows nothing about it." ;;
    esac
    probe_out="$( cd "$SB_WORK" && "${probe_cmd[@]}" "$kept" 2>&1 || true )"
    printf '%s' "$probe_out" | grep -- '--role must be' >/dev/null \
      && cf "($t b) it refused '$kept', a member of the set this project just declared — its whitelist was not stamped, and --help now advertises a role the tool rejects"
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      # THE ADVERTISED SET, NOT THE WHOLE HELP TEXT — and this distinction was MEASURED rather
      # than reasoned. Grepping all of --help for a withdrawn role reddens on the header's
      # EXAMPLES, which name a concrete role so they read as runnable commands. Those are a real
      # and separate instance of this class; both tools now carry a label saying an example value
      # is an example, which is disclosure rather than removal. Named in the finish line.
      printf '%s\n' "$advertised" | tr '|' '\n' | sed 's/[[:space:]]//g' | grep -x "$r" >/dev/null \
        && cf "($t b) the advertised set still names '$r', which this project's declared set does not contain — a second copy of the set, in a shape the stamper's matcher cannot produce and therefore cannot rewrite"
      probe_out="$( cd "$SB_WORK" && "${probe_cmd[@]}" "$r" 2>&1 || true )"
      printf '%s' "$probe_out" | grep -- '--role must be' >/dev/null \
        || cf "($t b) it did NOT refuse '$r', a role this project no longer declares — the whitelist was not stamped, or the arm was never reached: $(printf '%s' "$probe_out" | tr '\n' '|' | cut -c1-160)"
    done <<WITHDRAWN_EOF
$withdrawn
WITHDRAWN_EOF

    # ── ARM (c) THE DEGRADATION IS HONEST, because arm (a) made the usage path depend on a
    #    library and a seam. issue-creation.md § 3 says a usage request ALWAYS succeeds; the
    #    sheet's rule for derived content is that it degrades to NAMING THE SOURCE and never
    #    to a guess — a list that is right about the kit and wrong about this project is the
    #    defect being removed, not a fallback from it.
    # THE PASS COUNT IS DERIVED FROM THE SAME LIST THE LOOP RUNS, never typed beside it: a
    # literal here would go stale the day a third seam file joins the loop, and the message
    # would then number the passes wrongly while looking authoritative.
    local d keep c_i=0 c_n
    local -a c_seams=(scripts/lib/role-set.sh scripts/githooks/commit-msg)
    c_n=${#c_seams[@]}
    for d in "${c_seams[@]}"; do
      c_i=$(( c_i + 1 ))
      keep="$SB_TMP/$(basename "$d").keep"
      cp "$SB_WORK/$d" "$keep" 2>/dev/null || { _control_did_not_run "stash $d to remove it"; continue; }
      rm -f "$SB_WORK/$d"
      out="$( cd "$SB_WORK" && "./scripts/$t" --help 2>&1 )"; rc=$?
      [ "$rc" -eq 0 ] \
        || cf "($t c, pass $c_i of $c_n, $d absent) --help exited $rc — a usage request must always succeed, and this is the path arm (a) put a dependency on"
      # THE MESSAGE REPORTS THE OPERAND THE ASSERTION READ, NOT A SECOND DERIVATION OVER IT.
      # This `cf` used to print a `sed` for the `<R> = ` line while the assertion grepped for a
      # token, so the two read the same string by different routes and could describe different
      # states — and with the seam removed there may be no `<R> = ` line at all, which rendered an
      # EMPTY tail that cannot distinguish "--help printed nothing" from "--help printed plenty,
      # none of it a role line". Both are reported here instead: the byte length is unambiguous
      # where an extracted line is not, and `$d` and the iteration make two `cf`s unreadable as one.
      # (Arm (a) already halts on an absent `<R> = ` line, but it runs on the INTACT tree — this
      # loop has just removed the seam, so that guard says nothing about this string.)
      printf '%s\n' "$out" | grep 'ROLE_PREFIXES' >/dev/null \
        || cf "($t c, pass $c_i of $c_n, $d absent) --help does not NAME the seam the role set comes from — it degraded to something that tells the operator nothing about where to look. It printed ${#out} byte(s): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
      printf '%s\n' "$out" | grep -F -- "$shipped" >/dev/null \
        && cf "($t c, pass $c_i of $c_n, $d absent) --help printed the KIT'S SHIPPED set — it guessed, and a guess that is right about the kit and wrong about this project is the exact defect this case is named for"
      cp "$keep" "$SB_WORK/$d"; chmod +x "$SB_WORK/$d" 2>/dev/null || true
    done

    # ── THE REDDENING CONTROL, PER MEMBER, and it re-introduces the ORIGINAL DEFECT rather than a
    #    synthetic one: the padded shipped-set literal, back in the header where it used to live.
    #    Arm (a)'s comparison must fire. A control that cannot reproduce the defect the case is
    #    named for is not a control (instruments.md § A.2).
    local padded n_leg ctl_adv
    padded="$(printf '%s' "$shipped" | sed 's/|/ | /g')"
    n_leg="$(grep -c '<R> = ' "$tool_path" || true)"
    if [ "$n_leg" != "1" ]; then
      _control_did_not_run "locate exactly one '<R> = ' line in $t to overwrite (found $n_leg)"
    else
      # WRITTEN BY POSITION, and back through `cat` rather than `mv`. index/substr interprets
      # nothing, so a `|`-bearing replacement survives; `cat >` truncates the ORIGINAL file, which
      # keeps its executable bit — `mv` would give it the temp file's mode and leave a tool the
      # next arm cannot run. (That mode-loss shipped once in this repository already.)
      awk -v p="$padded" '
        { i = index($0, "<R> = ")
          if (i) print substr($0, 1, i + 5) p
          else   print }' "$tool_path" > "$SB_TMP/ctl.$t" \
        && cat "$SB_TMP/ctl.$t" > "$tool_path"
      if ! grep -qF -- "$padded" "$tool_path"; then
        _control_did_not_run "plant the padded shipped set into $t's header (the substitution matched nothing)"
      else
        [ -x "$tool_path" ] \
          || _control_did_not_run "keep $t executable across the plant (the control broke its own subject)"
        ctl_adv="$( cd "$SB_WORK" && "./scripts/$t" --help 2>&1 | sed -n 's/^[[:space:]]*<R> = //p' | head -1 )"
        diff <(printf '%s\n' "$ctl_adv"  | tr '|' '\n' | sed 's/[[:space:]]//g' | grep . | sort) \
             <(printf '%s\n' "$declared" | tr '|' '\n' | sed 's/[[:space:]]//g' | grep . | sort) >/dev/null 2>&1 \
          && cf "($t control) the padded shipped-set literal was planted back into the header and arm (a) still saw the declared set — the comparison is reading something other than what --help prints, and it cannot see the defect it is named for"
      fi
    fi
  done <<TOOLS_EOF
$tools
TOOLS_EOF

  finish "every shipped tool that PROMISES to render the role set from the seam advertises EXACTLY the set this project declares ($dec_n member(s)) and refuses every member it does not — population DERIVED from the @ROLE_SET@ token rather than listed ($(printf '%s' "$tools" | tr '\n' ' ')), with both operands derived independently (the declared set from kit-init's own argument, the advertised set from what --help prints) so no shared expression can hide a disagreement; each member's --role probe is DECLARED per tool and an undeclared member halts the case rather than being run with guessed arguments; the usage path degrades to NAMING the seam (never guessing the shipped set) with either the library or the hook absent; NO help window anywhere under scripts/ still carries a role-set literal, in any of the three shapes observed (full unpadded, space-padded, partial subset out of order), with that selector reddened in five directions including a non-role alternation and a role name outside the window; and re-planting the original padded literal reddens arm (a) for every member. NOT COVERED, and each is a HOLE rather than an exemption: whether the ENFORCEMENT list is itself derived rather than stamped (it is not, so a hand-edited hook leaves it behind while this help text follows); the header EXAMPLES, which name a concrete role in the argument position so they read as runnable commands and therefore name a refused one on a tree that withdrew it — both tools now carry a label saying an example value is an example, which is DISCLOSURE and not removal; and role sets in files with no help window at all, which this arm cannot see by construction"
  teardown
}

# =============================================================================
# CASE — the --role enforcement DERIVES the set, and when it cannot, it says so.
#
# THE DEFECT THIS IS NAMED FOR SHIPPED AND WAS MEASURED, not reasoned. Both tools' `--help` was
# made to derive the role set from the hook at print time — through lib/role-set.sh's
# kit_role_display, which is where that history is written down. The
# ENFORCEMENT stayed a hand-typed alternation that `kit-init --roles` rewrites once. So the two
# halves had different AUTHORITIES, and on a tree whose hook moved without the initializer —
# which the kit's own documented upgrade produces, since the literal lived in a file an upgrade
# REPLACES — they disagreed to the operator's face: the usage text named two roles and the refusal
# message named three, in the same session.
#
# AND THE STALENESS WAS IN THE PERMISSIVE DIRECTION, which is the dangerous one. A withdrawn role
# PASSED the whitelist. That whitelist exists to refuse BEFORE the git mv and the Activity append,
# because the commit-msg hook refuses AFTER them — leaving uncommitted state in the shared kanban
# worktree that the next board operation `reset --hard`s. So a stale-permissive literal does not
# produce the error you asked for, it produces an INCONSISTENT BOARD and a discarded Activity entry
# in somebody else's lane — which is why scripts/lib/role-set.sh exists. NOT "silent": that word was
# in this comment and in that header, and it was measured wrong end to end — the next invocation
# reports the dirty worktree and names both ways out. The cost is real and it is recoverable, and
# saying so is what keeps the rest of the rationale credible.
#
# WHAT THIS CASE ASSERTS, AND WHY EACH ARM IS NOT THE OTHERS:
#   (a) DERIVED — a role the project declares is accepted and one it withdrew is refused, on a
#       tree narrowed WITHOUT re-stamping anything. This is the arm the old literal could not pass.
#   (b) ANNOUNCED — with the seam unreadable the tool still enforces, and SAYS the set it used is
#       a fallback. A default that presents as the project's set is a false claim about this tree,
#       and `process/contracts/issue-creation.md` § 3 forbids exactly that.
#   (c) THE ANNOUNCEMENT IS ABSENT WHEN DERIVED. Without this, (b) is satisfied by a tool that
#       announces unconditionally, which would make the announcement meaningless.
#   (d) THE FALLBACK IS THE PROJECT'S SET, NOT THE KIT'S — a role in the shipped set but not in
#       this project's is still refused on the fallback path. This is the arm that would catch the
#       default being moved somewhere `kit-init --roles` cannot stamp.
#
# THE POPULATION IS DERIVED FROM THE ANNOUNCEMENT STRING, which is the declaration site: a tool
# carrying it is a tool claiming to have a named fallback, and this case holds it to the claim.
#
# NOT COVERED, and named because an instrument that does not name its span is the class this case
# belongs to:
#   * scripts/check-board.sh CARRIES THE SAME ANNOUNCEMENT — twice, for the role set and for the
#     trailer markers — AND THIS CASE CANNOT REACH EITHER. It reads the hook from the REF it
#     scans (CB_TREE is a temp checkout when --ref is used), so removing the working-tree hook
#     does not reach its derivation: measured, it still reported "prefixes derived from
#     scripts/githooks/commit-msg" with the working file gone. Reaching its fallback needs the
#     hook absent from the scanned ref, which is a different fixture and one NO case here builds.
#     So check-board.sh's two announcements remain real but unverified, which is what they were
#     before this case existed.
#   * WHETHER THE HOOK'S OWN LIST IS DERIVED. It is the authority, so there is nothing above it to
#     derive from; a hand-edited hook is the state arm (a) is about, not a defect in the hook.
# =============================================================================
case_role_enforcement_derives_and_names_its_fallback() {
  cf_reset
  if ! has_kit_init; then skp "--role derives the declared set, and names its fallback" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "--role derives the declared set, and names its fallback" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  # ── POPULATION, DERIVED FROM THE DECLARATION SITE. `scripts/*.sh` only: a library has no output
  #    of its own, and scripts/lib/role-set.sh is where two of these tools get the wording from.
  local ann='THE KIT'"'"'S FALLBACK SET'
  local tools
  tools="$(cd "$SB_WORK/scripts" && grep -lF -- "$ann" ./*.sh 2>/dev/null | sed 's@^\./@@' | sort)"
  [ -n "$tools" ] \
    || _fixture_die "case_role_enforcement_derives_and_names_its_fallback: no shipped tool declares a named fallback for the role set, so every arm below would pass over an empty population."

  # A NARROWING THAT REMOVES MEMBERS, so "derived" and "the kit's set" are distinguishable at all.
  local shipped="$KIT_NEUTRAL_ROLE_PREFIXES" declared='PM|Dev|Architect' out rc=0
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --roles "$declared" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] \
    || _fixture_die "case_role_enforcement_derives_and_names_its_fallback: kit-init --roles exited $rc, so nothing below is about a narrowed tree: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # THE WITHDRAWN MEMBERS ARE DERIVED, never typed — case_role_literals_are_declared scans this
  # file for `--role <Name>` literals, so a typed name would redden that case on this case's text.
  local withdrawn kept
  withdrawn="$(printf '%s\n' "$shipped" | tr '|' '\n' \
               | grep -vxF -f <(printf '%s\n' "$declared" | tr '|' '\n') || true)"
  [ -n "$withdrawn" ] \
    || _fixture_die "case_role_enforcement_derives_and_names_its_fallback: the narrowing removed no member, so 'refuses what the project withdrew' would be satisfied by either set."
  kept="$(printf '%s' "$declared" | cut -d'|' -f1)"

  local t hook="$SB_WORK/scripts/githooks/commit-msg" held="$SB_TMP/commit-msg.held274"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    [ -f "$SB_WORK/scripts/$t" ] \
      || _fixture_die "case_role_enforcement_derives_and_names_its_fallback: $t is in the derived population but absent from the sandbox."

    # THE INVOCATION IS DECLARED PER TOOL AND THE DIE IS OUTSIDE ANY COMMAND SUBSTITUTION.
    # `_fixture_die` ends in `exit 1`; inside `$( … )` that exits the SUBSHELL and the harness
    # carries on with the die message captured as output — a guard that cannot fire. Built once,
    # here, as an argv array with `--role` last so the role is appended.
    local -a probe
    case "$t" in
      move-issue.sh)  probe=(./scripts/move-issue.sh SBX-001 in_progress --note n --role) ;;
      subtask.sh)     probe=(./scripts/subtask.sh move SBX-001-s1 in_progress --note n --role) ;;
      check-board.sh) probe=() ;;   # declared UNREACHABLE, not forgotten — see the span above.
      *) _fixture_die "case_role_enforcement_derives_and_names_its_fallback: '$t' declares a named fallback and no invocation is declared for it. Add its arm — a case that cannot exercise a member knows nothing about it." ;;
    esac
    [ "${#probe[@]}" -gt 0 ] || continue

    local r probe_out
    # ── ARM (a) DERIVED, both directions, with NOTHING re-stamped since kit-init ran.
    probe_out="$( cd "$SB_WORK" && "${probe[@]}" "$kept" 2>&1 || true )"
    printf '%s' "$probe_out" | grep -- '--role must be' >/dev/null \
      && cf "($t a) refused '$kept', a member of the set this project declares — the enforcement is not reading the declared set"
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      probe_out="$( cd "$SB_WORK" && "${probe[@]}" "$r" 2>&1 || true )"
      printf '%s' "$probe_out" | grep -- '--role must be' >/dev/null \
        || cf "($t a) did NOT refuse '$r', a role this project withdrew — this is the PERMISSIVE staleness the whitelist exists to prevent: the board moves, the hook refuses the commit afterwards, and the shared kanban worktree loses it: $(printf '%s' "$probe_out" | tr '\n' '|' | cut -c1-140)"
    done <<W274_EOF
$withdrawn
W274_EOF

    # ── ARM (c) THE ANNOUNCEMENT IS ABSENT WHILE THE SEAM IS READABLE. Ordered before (b) on
    #    purpose: it is the control that gives (b) its meaning, and it runs on the untouched tree.
    probe_out="$( cd "$SB_WORK" && "${probe[@]}" "$kept" 2>&1 || true )"
    printf '%s' "$probe_out" | grep -F -- "$ann" >/dev/null \
      && cf "($t c) announced a fallback while the seam was READABLE — an announcement that always fires says nothing, and arm (b) below would be satisfied by it"

    # ── ARM (b) WITH THE SEAM UNREADABLE: still enforces, and NAMES the fallback IN THE OUTPUT.
    cp "$hook" "$held" 2>/dev/null || { _control_did_not_run "stash the commit-msg hook for $t"; continue; }
    rm -f "$hook"
    if [ -e "$hook" ]; then
      _control_did_not_run "remove the commit-msg hook for $t (it is still there, so nothing below is about an unreadable seam)"
    else
      probe_out="$( cd "$SB_WORK" && "${probe[@]}" "$kept" 2>&1 || true )"
      printf '%s' "$probe_out" | grep -F -- "$ann" >/dev/null \
        || cf "($t b) with the seam unreadable it did not SAY the set was a fallback — the announcement is in the file and not in the output, so an operator is told a set that is not their project's as though it were: $(printf '%s' "$probe_out" | tr '\n' '|' | cut -c1-140)"
      # STILL ENFORCES. A fallback that stops checking is option 1, which this change rejected:
      # it would silently widen --role to anything on a tree whose hook is gone.
      probe_out="$( cd "$SB_WORK" && "${probe[@]}" "$(printf 'Nonexistent%s' "$$")" 2>&1 || true )"
      printf '%s' "$probe_out" | grep -- '--role must be' >/dev/null \
        || cf "($t b) with the seam unreadable it accepted a role no set contains — the fallback stopped enforcing rather than enforcing a named default"

      # ── ARM (d) THE FALLBACK IS THIS PROJECT'S SET, NOT THE KIT'S. A withdrawn role must STILL
      #    be refused on the fallback path, which is only true if the default was stamped where
      #    `kit-init --roles` could reach it. This is the arm that catches the default being
      #    moved into scripts/lib/, which that glob does not cover.
      while IFS= read -r r; do
        [ -n "$r" ] || continue
        probe_out="$( cd "$SB_WORK" && "${probe[@]}" "$r" 2>&1 || true )"
        printf '%s' "$probe_out" | grep -- '--role must be' >/dev/null \
          || cf "($t d) on the fallback path it accepted '$r', which this project withdrew — the default is the KIT'S set rather than this project's, so it was never stamped, and the fallback is more permissive than the literal it replaced"
      done <<W274D_EOF
$withdrawn
W274D_EOF
    fi
    cp "$held" "$hook"; chmod +x "$hook" 2>/dev/null || true; rm -f "$held"
  done <<T274_EOF
$tools
T274_EOF

  finish "the --role enforcement DERIVES this project's declared set — accepting what it declares and refusing what it withdrew on a tree narrowed with nothing re-stamped since, which the hand-typed alternation this replaced could not do — and when the seam is unreadable it enforces a STAMPED DEFAULT and NAMES it as a fallback in its OUTPUT, refusing both a role no set contains and a role this project withdrew, so the default is this project's rather than the kit's; the announcement is asserted ABSENT while the seam is readable, without which an unconditional announcement would satisfy the arm above it; population DERIVED from the announcement string ($(printf '%s' "$tools" | tr '\n' ' ')) with each tool's invocation DECLARED and an undeclared member halting the case. NOT COVERED, and each is a HOLE rather than an exemption: scripts/check-board.sh carries this same announcement TWICE and this case reaches NEITHER, because it reads the hook from the ref it scans rather than from the working tree — measured, it still reported the set as derived with the working hook removed — so its fallbacks remain real but unverified and want a ref-level fixture nothing here builds; and whether the hook's own list is derived, which it cannot be, being the authority"
  teardown
}

# =============================================================================
# CASE — THE ALREADY-LIVED PROBE HAS ONE AUTHORING SITE, ASSERTED AS AN EFFECT.
#
# "check-board.sh sources lib/lived-probe.sh" is a LABEL, and it is satisfied by a
# script that sources the file and then goes on using its own inline copy. Nothing
# below asserts it. What cannot be faked: add a fifth signal to the LIBRARY and BOTH
# consumers must see it — the initializer must refuse and NAME it, and arm [g] must RUN
# and name it as its enabling condition. A consumer still carrying an inline copy sees
# nothing and fails here, naming itself.
#
# THE THIRD COPY IS THE INSTRUMENT, NOT AN OPERAND. `_lived_signals` is this harness's
# own independent implementation and is deliberately NOT collapsed into the library — a
# fixture that asked the subject under test what to check would agree with it by
# construction. It is used here only to establish the PRE-STATE.
# =============================================================================
case_lived_probe_has_one_authoring_site() {
  cf_reset
  if ! has_kit_init; then skp "lived probe: one authoring site, both consumers" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "lived probe: one authoring site, both consumers" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox

  local lib="$SB_WORK/scripts/lib/lived-probe.sh"
  [ -f "$lib" ] \
    || _fixture_die "case_lived_probe_has_one_authoring_site: the sandbox has no scripts/lib/lived-probe.sh — there is no shared library to mutate, so nothing here can distinguish one authoring site from two."

  # A token that occurs NOWHERE in the shipped scripts, so a match below cannot come from
  # anything but the plant. NO trailing -<digits>: build-kit.sh's citation gate reads that
  # as one of the kit repository's change ids and refuses the zip, and this file ships.
  local tok='LIVEDPROBE-FIFTH-SIGNAL-SENTINEL'
  # SWEPT OVER THE SANDBOX'S SCRIPTS, AND NOT OVER $REAL_SCRIPTS — which was the first
  # spelling and it died instantly, correctly: $REAL_SCRIPTS contains THIS FILE, and this
  # file contains the token on the line above. A uniqueness probe whose corpus includes
  # its own source always finds itself. Excluding test/ keeps the corpus to the scripts
  # the two consumers actually load.
  [ -z "$( { find "$SB_WORK/scripts" -type f ! -path '*/test/*' -exec grep -lF "$tok" {} + 2>/dev/null || true; } )" ] \
    || _fixture_die "case_lived_probe_has_one_authoring_site: '$tok' already occurs in a sandbox script — every assertion below would be satisfiable without the plant."

  # PRE-STATE, BOTH DIRECTIONS. Without these the case passes on a signal the sandbox
  # already carried and proves nothing about the library.
  publish_sandbox
  local sig pre
  sig="$(_lived_signals)"
  [ -z "$sig" ] \
    || _fixture_die "case_lived_probe_has_one_authoring_site: the sandbox already carries lived signal(s) — $(printf '%s' "$sig" | tr '\n' ';') — so kit-init would refuse and arm [g] would run whatever the plant did."
  pre="$(cb_run)"
  printf '%s\n' "$pre" | _cb_g_section | grep 'THIS CHECK DID NOT RUN' >/dev/null \
    || _fixture_die "case_lived_probe_has_one_authoring_site: arm [g] ALREADY runs on the unplanted sandbox, so the 'it ran' assertion below would pass without the fifth signal."

  # THE PLANT — one probe, in the LIBRARY only, emitting a record shape both consumers
  # already render. Every step self-asserts: a perl -i whose anchor misses exits 0 and
  # leaves the file byte-identical, which would make this case green about nothing.
  _plant_in_function "$lib" kit_lived_signals "  printf 'folder|$tok|1\n'" \
    "case_lived_probe_has_one_authoring_site"
  bash -n "$lib" \
    || _fixture_die "case_lived_probe_has_one_authoring_site: the mutated lived-probe.sh no longer parses — both consumers would fail to LOAD it, and this case would be measuring a load failure while reporting on a shared probe."
  # PUBLISH AFTER THE MUTATION, and this is not tidiness: kit-init refuses on uncommitted
  # changes to TRACKED files, so an unpublished plant replaces the refusal this case reads
  # with a completely different one.
  publish_sandbox

  local out rc=0 before after out2
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix ZZZ --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -ne 0 ] \
    || cf "(initializer) kit-init did not refuse on a signal the shared probe emits — it is not deriving already-lived from the library: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s\n' "$out" | grep 'already lived' >/dev/null \
    || cf "(initializer) kit-init refused without naming the already-lived class: $(printf '%s' "$out" | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F "$tok" >/dev/null \
    || cf "(initializer) the refusal did not name the library's fifth signal — kit-init still carries its own inline copy of the probe: $(printf '%s' "$out" | tr '\n' '|')"
  after="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "HEAD moved during a refusal"

  out2="$(cb_run)"
  printf '%s\n' "$out2" | grep '^\[g\]' >/dev/null \
    || cf "no [g] section — the arm is absent, which no other assertion here can detect"
  printf '%s\n' "$out2" | _cb_g_section | grep 'THIS CHECK DID NOT RUN' >/dev/null \
    && cf "(arm) arm [g] did not run on a signal the shared probe emits — it still re-derives the set itself: $out2"
  printf '%s\n' "$out2" | _cb_g_section | grep -F "$tok" >/dev/null \
    || cf "(arm) arm [g] ran but did not name the library's fifth signal as its enabling condition — the two consumers are not reading one probe: $out2"

  finish "lived probe: a fifth signal added to scripts/lib/lived-probe.sh reaches BOTH consumers — kit-init refuses naming it, arm [g] is enabled by it (one authoring site, asserted as an effect)"
  teardown
}

case_kit_init_refuses_lived_board() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: refuses a repo that has already lived" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: refuses a repo that has already lived" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  seed_issue todo SBX-500 lived chore "A card already on the board"
  publish_sandbox

  local before out rc after
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix ZZZ --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "kit-init ran against a board carrying an issue file (it must refuse)"
  printf '%s\n' "$out" | grep 'already lived' >/dev/null || cf "the refusal did not name the class: $out"
  printf '%s\n' "$out" | grep 'NOTHING WAS WRITTEN' >/dev/null || cf "the refusal did not state that nothing was written"
  # THE REFUSAL MUST BE FOR THE RIGHT REASON. kit-init has four ALREADY-LIVED
  # signals (a board carrying issue files, a progress.md § Log with entries, an
  # ARCHIVE.md with entries, and its own stamp receipt in config.sh) and `grep -q
  # 'already lived'` is satisfied by ANY of them. This case plants exactly one — the
  # issue file — so it must assert THAT bullet and the ABSENCE of the stamp bullet.
  # Before the sandbox was neutralized, a configured adopter's copied-in config.sh
  # carried kit-init's stamp, so this case passed on the WRONG signal in their tree
  # and nothing said so. Neutralizing removes the stamp; without these two lines it
  # would only convert a measured wrong-reason pass into an unmeasured one.
  printf '%s\n' "$out" | grep 'progress/todo/ carries 1 issue file' >/dev/null \
    || cf "the refusal did not name the planted issue file as the lived signal — it may have refused for a different reason: $out"
  printf '%s\n' "$out" | grep "$KIT_STAMP_MARK" >/dev/null \
    && cf "the refusal cited kit-init's own stamp receipt as a lived signal — the sandbox was not neutralized, so this case is measuring the wrong signal: $out"
  after="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "HEAD moved during a refusal"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "the tree was modified during a refusal"
  grep -q 'ISSUE_PREFIX:-ZZZ' "$SB_WORK/scripts/config.sh" && cf "config.sh was stamped during a refusal"

  finish "kit-init: refuses a repo that has already lived, and writes nothing"
  teardown
}

# =============================================================================
# CASE — kit-init.sh --project-name refuses what it cannot stamp, and ONLY that.
#
# THE INCIDENT, and it was found by use rather than by review. An adopted project
# ran the initializer with an ordinary place name carrying an apostrophe. The
# stamping and the board creation both reported CLEAN; the self-check then failed
# with "could not mint" and no cause. The stamped line was
#     PROJECT_NAME="${PROJECT_NAME:-The Old Bell's Rota}"
# and bash still processes quoting inside the `word` of a `${VAR:-word}` even when
# the whole expansion is double-quoted, so the apostrophe opened a single-quoted
# string that ran to end of file. config.sh was unsourceable and EVERY script that
# reads it died. The repair was by hand, outside the tool that made the mess.
#
# WHAT THIS CASE ASSERTS, and the second half is the one that matters. A refusal is
# cheap to write and easy to write too wide: a --project-name arm that rejected
# everything unfamiliar would pass a positive-only case while making the flag
# useless. So the NEGATIVE control runs a full init with an ordinary two-word name
# and requires it to stamp, mint and self-check green. Without it this case cannot
# tell a narrow refusal from a blanket one.
#
# THE REFUSED SET IS RE-DERIVED HERE BY EXECUTION, NOT READ OFF THE COMMENT IN
# kit-init.sh. Each candidate character is stamped through the REAL substitution
# expression — read out of kit-init.sh rather than retyped — and the result is both
# parsed and sourced back. A character is hostile if it leaves config.sh unparseable
# OR if the value that comes back out differs from the value that went in. The
# validator must refuse every character this derivation calls hostile, and must NOT
# refuse one it calls safe. A hand-listed set is a claim; this is a measurement, and
# it is the reason a character nobody thought of cannot quietly stay accepted.
# =============================================================================
case_kit_init_project_name_refusal() {
  cf_reset
  if ! has_kit_init; then skp "kit-init --project-name: refuses what it cannot stamp" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init --project-name: refuses what it cannot stamp" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local out rc before after

  # --- (a) THE DERIVATION. Re-measure which characters are hostile, using the real
  # stamping expression lifted out of kit-init.sh so a change to that line is felt here.
  local stamp_sed probe hostile safe got line
  stamp_sed="$(grep -m1 -F 's|^PROJECT_NAME=.*|PROJECT_NAME=' "$SB_WORK/scripts/kit-init.sh")"
  [ -n "$stamp_sed" ] \
    || _fixture_die "case_kit_init_project_name_refusal: could not find the PROJECT_NAME stamping line in kit-init.sh — the derivation below would measure nothing and the case would pass vacuously."
  probe="$SB_TMP/pn-probe"; mkdir -p "$probe"
  hostile=""; safe=""
  local code c nn
  for code in 32 34 36 38 39 92 96 124 125 45 46 97 65 48 44 40; do
    c="$(printf "\\$(printf '%03o' "$code")")"
    nn="A${c}B"
    printf 'PROJECT_NAME="${PROJECT_NAME:-<project-name>}"\nX=1\n' > "$probe/config.sh"
    if ! sed -i.bak -e "s|^PROJECT_NAME=.*|PROJECT_NAME=\"\${PROJECT_NAME:-${nn}}\"|" "$probe/config.sh" 2>/dev/null; then
      hostile="$hostile$c"; continue          # the substitution itself aborted
    fi
    if ! bash -n "$probe/config.sh" 2>/dev/null; then
      hostile="$hostile$c"; continue          # config.sh is no longer sourceable
    fi
    got="$( ( unset PROJECT_NAME; . "$probe/config.sh" >/dev/null 2>&1; printf '%s' "${PROJECT_NAME:-}" ) )"
    if [ "$got" = "$nn" ]; then safe="$safe$c"; else hostile="$hostile$c"; fi
  done
  [ -n "$hostile" ] \
    || _fixture_die "case_kit_init_project_name_refusal: the derivation found NO hostile character among its candidates — the probe is broken, and every assertion below would be vacuous."
  [ -n "$safe" ] \
    || _fixture_die "case_kit_init_project_name_refusal: the derivation found NO safe character — the probe is broken, and the narrowness assertion below would be vacuous."

  # --- (b) the validator agrees with the derivation, character for character.
  # It is run OUT OF THE SHIPPED SCRIPT, never a copy: a paraphrase here would stay
  # green through any edit to the real function.
  local vfn
  vfn="$(sed -n '/^validate_project_name() {$/,/^}$/p' "$SB_WORK/scripts/kit-init.sh")"
  [ -n "$vfn" ] \
    || cf "kit-init.sh declares no validate_project_name() — --project-name is unvalidated again"
  if [ -n "$vfn" ]; then
    local i n
    n="${#hostile}"; i=1
    while [ "$i" -le "$n" ]; do
      c="${hostile:$((i-1)):1}"
      if ( eval "$vfn"; validate_project_name "A${c}B" ) >/dev/null 2>&1; then
        cf "validate_project_name ACCEPTS '$c', which the derivation just measured as hostile (it breaks or corrupts the stamped config.sh)"
      fi
      i=$(( i + 1 ))
    done
    n="${#safe}"; i=1
    while [ "$i" -le "$n" ]; do
      c="${safe:$((i-1)):1}"
      if ! ( eval "$vfn"; validate_project_name "A${c}B" ) >/dev/null 2>&1; then
        cf "validate_project_name REFUSES '$c', which the derivation just measured as safe — the refusal is wider than the defect"
      fi
      i=$(( i + 1 ))
    done
    ( eval "$vfn"; validate_project_name "A
B" ) >/dev/null 2>&1 \
      && cf "validate_project_name accepts an embedded newline, which aborts the substitution"
  fi

  # --- (c) THE POSITIVE. The real invocation, with the real name that found this.
  local hostile_name hn_pre expect_pos _sq
  _sq="'"                       # one apostrophe, held in a variable so no line below has to
                                # escape it inside a double-quoted string — the escaping idiom
                                # for a single-quoted context ends the string early here, and
                                # the name arrived EMPTY, which the premise check caught.
  hostile_name="The Old Bell${_sq}s Rota"
  # DERIVED, not typed: the expected column is computed from the name above, so changing
  # the name cannot leave a stale digit here asserting the wrong column. The derivation is
  # then CHECKED against the name — an arithmetic slip would otherwise hand the assertion
  # below a plausible-looking wrong number and it would fail for a reason nobody could read.
  hn_pre="${hostile_name%%${_sq}*}"
  expect_pos=$(( ${#hn_pre} + 1 ))
  [ "${hostile_name:$((expect_pos-1)):1}" = "$_sq" ] \
    || _fixture_die "case_kit_init_project_name_refusal: the derived apostrophe position ($expect_pos) does not point at an apostrophe in '$hostile_name' — the POSITION assertion below would compare against the wrong column."
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --project-name "$hostile_name" 2>&1)"; rc=$?
  [ "$rc" -eq 2 ] || cf "--project-name with an apostrophe exited $rc; an illegal invocation is exit 2 (process/contracts/issue-creation.md § 3): $out"
  printf '%s\n' "$out" | grep -F 'apostrophe' >/dev/null \
    || cf "the refusal did not NAME the offending character: $out"
  printf '%s\n' "$out" | grep -F "position $expect_pos" >/dev/null \
    || cf "the refusal did not name the offending character's POSITION (expected position $expect_pos): $out"
  # It refused BEFORE writing, which is the whole point of doing it at parse time.
  after="$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$before" = "$after" ] || cf "HEAD moved during a --project-name refusal"
  [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "the tree was modified during a --project-name refusal"
  grep -q 'ISSUE_PREFIX:-SBX' "$SB_WORK/scripts/config.sh" \
    && cf "config.sh was stamped during a --project-name refusal — it refused too late"

  # --- (d) THE NEGATIVE, and it is the one that proves the refusal is narrow.
  # An ordinary name — spaces and letters, nothing exotic — must initialize, stamp and
  # mint exactly as the unflagged happy path does.
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --project-name "The Old Bell Rota" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "a --project-name with no hostile character was REFUSED (exit $rc) — the refusal is a blanket one: $out"
  printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null \
    || cf "the clean --project-name run did not reach COMPLETE and PROVEN: $out"
  printf '%s\n' "$out" | grep '✗' >/dev/null && cf "a self-check assertion failed on the clean --project-name run: $out"
  printf '%s\n' "$out" | grep "id: SBX-000" >/dev/null \
    || cf "the clean --project-name run did not mint the scratch card: $out"
  # The name actually landed, and config.sh still sources.
  grep -qF 'PROJECT_NAME:-The Old Bell Rota' "$SB_WORK/scripts/config.sh" \
    || cf "the clean --project-name was not stamped into scripts/config.sh"
  bash -n "$SB_WORK/scripts/config.sh" \
    || cf "scripts/config.sh does not parse after a clean --project-name run"
  got="$( ( unset PROJECT_NAME; . "$SB_WORK/scripts/config.sh" >/dev/null 2>&1; printf '%s' "${PROJECT_NAME:-}" ) )"
  [ "$got" = "The Old Bell Rota" ] \
    || cf "sourcing the stamped config.sh yields PROJECT_NAME='$got', not the name that was asked for"

  finish "kit-init --project-name: refuses every character measured hostile, accepts every one measured safe, and a clean name still initializes and mints"
  teardown
}

# =============================================================================
# CASE — kit-init.sh --gate-command against the SHIPPED FRAME.
# The incident (measured 2026-08-26, from the seed's own zip): the seed ships
# verify.sh as a frame with an EMPTY table that refuses to run; --gate-command
# refused because verify.sh existed; the frame's header told the reader to run the
# flag that refused; the README's day-one command was that flag. Three documents,
# no working path. The flag now FILLS the empty table; this case keeps that true.
# =============================================================================
case_kit_init_gate_fill() {
  cf_reset
  if ! has_kit_init; then skp "kit-init --gate-command: fills the shipped frame's empty table" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init --gate-command: fills the shipped frame's empty table" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  # Ship-state: empty the GATES table again — make_sandbox neutralized it and then
  # _declare_sandbox_gate put the sandbox's own gate back, and THIS case is about
  # kit-init filling an EMPTY frame. Through the shared, self-asserting helper: this
  # step used to be a local `perl -i -ne` that silently did nothing if `^GATES=($`
  # ever moved, which would have left the record make_sandbox declared in place and
  # turned the "fills the empty table" assertion into a test of the refusal path.
  _neu_array "$SB_WORK/scripts/verify.sh" GATES
  publish_sandbox

  local v="$SB_WORK/scripts/verify.sh" out rc
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --gate-command '/bin/echo kit-init-gate-green' 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc with --gate-command against the empty frame: $out"
  printf '%s\n' "$out" | grep 'kit-init COMPLETE and PROVEN' >/dev/null || cf "no COMPLETE-and-PROVEN line: $out"
  printf '%s\n' "$out" | grep 'GATES table was empty — filled' >/dev/null || cf "kit-init did not report filling the table: $out"
  grep -qF '"gate|core|/bin/echo kit-init-gate-green"' "$v" || cf "the record did not land in verify.sh"
  grep -q '^GATES=($' "$v" || cf "the frame's GATES=( line is gone — the fill rewrote more than one line"
  [ -x "$v" ] || cf "verify.sh lost its executable bit"
  # The filled runner RUNS, and is green — the first landing has a gate to pass.
  out="$( cd "$SB_WORK" && "$v" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "the filled verify.sh exited $rc: $out"
  printf '%s' "$out" | grep 'kit-init-gate-green' >/dev/null || cf "the filled verify.sh did not run the declared command: $out"
  printf '%s' "$out" | grep 'PASS  gate' >/dev/null || cf "the summary does not name the filled gate: $out"
  out="$( cd "$SB_WORK" && "$v" --list 2>&1 )"; rc=$?
  printf '%s' "$out" | grep '1 declared gate' >/dev/null || cf "--list does not report one declared gate: $out"
  # ...and the filled file reached the trunk with the initialization commit.
  origin_file_contains "scripts/verify.sh" 'gate|core|/bin/echo kit-init-gate-green' \
    || cf "the filled verify.sh was not pushed to the trunk"

  finish "kit-init --gate-command: fills the shipped frame's empty GATES table, the runner runs green, --list counts it, and it reaches the trunk"
  teardown
}

case_kit_init_gate_and_remote_refusals() {
  cf_reset
  if ! has_kit_init; then skp "kit-init: refuses a declared table, a '|' in the gate command, and a relative remote URL" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "kit-init: refuses a declared table, a pipe in the gate command, and a relative remote" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox            # make_sandbox already DECLARED one gate in verify.sh
  publish_sandbox
  local before out rc
  before="$(git -C "$SB_WORK" rev-parse HEAD)"
  refused_clean() {  # <label> <rc> <out> <needle>
    [ "$2" -ne 0 ] || cf "$1: did not refuse"
    printf '%s\n' "$3" | grep 'NOTHING WAS WRITTEN' >/dev/null || cf "$1: the refusal did not state that nothing was written"
    printf '%s\n' "$3" | grep "$4" >/dev/null || cf "$1: the refusal did not name the cause ($4): $3"
    [ "$(git -C "$SB_WORK" rev-parse HEAD)" = "$before" ] || cf "$1: HEAD moved during a refusal"
    [ -z "$(git -C "$SB_WORK" status --porcelain)" ] || cf "$1: the tree was modified during a refusal"
  }
  # (a) a DECLARED table is never overwritten or appended to.
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --gate-command '/bin/echo x' 2>&1)"; rc=$?
  refused_clean "(a) declared table" "$rc" "$out" 'already DECLARES a gate'
  grep -qF '/bin/echo x' "$SB_WORK/scripts/verify.sh" && cf "(a) the record was appended to a declared table"
  # (b) a '|' cannot be carried by the record format.
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" --gate-command 'a | b' 2>&1)"; rc=$?
  refused_clean "(b) '|' in the command" "$rc" "$out" "contains '|'"
  # (c) a RELATIVE remote URL resolves differently from .kanban-wt/ — refuse at preflight.
  git -C "$SB_WORK" remote set-url origin "../$(basename "$SB_ORIGIN")" >/dev/null 2>&1
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  refused_clean "(c) relative remote URL" "$rc" "$out" 'RELATIVE path'
  printf '%s\n' "$out" | grep 'remote set-url' >/dev/null || cf "(c) the refusal did not print the set-url fix: $out"

  finish "kit-init: refuses --gate-command against a declared table (never appends), a '|' in the command, and a relative remote URL — writing nothing each time"
  teardown
}

# =============================================================================
# CASE — OPTION-PARSING HYGIENE across the argument-taking scripts.
# The incident: a creation script consumed `--help` as the item's slug, minted an
# item under a nonsense name, burned a real id, and printed "Created:" — an
# acceptance WITH a success message, which is why "it looked right" is exactly the
# evidence that failed. Three behaviours × six scripts, each with its exit code
# asserted:
#   • a leading '-' is NEVER a name           → refuse, rc=2
#   • -h/--help                                → usage, rc=0
#   • an unknown option                        → refuse, rc=2
# =============================================================================
case_option_parsing_hygiene() {
  cf_reset
  if ! has_issue_template; then skp "option parsing across the creation and board scripts" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # THE CAPABILITY PROBE GUARDS THE CASE, NOT JUST THE COPY. It used to guard only
  # the `cp` below, so when .claude/templates was absent the case ran anyway
  # against a sandbox with no templates — and every creation script then exited 1
  # at its own "template not found" check, which sits BEFORE its argument loop. The
  # case reported `an unknown option refuses → rc=1 (want 2)` on scripts whose
  # unknown-option path is a correct `exit 2`. A FALSE RED, and a durable one: it
  # names the subject and the wrong verdict, so it reads exactly like a real defect
  # in three scripts at once. Measured 2026-08-26.
  #
  # A SKIP is a statement about the environment; a FAIL is a statement about the
  # subject. This case could not tell them apart, which is the same lesson the kit
  # carries for its own gate runner (a runner reports on its subject and on itself
  # in different vocabularies). Its three siblings — kit-init happy, gate-fill and
  # first-mile — already probe this exact capability and skip loudly; this one is
  # brought into line with them.
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    skp "option parsing across the creation and board scripts" ".claude/templates absent — the creation scripts would exit 1 at their template check, before the argument loop this case is about"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  # The second site that copies the real .claude/ tree in, so the second caller of
  # the neutralizer. This case does not assert on the template BODY, so nothing
  # here reddens without it today — it is called because the rule is "every site
  # that copies .claude/ in", and a rule with one remembered site and one forgotten
  # one is how the template-seam defect above survived two rounds of fixing.
  _kit_neutral_claude
  publish_sandbox

  local out rc
  _opt() {  # <expected-rc> <label> <script> <args…>
    local want="$1" label="$2"; shift 2
    local s="$1"; shift
    out="$(cd "$SB_WORK" && "$SB_WORK/scripts/$s" "$@" 2>&1)"; rc=$?
    [ "$rc" = "$want" ] || cf "$s: $label → rc=$rc (want $want)"
  }

  local s
  for s in new-issue.sh new-bug.sh new-refactor.sh new-prd.sh; do
    _opt 0 "--help prints usage and SUCCEEDS"      "$s" --help
    _opt 2 "a leading '-' is never a <slug>"       "$s" --id
    _opt 2 "an unknown option refuses"             "$s" someslug --bogus x
  done
  # THE VALUE-TAKING OPTIONS, which the loop above never reaches. Two shapes, both
  # previously unguarded: an option whose value is outside its declared enum, and an
  # option given as the LAST argument with no value at all — that one used to trip
  # `set -u` on a bare $2 and die with "$2: unbound variable", non-zero only by
  # accident of the shell and naming a positional rather than the flag.
  _opt 1 "--severity refuses a value outside its enum"  new-bug.sh sl --id "$SB_PREFIX-901" --severity nonsense
  _opt 2 "a value-taking option with NO value refuses, naming it" new-bug.sh sl --id "$SB_PREFIX-902" --severity
  _opt 2 "the same, on a sibling's flag"                new-refactor.sh sl --id "$SB_PREFIX-903" --target
  printf '%s' "$out" | grep -- '--target requires a value' >/dev/null \
    || cf "the no-value refusal did not name the option: $out"

  _opt 0 "--help prints usage and SUCCEEDS"        subtask.sh --help
  _opt 2 "a leading '-' is never a positional"     subtask.sh new --help s1 slug
  _opt 2 "an unknown option refuses"               subtask.sh new "$SB_PREFIX-999" s1 slug --bogus x
  _opt 0 "--help prints usage and SUCCEEDS"        finish-pr.sh --help
  _opt 2 "a leading '-' is never an issue id"      finish-pr.sh --note x
  _opt 2 "an unknown option refuses"               finish-pr.sh "$SB_PREFIX-999" --bogus x

  # The real damage: the refusals must have created NOTHING. A refusal that
  # already wrote the file is the bug, not the fix.
  local minted
  minted="$(find "$SB_WORK/progress" "$SB_WORK/requirements" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$minted" = "0" ] || cf "$minted item(s) were created by refused invocations"

  finish "option parsing across the creation and board scripts: a leading '-' is never a name, --help rc=0, an unknown option rc=2, a value outside a declared enum refuses, a value-taking option with no value refuses NAMING ITSELF rather than dying on an unbound positional, and no refusal creates anything"
  teardown
}

# =============================================================================
# CASE — THE SHORT NAME'S SHAPE BINDS EVERY CREATOR, INCLUDING THE TWO THAT SKIPPED IT.
#
# `validate_slug` implements process/contracts/issue-creation.md § 5 and three creators
# called it. `new-prd.sh` did not, and `subtask.sh` did not even source config.sh.
#
# THE TWO HALVES ARE NOT EQUALLY SERIOUS AND THE CASE SAYS SO. For new-prd.sh the
# damage is a shell-hostile filename and a burned id — annoying, contained. For
# subtask.sh it is a FUNCTIONAL BREAK: its create arm writes `branch: feature/<ID>-<SLUG>`
# into a card it PUBLISHES, and the role docs tell Dev and QA to `git switch` that value.
# Measured: a slug with a space makes `git check-ref-format` refuse and `git switch -c`
# exit 128 — so the trunk carries a card naming a branch nobody can check out.
#
# THE SUFFIX IS CHECKED TOO, and leaving it out would have been a false claim of
# closure: it reaches the same filename and the same ref by the same concatenation, and
# the `move` arm recovers the parent with ${ID%-s*}, so a suffix that is not s<digits>
# resolves to the WRONG PARENT rather than failing.
# =============================================================================
case_creation_slug_shape_is_one_rule() {
  cf_reset
  if ! has_issue_template; then skp "the short name's shape binds every creator" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ] || [ ! -f "$REAL_REPO_ROOT/.claude/templates/SUBTASK.template.md" ]; then
    skp "the short name's shape binds every creator" ".claude/templates (or SUBTASK.template.md) absent — the creators exit before the short name is read"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  seed_issue todo "$SB_PREFIX-014" parent chore "Decomposition parent"
  publish_sandbox

  local bad='Bad_Slug Name' out rc=0

  # (1) new-prd.sh — the EFFECT: requirements/ untouched, so PRD-001 is not burned.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh "$bad" 2>&1 )" || rc=$?
  [ "$rc" -eq 2 ] || cf "new-prd.sh: a short name with a space and an underscore → rc=$rc (want 2): $(printf '%s' "$out" | tr '\n' '|')"
  [ -z "$(find "$SB_WORK/requirements" -name '*.md' 2>/dev/null)" ] \
    || cf "new-prd.sh WROTE a file for a refused short name — the id is burned: $(ls -1 "$SB_WORK/requirements")"
  printf '%s' "$out" | grep 'position' >/dev/null \
    || cf "new-prd.sh's refusal does not name the offending position: $(printf '%s' "$out" | tr '\n' '|')"

  # (2) subtask.sh — the EFFECT on the TRUNK, which is where its create arm publishes.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s1 "$bad" --title ok 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "subtask.sh new: exited 0 on a short name git itself refuses as a ref"
  origin_has_path "progress/subtasks/$SB_PREFIX-014/todo/$SB_PREFIX-014-s1-$bad.md" \
    && cf "subtask.sh PUBLISHED a card whose filename carries a space and whose branch: is not a legal git ref"
  # THE REFUSAL MUST PRECEDE THE LOCK, not merely the commit — a refusal that reached
  # kwt_bootstrap leaves the shared worktree behind for the next lane.
  [ -e "$SB_WORK/.kanban-wt" ] \
    && cf "subtask.sh reached kwt_bootstrap before refusing the short name — the refusal is not pre-mutation"

  # (3) THE SUFFIX, same arm. Without this the case would ship "the slug is validated"
  #     while the other half of the same concatenation is still open.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" 'a b' legal-name --title ok 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "subtask.sh new: exited 0 on a SUFFIX that is not s<digits> — it reaches the filename and the branch name the same way the slug does"

  # (4) THE VALUE IS ECHOED, NOT REWRITTEN INTO LEGALITY (§ 5, and config.sh's reason).
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh "$bad" 2>&1 )" || rc=$?
  printf '%s' "$out" | grep -F -- "$bad" >/dev/null \
    || cf "the refusal does not echo the name that was typed: $(printf '%s' "$out" | tr '\n' '|')"

  # ── INSTRUMENT CHECK. Everything above is "non-zero and nothing landed", which a
  #    creator broken for ANY reason satisfies. The SAME invocations with a LEGAL short
  #    name must both succeed and both land.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh legal-name 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) new-prd.sh rejected a LEGAL short name (rc=$rc) — this case cannot tell a slug refusal from a broken script: $(printf '%s' "$out" | tr '\n' '|')"
  [ -n "$(find "$SB_WORK/requirements" -name '*legal-name*' 2>/dev/null)" ] \
    || cf "(control) new-prd.sh minted nothing for a legal name — the refusals above prove nothing"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s1 legal-name --title ok 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "(control) subtask.sh new rejected a LEGAL short name and suffix (rc=$rc): $(printf '%s' "$out" | tr '\n' '|')"
  origin_has_path "progress/subtasks/$SB_PREFIX-014/todo/$SB_PREFIX-014-s1-legal-name.md" \
    || cf "(control) subtask.sh published nothing for a legal name — the 'did not publish' probe above is vacuous"

  finish "the short name's shape binds every creator: new-prd.sh and subtask.sh refuse a name (or a suffix) outside § 5 BEFORE minting or locking, echo what was typed rather than rewriting it, burn no id and publish nothing — and both still mint normally on legal input"
  teardown
}

case_creation_scripts_substitute_hostile_values() {
  cf_reset
  if ! has_issue_template; then skp "creation scripts substitute hostile values without executing them" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  # WHAT THE OPTION-PARSING CASE ABOVE CANNOT SEE. It exercises REFUSALS, so every
  # invocation it makes stops before the substitution block. Nothing covered the
  # SUCCESS path's substitution, and that is where the damage lived: each value is
  # interpolated into a `s|…|REPL|` expression, where `|` ends the expression, `&`
  # means "the whole match" and `\` escapes. A --prd of `a|b` aborted sed mid-run;
  # a value containing `&` was silently corrupted into the card.
  #
  # AND THE ABORT WAS THE WORSE HALF: the card was copied onto the board BEFORE the
  # substitutions ran, so the failure left a half-filled card and its .bak sitting in
  # progress/todo/ with the template's placeholder id — an id burned by an invocation
  # that reported failure. The contract's own words: a refusal that already wrote the
  # file is the bug.
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ] || [ ! -f "$REAL_REPO_ROOT/.claude/templates/SUBTASK.template.md" ]; then
    skp "creation scripts substitute hostile values" ".claude/templates (or SUBTASK.template.md) absent — the creation scripts exit before their substitution block"
    return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  seed_issue todo "$SB_PREFIX-014" parent chore "Decomposition parent"
  publish_sandbox

  local out rc card
  # A pipe: the delimiter itself.
  out="$( cd "$SB_WORK" && ./scripts/new-issue.sh piped --id "$SB_PREFIX-910" --prd 'a|b' 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a --prd containing the sed delimiter did not succeed: rc=$rc $out"
  card="$SB_WORK/progress/todo/$SB_PREFIX-910-piped.md"
  [ -f "$card" ] || cf "the card was not created for a piped --prd"
  grep -q '^prd: a|b$' "$card" 2>/dev/null \
    || cf "the piped value did not land verbatim: $(grep '^prd:' "$card" 2>/dev/null)"

  # An ampersand: sed's "whole match" metacharacter.
  out="$( cd "$SB_WORK" && ./scripts/new-refactor.sh amped --id "$SB_PREFIX-911" --target 'a & b' 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "a --target containing '&' did not succeed: rc=$rc $out"
  card="$SB_WORK/progress/todo/$SB_PREFIX-911-amped.md"
  grep -q '^target_module: a & b$' "$card" 2>/dev/null \
    || cf "the '&' value was corrupted rather than written: $(grep '^target_module:' "$card" 2>/dev/null)"

  # NOTHING PARTIAL IS EVER LEFT. The .bak is the tell: it only exists between the
  # first substitution and the cleanup, so one on the board means a card was being
  # edited in place where the operator can see it.
  local strays
  strays="$(find "$SB_WORK/progress" -name '*.bak' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$strays" = "0" ] || cf "$strays .bak file(s) left on the board — the card is being built in place"

  # And a refusal AFTER the id validates still writes nothing.
  local before after
  before="$(find "$SB_WORK/progress" -name '*.md' | wc -l | tr -d ' ')"
  ( cd "$SB_WORK" && ./scripts/new-bug.sh refused --id "$SB_PREFIX-912" --severity nonsense ) >/dev/null 2>&1
  after="$(find "$SB_WORK/progress" -name '*.md' | wc -l | tr -d ' ')"
  [ "$before" = "$after" ] \
    || cf "a refused invocation changed the board: $before → $after item(s)"

  # ── subtask.sh: THE CREATOR THAT TAKES THE MOST FREE TEXT AND NEVER GOT THE FIX.
  #    Its create arm PUBLISHES, so these read the TRUNK, not the checkout — unlike the
  #    arms above, whose creators are inert.
  local st="progress/subtasks/$SB_PREFIX-014/todo"

  # (a) '&' — sed's whole-match metacharacter. The tell is not "the title is wrong": it
  #     is that the frontmatter and the H1 DISAGREE, because only one path was broken.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s1 amped --title 'Fix A & B' 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "subtask.sh new: a --title containing '&' did not succeed: rc=$rc $(printf '%s' "$out" | tr '\n' '|')"
  origin_file_contains "$st/$SB_PREFIX-014-s1-amped.md" '^title: Fix A & B$' \
    || cf "subtask.sh: the '&' title was corrupted rather than written into the published card"
  origin_file_contains "$st/$SB_PREFIX-014-s1-amped.md" "^# $SB_PREFIX-014-s1 — Fix A & B\$" \
    || cf "subtask.sh: the H1 does not carry the '&' title verbatim"

  # (b) A BACKSLASH — a SECOND escaping bug in the same twelve lines that sed_repl does
  #     NOT fix. `awk -v` performs escape processing, so \t became a tab and \n split the
  #     heading. A fix that only escapes the sed passes (a) and fails here.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s4 backsl --title 'path C:\tmp\new' 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "subtask.sh new: a --title containing a backslash did not succeed: rc=$rc"
  origin_file_contains "$st/$SB_PREFIX-014-s4-backsl.md" '^title: path C:\\tmp\\new$' \
    || cf "subtask.sh: a backslash in --title was interpreted rather than kept — the frontmatter value is not literal"
  origin_file_contains "$st/$SB_PREFIX-014-s4-backsl.md" '^# .*path C:\\tmp\\new$' \
    || cf "subtask.sh: the H1 mangled the backslash — 'awk -v' processes escapes; the heading must go through ENVIRON"

  # (c) '|' — THE DELIMITER, and the real damage is not the abort. sed writes via
  #     `> "$DEST"`, so the file exists before sed fails; `reset --hard` does not remove
  #     an untracked file, so the husk BLOCKS the id. The assertion that cannot be faked
  #     is the control below: the SAME id must still be mintable afterwards.
  rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$SB_PREFIX-014" s2 piped --title 'a|b' 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] || cf "subtask.sh new: a --title containing the sed delimiter aborted: rc=$rc $(printf '%s' "$out" | tr '\n' '|')"
  origin_file_contains "$st/$SB_PREFIX-014-s2-piped.md" '^title: a|b$' \
    || cf "subtask.sh: the piped value did not land verbatim in the published card"

  # NO HUSK IN THE SHARED WORKTREE. This is the durable half of the '|' damage and it
  # outlives the failed run: sed's `> "$DEST"` creates the file before sed fails, and
  # `reset --hard` does not remove an untracked file, so a zero-byte card survives in a
  # directory the docs tell operators not to touch and blocks that id.
  #
  # NOTE WHY THIS IS NOT "re-mint the same id and expect success": once the escaping
  # WORKS, the piped run publishes the card, so re-minting that id correctly refuses with
  # "already exists". The first draft of this control asserted the opposite and reddened
  # on the fix. The husk itself is the thing to look for, so look for it.
  local husk
  husk="$( { find "$SB_WORK/.kanban-wt/progress/subtasks" -type f -name '*.md' -size 0 2>/dev/null || true; } )"
  [ -z "$husk" ] \
    || cf "a ZERO-BYTE card was left in the SHARED kanban worktree ($husk) — reset --hard does not remove it, so it blocks that subtask id until someone deletes a file by hand inside .kanban-wt/"

  finish "creation scripts (subtask.sh included): a value carrying sed's delimiter or its whole-match metacharacter lands VERBATIM in the card, no .bak is ever left on the board, and a refusal after id validation creates nothing"
  teardown
}


# =============================================================================
# CASE — THE FIRST MILE, pinned end to end.
#
# Three defects, each independently replicated by a live agent, each fixed by a
# COMPOSITION change rather than a contract change:
#   • the kit-init × next-id composition bug: kit-init's printed recipe embedded
#     $(next-id.sh), which on the board kit-init has just left EMPTY correctly
#     REFUSES. This asserts BOTH halves — the recipe prints the literal first id,
#     AND next-id.sh still refuses on that same empty board. If the second half
#     ever goes green by next-id.sh answering, the fix was applied to the wrong
#     file;
#   • the push-before-you-move trap: creation PRINTS the push step, and the
#     mover's not-found error NAMES the cause. Both proven by running them, in
#     that order;
#   • the false drift-[a] finding: a FRESHLY MINTED card must read clean. The old
#     template's Activity bullet is re-created as an ABLATION CONTROL, because a
#     clean assertion with a dead comparator proves nothing.
# =============================================================================
case_first_mile() {
  cf_reset
  if ! has_kit_init; then skp "first mile: kit-init → mint → push → move → drift-clean" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "first mile: kit-init → mint → push → move → drift-clean" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local out rc f
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "kit-init exited $rc: $out"

  # The COMPOSITION: the printed recipe names the literal first id…
  printf '%s\n' "$out" | grep -- '--id SBX-001' >/dev/null \
    || cf "the printed next-step recipe does not name the literal first id 'SBX-001': $out"
  # …and it no longer offers next-id.sh for the FIRST mint.
  printf '%s\n' "$out" | grep 'next-id.sh' | grep -i 'after the first\|refuses' >/dev/null \
    || cf "next-id.sh is still offered without the after-the-first qualification: $out"

  # The CONTRACT is untouched: next-id.sh still refuses on the empty board.
  local nid_err nid_rc
  nid_err="$(cd "$SB_WORK" && "$SB_WORK/scripts/next-id.sh" 2>&1 1>/dev/null)"; nid_rc=$?
  [ "$nid_rc" -ne 0 ] || cf "next-id.sh answered on an EMPTY board — the id-minting refusal was weakened"
  printf '%s' "$nid_err" | grep -i 'no existing' >/dev/null || cf "next-id.sh's refusal lost its explanation: $nid_err"

  # Follow the printed recipe VERBATIM: the first issue mints.
  out="$(cd "$SB_WORK" && "$SB_WORK/scripts/new-issue.sh" first-mile --id SBX-001 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the printed first-mint recipe failed (rc=$rc): $out"
  f="$SB_WORK/progress/todo/SBX-001-first-mile.md"
  [ -f "$f" ] || cf "the printed recipe did not create progress/todo/SBX-001-first-mile.md"
  printf '%s\n' "$out" | grep 'PUSH IT BEFORE YOU MOVE IT' >/dev/null \
    || cf "new-issue.sh does not print the push-before-you-move step: $out"

  # The mover's not-found error NAMES the cause.
  out="$(cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" SBX-001 in_progress --role PM --note x 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "the mover moved a card that was never pushed"
  printf '%s\n' "$out" | grep 'no file matching' >/dev/null || cf "the mover's error changed shape: $out"
  printf '%s\n' "$out" | grep -i 'not yet pushed' >/dev/null \
    || cf "the not-found error does not name 'minted but not yet pushed?': $out"
  # THE COSTS-NOTHING ASSERTION DOES NOT BELONG HERE, and the reason is measured
  # rather than argued (2026-08-28). It was authored for this spot as
  # "it must not have bootstrapped a worktree … in a repo that had none". This repo
  # HAS one by the time this line runs: kit-init's own self-check moves a scratch card
  # through two columns a few lines above, and each move legitimately bootstraps
  # .kanban-wt. Measured at this exact point — before the call kanban=1, after the call
  # kanban=1, and the refusal's provenance line reads "read the TRUNK's board straight
  # out of …", so the probe refused exactly as designed and created nothing. The
  # assertion would therefore have been a FALSE RED over correct behaviour, measuring
  # kit-init's residue instead of the refusal's cost.
  # The property itself is not lost: case_move_issue_probe (a) asserts it where
  # make_sandbox guarantees the premise, and (b) ablation-proves that (a) can fail.

  # Push, then the move composes.
  git -C "$SB_WORK" add "progress/todo/SBX-001-first-mile.md" >/dev/null 2>&1
  git -C "$SB_WORK" commit -qm "[PM] SBX-001: mint" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  # A freshly minted card produces NO drift-[a] finding.
  cb_a() { CLAUDE_PROJECT_DIR="$SB_WORK" "$SB_WORK/scripts/check-board.sh" 2>&1 \
             | awk '/^\[a\]/{a=1} a&&/^\[b\]/{exit} a{print}'; }
  out="$(cb_a)"
  printf '%s\n' "$out" | grep '⚠' >/dev/null && cf "a FRESHLY MINTED card produced a drift-[a] finding: $out"
  # ABLATION CONTROL — plant an Activity bullet DECLARING another column and the
  # comparator must fire. Without this, the assertion above is unfalsifiable.
  cp "$f" "$SB_WORK/progress/todo/SBX-002-old-shape.md"
  sed -i.bak 's/^id: SBX-001/id: SBX-002/' "$SB_WORK/progress/todo/SBX-002-old-shape.md"
  rm -f "$SB_WORK/progress/todo/SBX-002-old-shape.md.bak"
  printf -- '- 2026-01-03 [QA] Review — PASS; moved to `qa_complete/`.\n' \
    >> "$SB_WORK/progress/todo/SBX-002-old-shape.md"
  # THE PLANT MUST BE PUBLISHED, because arm [a]'s subject is the TRUNK's board and
  # it reads a named ref. Planted in the working tree only, it is invisible by
  # design and this control would fail for the right reason — which is how it was
  # found: it reddened the moment the arms stopped reading the checkout.
  git -C "$SB_WORK" add "progress/todo/SBX-002-old-shape.md" >/dev/null 2>&1
  git -C "$SB_WORK" commit -qm "[PM] SBX-002: ablation plant" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  out="$(cb_a)"
  printf '%s\n' "$out" | grep 'SBX-002-old-shape.md' >/dev/null \
    || cf "(control) the [a] comparator did NOT fire on a bullet declaring qa_complete — the clean result above proves nothing: $out"
  # Withdraw the plant from the trunk too, so the move below runs against the board
  # the rest of this case describes.
  git -C "$SB_WORK" rm -q "progress/todo/SBX-002-old-shape.md" >/dev/null 2>&1
  git -C "$SB_WORK" commit -qm "[PM] SBX-002: withdraw the ablation plant" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  # And the move itself now composes.
  out="$(cd "$SB_WORK" && "$SB_WORK/scripts/move-issue.sh" SBX-001 in_progress --role PM --note "picked up" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "the move failed after the printed push step (rc=$rc): $out"
  [ -f "$SB_WORK/progress/in_progress/SBX-001-first-mile.md" ] \
    || cf "the card did not land in progress/in_progress/"

  finish "first mile: kit-init prints the literal first id (next-id.sh still refuses), the push step is unmissable, the mover names the cause, a fresh mint is drift-[a] clean (ablation-proven)"
  teardown
}

# =============================================================================
# CASE — A FRESHLY MINTED CARD IS DRIFT-CLEAN ON THE FIRST BOARD CHECK.
#
# Three templates told the author that leaving an example as a bullet would make a
# freshly minted card report false drift. Measured 2026-09-03, that was never true in any
# release: the seed entry is the last bullet either way, and the shape lines are
# un-judgeable to the arm. The wording is corrected — but the PROMISE underneath it is
# real and was never asserted: a card nobody has moved yet must not be reported as drift.
#
# THE PROSE IS NOT WHAT IS TESTED. A text-match over the templates would have pinned the
# false mechanism just as happily as the true one; this asserts the board report.
# =============================================================================
case_minted_card_is_drift_clean() {
  cf_reset
  if ! has_issue_template; then skp "a freshly minted card is drift-clean" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    skp "a freshly minted card is drift-clean" ".claude/templates absent"; return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude

  local creator base card n=0 i=800 victim=""
  for creator in "$SB_WORK"/scripts/new-*.sh; do
    [ -e "$creator" ] || continue
    base="$(basename "$creator")"; i=$((i+1))
    ( cd "$SB_WORK" && "./scripts/$base" "clean$i" --id "$SB_PREFIX-$i" >/dev/null 2>&1 ) || true
    card="$SB_WORK/progress/todo/$SB_PREFIX-$i-clean$i.md"
    [ -f "$card" ] || continue
    n=$((n+1)); [ -z "$victim" ] && victim="$card"
  done
  [ "$n" -ge 3 ] \
    || _fixture_die "case_minted_card_is_drift_clean: only $n card(s) minted — the board would be checked over nothing."
  publish_sandbox

  local out rc=0
  out="$(cb_run)"; rc=$?
  [ "$rc" -eq 0 ] || cf "check-board.sh exited $rc (exit 0 ALWAYS)"
  # INSTRUMENT: arm [a] must have walked a column. "nothing found" over an absent board
  # is the vacuous pass this arm's own header warns about.
  printf '%s\n' "$out" | grep 'no active column exists' >/dev/null \
    && cf "(instrument) arm [a] found no active column — the assertion below is vacuous"
  printf '%s\n' "$out" | grep 'last Activity declares' >/dev/null \
    && cf "a FRESHLY MINTED card reports folder-vs-Activity drift — the templates promise the adopter's first board check is clean: $out"

  # ── ABLATION: the arm must be able to SEE these cards, or the green above is empty.
  #    Rewrite one card's seed bullet to declare a folder it is not in.
  grep -q '^- .*`todo/`' "$victim" \
    || _fixture_die "case_minted_card_is_drift_clean: the seed bullet's shape moved — the plant cannot take and the ablation would prove nothing."
  perl -i -pe 's/`todo\/`/`dev_complete`/ if /^- /' "$victim"
  grep -q '`dev_complete`' "$victim" || _fixture_die "case_minted_card_is_drift_clean: the plant did not take."
  publish_sandbox
  out="$(cb_run)"
  printf '%s\n' "$out" | grep 'last Activity declares' >/dev/null \
    || cf "(ablation) arm [a] did NOT report a card whose last Activity declares a folder it is not in — the clean result above establishes nothing"

  finish "a freshly minted card is drift-clean on the first board check across $n creator(s), and the arm demonstrably sees these cards (ablation-proven)"
  teardown
}

# =============================================================================
# CASE — EVERY MINTED BOARD CARD PROMPTS FOR ITS NOTES DELIVERABLE.
#
# The rule's own standard is "named, or explicitly dismissed, never absent" — and the one
# template for the case the rule calls out BY NAME (a test-only refactor with no
# shipped-surface delta) had no prompt at all. So the author most likely to owe an
# explicit dismissal was the one never asked for it.
#
# IT ASSERTS THE MINTED CARD, NOT THE TEMPLATE, and that is the point: a creator that
# strips the section would pass a template check and fail this one. The card is what the
# author actually receives.
# =============================================================================
case_minted_card_prompts_for_notes() {
  cf_reset
  if ! has_issue_template; then skp "every minted board card prompts for its notes deliverable" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  if [ ! -d "$REAL_REPO_ROOT/.claude/templates" ]; then
    skp "every minted board card prompts for its notes deliverable" ".claude/templates absent"; return
  fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  publish_sandbox

  local creator base out card n=0 i=700
  for creator in "$SB_WORK"/scripts/new-*.sh; do
    [ -e "$creator" ] || continue
    base="$(basename "$creator")"
    i=$((i+1))
    # SLUG AND --id ONLY. Every board creator accepts exactly that, and passing a flag
    # one of them does not know now exits 2 (the CLI shape contract) — so a "helpful"
    # extra flag makes every creator refuse and the loop measures nothing. It did.
    out="$( cd "$SB_WORK" && "./scripts/$base" "probe$i" --id "$SB_PREFIX-$i" 2>&1 )" || true
    # THE PATH IS CONSTRUCTED, not parsed out of the output — the creators do not all
    # print the same "Created:" line, and an output parse that silently matches nothing
    # turns this loop into a pass over zero cards.
    card="$SB_WORK/progress/todo/$SB_PREFIX-$i-probe$i.md"
    # BOARD CARDS ONLY: new-prd.sh writes a requirements document, not a board card, so
    # it mints nothing here and drops out by shape rather than by a name in a list.
    [ -f "$card" ] || continue
    n=$((n+1))
    grep -qi 'notes deliverable' "$card" \
      || cf "$base mints a board card with no notes-deliverable prompt — the rule's standard is 'named, or explicitly dismissed, never absent', and this card cannot meet it"
  done

  [ "$n" -ge 3 ] \
    || _fixture_die "case_minted_card_prompts_for_notes: only $n board card(s) were minted — the loop lost its subject and would report PASS over nothing."

  finish "every minted board card prompts for its notes deliverable ($n creator(s) exercised; new-prd.sh is correctly excluded — it writes a requirements document, not a board card)"
  teardown
}

# =============================================================================
# CASE — THE TEMPLATE HEADER SURVIVES THE STAMP IT DESCRIBES.
#
# Each card template's header explains two substitutions the initializer performs — and
# it used to SPELL BOTH TOKENS OUT, so kit-init rewrote its own explanation. Measured:
# every initialized adopter tree carried, in all five templates, a sentence reading
# "the initializer stamps BOTH <the trunk value> and <the prefix value> in this
# directory today" — a sentence with no referent, shipped since v0.1.0.
#
# PRESENCE OF THE HEADER IS NOT THE PROPERTY. Readability AFTER the stamp is, and only an
# end-to-end kit-init run can see it — which is why no static check caught this.
# =============================================================================
case_template_header_survives_the_stamp() {
  cf_reset
  if ! has_kit_init; then skp "the template header survives the stamp" "scripts/kit-init.sh absent"; return; fi
  if ! has_issue_template; then skp "the template header survives the stamp" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox

  local out rc=0 t base hdr n=0
  out="$("$SB_WORK/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || { cf "kit-init exited $rc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"; finish "the template header survives the stamp"; teardown; return; }

  # ── INSTRUMENT CHECK FIRST. Every assertion below is "a token is ABSENT from the
  #    header", which a kit-init that did nothing at all satisfies perfectly.
  grep -q 'SBX-' "$SB_WORK/.claude/templates/ISSUE.template.md" \
    || cf "(instrument) the ISSUE template BODY was not stamped — kit-init did nothing, and every absence asserted below is meaningless"

  for t in "$SB_WORK"/.claude/templates/*.template.md; do
    [ -e "$t" ] || continue
    base="$(basename "$t")"; n=$((n+1))
    hdr="$(awk '/^<!-- KIT-CLASS:/{p=1} p{print} p && /-->/{exit}' "$t")"
    [ -n "$hdr" ] || { cf "$base: no KIT-CLASS header block after init"; continue; }
    # THE STAMPED VALUES MUST NOT APPEAR INSIDE THE EXPLANATION.
    printf '%s\n' "$hdr" | grep -w 'SBX' >/dev/null \
      && cf "$base: the post-init header names the stamped PREFIX value — kit-init rewrote the sentence that explains kit-init, and the adopter reads a claim with no referent"
    printf '%s\n' "$hdr" | grep -w "$SB_TRUNK" >/dev/null \
      && cf "$base: the post-init header names the stamped TRUNK value where it should be describing a token"
    # …and the instruction that is still in force survived.
    printf '%s\n' "$hdr" | grep -i 'never leave' >/dev/null \
      || cf "$base: the post-init header lost its fill instruction"
  done
  [ "$n" -ge 5 ] \
    || cf "only $n template(s) were examined — the glob stopped matching the tree, which is NOT proof the tree is clean"

  finish "the template header survives the stamp: across $n template(s), the post-init KIT-CLASS block names neither stamped value and keeps its fill instruction, while the bodies are demonstrably stamped"
  teardown
}

# =============================================================================
# CASE — ONE READ EXPRESSION, FIVE SITES, AND EVERY SITE DECLARES ITS FALLBACK POLICY.
#
# Reading the project's declared role set out of scripts/githooks/commit-msg is ONE act
# written five times. It cannot be written once: check-board.sh and kit-init.sh source
# nothing from scripts/lib/, so lib/role-set.sh's kit_role_set reaches its sourcing consumers and
# not the other two.
#
# WHAT ACTUALLY WENT WRONG IS NOT THE COUNT. The copies disagreed and the disagreement was
# invisible: one carried a trailing `.*`, silently tolerating content after the closing
# quote that no other reader accepts. Two sites, same file, different answers, nothing in
# either to show it.
#
# AND THE POLICIES DIFFER ON PURPOSE — check-board falls back to a hardcoded set and SAYS
# so; kit-init treats an unreadable hook as fatal; the library returns empty and makes the
# caller decide; the harness dies. Each is right for its own caller. So this case pins the
# EXPRESSION, which must be identical, and requires each site to DECLARE its policy, which
# must not be guessed at by the next reader.
# =============================================================================
case_role_set_read_is_one_expression() {
  cf_reset
  make_sandbox
  local expr_ rows n

  # DERIVE the canonical expression from the library, never retype it: the library is the
  # declared shape, so a change there is meant to reach the census.
  # Read the REAL shipped tree, not the sandbox: the sandbox omits scripts/test/, which
  # holds two of the five sites — and a census that cannot see two of its operands reports
  # agreement among the three it can.
  expr_="$(sed -n 's/.*sed -n "\(s\/\^ROLE_PREFIXES[^"]*\)".*/\1/p' "$REAL_SCRIPTS/lib/role-set.sh" | head -1)"
  [ -n "$expr_" ] \
    || _fixture_die "case_role_set_read_is_one_expression: could not derive the canonical read out of lib/role-set.sh — a census with no expression to compare against passes forever."

  # Every site that reads ROLE_PREFIXES through sed uses THAT expression.
  rows="$(grep -rn "sed -n \"s/\^ROLE_PREFIXES" "$REAL_SCRIPTS" 2>/dev/null \
          | grep -vF "$expr_" || true)"
  [ -z "$rows" ] \
    || cf "a ROLE_PREFIXES read uses an expression other than the canonical one ('$expr_') — the copies then disagree about the same file with nothing in either to show it: $(printf '%s' "$rows" | tr '\n' ' ' | cut -c1-220)"

  # ── INSTRUMENT CHECK: the census still finds the population. A search that stopped
  #    matching reports "no divergence" about nothing.
  n="$(grep -rc "sed -n \"s/\^ROLE_PREFIXES" "$REAL_SCRIPTS" 2>/dev/null | awk -F: '{t+=$2} END{print t+0}')"
  [ "$n" -ge 4 ] \
    || cf "the census found only $n ROLE_PREFIXES read(s) — expected at least 4. A low count means the idiom changed shape, NOT that the sites agree"

  # EVERY SITE DECLARES ITS FALLBACK POLICY, because the policies legitimately differ and
  # an undeclared one is indistinguishable from a copied one.
  #
  # THE POPULATION IS DERIVED, NOT LISTED — and this arm is the reason the rule has to be stated
  # for cases as well as for products. It read `for f in check-board.sh kit-init.sh lib/role-set.sh`,
  # a hand-typed list of three, inside a case whose ENTIRE SUBJECT is that this read should be
  # derived rather than retyped. Arm 1 above already derives the site set recursively; this arm
  # walked past that derivation and named its own files.
  #
  # AND IT FAILED IN THE SILENT DIRECTION, which is why it is worth more than the tidiness: a
  # FOURTH file that reads ROLE_PREFIXES faithfully and declares no fallback policy is caught by
  # arm 1 only if its EXPRESSION differs. Copy the canonical expression, say nothing about the
  # fallback, and this arm never looked — its loop `continue`s on files it does not name, and it
  # did not name that one. The `continue` shows the author knew the list might not match the
  # readers; the fix is to stop having a list.
  local f miss="" sites
  sites="$( { grep -rl "sed -n \"s/\^ROLE_PREFIXES" "$REAL_SCRIPTS" 2>/dev/null || true; } | sort )"
  [ -n "$sites" ] \
    || _fixture_die "case_role_set_read_is_one_expression: the site derivation found no file reading ROLE_PREFIXES, so the fallback-policy arm would pass over an empty population. Arm 1's own instrument check above should have caught this first."
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qiE 'FALLBACK POLICY|Callers MUST treat empty' "$f" \
      || miss="$miss ${f#"$REAL_SCRIPTS/"}"
  done <<SITES_EOF
$sites
SITES_EOF
  [ -z "$miss" ] \
    || cf "these sites read ROLE_PREFIXES and declare no fallback policy —$miss. The policies differ on purpose; an undeclared one cannot be told from a copied one, and the next reader has to guess which"

  finish "the ROLE_PREFIXES read is ONE expression at all $n sites (derived from lib/role-set.sh, not retyped) and every shipped site declares its own fallback policy — the expression is shared by assertion because two of the readers source nothing from scripts/lib/, and the policies differ on purpose"
  teardown
}

# =============================================================================
# CASE — THE COPY-LIST MINIMUM IS A REAL MINIMUM, AND IT IS DERIVED, NOT RETYPED.
#
# THIS CASE EXISTS BECAUSE OF A DECLINE. It was asked whether this preflight should
# check the whole manifest instead of a hand-typed minimum, and the answer was no: the
# manifest is prose in process/EXTRACTION.md, process/contracts/initializer.md § 1
# forbids the initializer carrying a second copy of it, and a machine-readable manifest
# is a new shipped artifact bought for one preflight. What a decline owes is a control
# proving the thing KEPT actually works — otherwise "the minimum is enough" is an
# assertion, and the wider promise was withdrawn on the strength of it.
# (Since then the build ships process/KIT-MANIFEST, and the preflight reads it for one
# question only — shipped paths on disk but uncommitted. Presence is still the
# hand-listed minimum, which is what this case controls.)
#
# The list is DERIVED out of the shipped script. A retyped copy here would be the exact
# second-hand-typed-list the decline promised not to create, and it would go stale in the
# one direction that matters: a file added to COPY_LIST and not to this case is a file
# nobody checks.
# =============================================================================
case_kit_init_copy_list_minimum_is_real() {
  cf_reset
  if ! has_issue_template; then skp "kit-init's copy-list minimum is a REAL minimum" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  kit_init_sandbox
  publish_sandbox
  local out rc f n=0
  local ki="$SB_WORK/scripts/kit-init.sh"

  # DERIVE the list out of the shipped array — never retype it.
  local list; list="$(awk '/^COPY_LIST=\($/{f=1;next} f&&/^\)$/{exit} f{gsub(/^[[:space:]]+|[[:space:]]+$/,"");print}' "$ki")"
  [ -n "$list" ] \
    || _fixture_die "case_kit_init_copy_list_minimum_is_real: could not derive COPY_LIST out of kit-init.sh — the array was renamed or reshaped, and a case that derives nothing passes forever."

  # ── INSTRUMENT CHECK: kit-init SUCCEEDS on the untouched fixture. Every "it refused"
  #    below is otherwise satisfied by a fixture that never worked in the first place.
  local pristine="$SB_TMP/cl-pristine"
  rm -rf "$pristine"; cp -R "$SB_WORK" "$pristine"
  rc=0; out="$( "$pristine/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
  [ "$rc" -eq 0 ] \
    || _fixture_die "case_kit_init_copy_list_minimum_is_real: kit-init exits $rc on the UNMUTATED fixture: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # EVERY member is load-bearing: remove exactly one, and the preflight must NAME it.
  # One at a time, because removing all seven cannot tell a real minimum from a list
  # whose refusal happens to mention the first entry.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    local probe="$SB_TMP/cl-probe"
    rm -rf "$probe"; cp -R "$SB_WORK" "$probe"
    [ -e "$probe/$f" ] \
      || { cf "COPY_LIST names '$f' but the shipped kit does not contain it — the list has rotted away from the tree"; continue; }
    rm -rf "${probe:?}/$f"
    rc=0; out="$( "$probe/scripts/kit-init.sh" --prefix SBX --trunk "$SB_TRUNK" 2>&1 )" || rc=$?
    [ "$rc" -ne 0 ] \
      || cf "kit-init exited 0 with '$f' missing — that entry is in COPY_LIST but nothing depends on it being there"
    printf '%s' "$out" | grep -F "$f" >/dev/null \
      || cf "kit-init refused with '$f' missing but did NOT name it: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
    rm -rf "$probe"
  done <<EOF
$list
EOF

  # A LIST THAT SHRANK TO NOTHING would satisfy the loop above vacuously.
  [ "$n" -ge 5 ] \
    || cf "COPY_LIST derived only $n entries — the minimum has shrunk or the derivation is reading the wrong array"

  finish "kit-init's copy-list minimum is a REAL minimum: every one of its $n entries, derived out of the shipped array rather than retyped, makes the preflight refuse AND name that path when it is absent (the decline of 104 rests on this)"
  teardown
}
