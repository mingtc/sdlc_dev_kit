# KIT-CLASS: MIXED — self-test harness, small script defects (input escaping, previews, argument ranges). See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/small-defects.sh — sourced by scripts/test/run.sh, never run on its own.
# One case per script defect that has its own reproduction and no larger subject. Each states the
# observed failure in its header and carries a control, so a green row is not a broken script.
# =============================================================================

# =============================================================================
# CASE — set-models.sh WRITES AN ID EXACTLY AS GIVEN OR REFUSES IT; AND PINS ONLY THE FRONTMATTER.
# The ids it can write exactly are letters, digits and . _ : / [ ] -; anything else (an apostrophe that
# breaks the runner's JavaScript, a backslash awk interprets, a `|` that adds a column to the ladder's
# table row, a space) is refused with exit 2 and nothing is written. A body line that starts with
# `model:` is prose, not the pin.
# =============================================================================
case_set_models_writes_an_id_as_given_or_refuses_it_and_pins_only_the_frontmatter() {
  cf_reset
  make_sandbox
  local ad orch sm="$SB_WORK/scripts/set-models.sh" snap="$SB_TMP/claude.before" out rc row cls model effort
  read -r ad orch <<<"$(_seed_provisioning_sandbox)"
  if [ -z "$ad" ]; then skp "set-models.sh refuses an id it cannot write as given" "no .claude/agents + roles/orchestrator.md in the real tree"; teardown; return; fi
  [ -x "$sm" ] || { cf "scripts/set-models.sh is absent or not executable"; finish "set-models.sh id shape"; teardown; return; }
  cp -R "$SB_WORK/.claude" "$snap"
  # <row>@<scope>@<model>@<effort>
  while IFS=';' read -r row cls model effort; do
    [ -n "$row" ] || continue
    out="$( cd "$SB_WORK" && ./scripts/set-models.sh $cls --model "$model" --effort "$effort" 2>&1 )"; rc=$?
    [ "$rc" -eq 2 ] || cf "($row) an id it cannot write as given exited $rc, not 2: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "($row) the refusal names no Next:"
    diff -r -x model-pins.record "$snap" "$SB_WORK/.claude" >/dev/null 2>&1 || cf "($row) the refused call changed .claude/: $(diff -r -x model-pins.record "$snap" "$SB_WORK/.claude" 2>&1 | head -3 | tr '\n' '|' | cut -c1-200)"
  done <<'SM_ROWS'
apostrophe;--runners;it's;high
backslash;--runners;m;a\b
pipe;--class dev;a&b|c\d;high
space-effort;--class dev;claude-x;hi gh
space-model;--class dev;claude x;high
leading-dash;--class dev;-x;high
SM_ROWS
  # (control) an ordinary id is written exactly, and a body line starting `model:` is left alone
  printf 'model: example of a config value in prose\n' >> "$ad/dev-worker.md"
  out="$( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model 'claude-x.1[1m]' --effort high 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(control) an ordinary id was refused ($rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  grep -qxF 'model: claude-x.1[1m]' "$ad/dev-worker.md" || cf "(control) the pin was not written as given: $(grep -E '^model:' "$ad/dev-worker.md" | tr '\n' '|')"
  grep -qxF 'model: example of a config value in prose' "$ad/dev-worker.md" || cf "(body) a body line that starts 'model:' was rewritten: $(grep -E '^model:' "$ad/dev-worker.md" | tr '\n' '|')"
  # (at) a Vertex-style id with @ is written as given
  out="$( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model 'claude-opus-4-1@20250805' --effort high 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(at) an id with @ was refused ($rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  grep -qxF 'model: claude-opus-4-1@20250805' "$ad/dev-worker.md" || cf "(at) the pin was not written as given: $(grep -E '^model:' "$ad/dev-worker.md" | tr '\n' '|')"
  # (nofm) a file with no frontmatter on its first line is refused, not half-written: no success line, no record
  printf '# a pin with no frontmatter\n\n---\n\nmodel: prose\neffort: prose\n' > "$ad/dev-worker.md"
  cp "$ad/dev-worker.md" "$SB_TMP/nofm.before"; : > "$SB_TMP/rec.before"; cp "$SB_WORK/.claude/model-pins.record" "$SB_TMP/rec.before" 2>/dev/null || true
  out="$( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model NEWM2 --effort NEWE2 2>&1 )"; rc=$?
  [ "$rc" -eq 1 ] || cf "(nofm) a pin file with no frontmatter exited $rc, not the shape refusal's 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  cmp -s "$ad/dev-worker.md" "$SB_TMP/nofm.before" || cf "(nofm) a file with no frontmatter was changed"
  grep -F 'NEWM2' "$SB_WORK/.claude/model-pins.record" >/dev/null 2>&1 && cf "(nofm) the record names a pin that was never written"
  printf '# no dashes at all\n\nmodel: prose\neffort: prose\n' > "$ad/dev-worker.md"
  out="$( cd "$SB_WORK" && ./scripts/set-models.sh --class dev --model NEWM3 --effort NEWE3 2>&1 )"; rc=$?
  [ "$rc" -eq 1 ] || cf "(nodash) a pin file with no --- at all exited $rc, not 1"
  printf '%s\n' "$out" | grep -F 'set-models: dev ->' >/dev/null && cf "(nodash) a success line was printed over a file that was not written"
  grep -F 'NEWM3' "$SB_WORK/.claude/model-pins.record" >/dev/null 2>&1 && cf "(nodash) the record names a pin that was never written"
  finish "set-models.sh refuses (exit 2, a Next, nothing written) an id with a quote, backslash, pipe, space or leading dash, writes an ordinary id and one with @ exactly, rewrites only a frontmatter pair that opens on line 1, and records only what it wrote"
  teardown
}

# =============================================================================
# CASE — archive.sh's PREVIEW COMMITS NOTHING, SO IT NEEDS NO ROLE TAG.
# With the project's role set narrowed to exclude the tag the sweep commits under, --apply must still
# refuse before it mutates; the default preview and --dry-run must print what they would sweep.
# =============================================================================
case_archive_preview_does_not_demand_a_role_tag() {
  cf_reset
  make_sandbox
  seed_issue qa_complete "$SB_PREFIX-300" alpha chore "Archive alpha"
  publish_sandbox
  local cm="$SB_WORK/scripts/githooks/commit-msg" narrow='PM|Dev' out rc flag
  NEU_NEW="$narrow" perl -i -pe "s@^ROLE_PREFIXES='.*'\$@ROLE_PREFIXES='\$ENV{NEU_NEW}'@" "$cm"
  grep -qxF "ROLE_PREFIXES='$narrow'" "$cm" || _fixture_die "case_archive_preview_does_not_demand_a_role_tag: the narrowed role set did not land"
  git -C "$SB_WORK" add -A >/dev/null 2>&1
  sbcommit -m "[PM] narrow the declared role set" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  for flag in "" --dry-run; do
    rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" $flag 2>&1 )" || rc=$?
    [ "$rc" -eq 0 ] || cf "(preview ${flag:-default}) the preview exited $rc over a role tag it does not use: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    printf '%s\n' "$out" | grep -F 'Found 1 file(s)' >/dev/null || cf "(preview ${flag:-default}) the preview did not list the sweep: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  done
  rc=0; out="$( cd "$SB_WORK" && "$SB_WORK/scripts/archive.sh" --apply 2>&1 )" || rc=$?
  [ "$rc" -ne 0 ] || cf "(control) --apply exited 0 with a role tag the project does not declare"
  printf '%s\n' "$out" | grep -F 'ARCHIVE_ROLE' >/dev/null || cf "(control) the --apply refusal no longer names ARCHIVE_ROLE"
  finish "archive.sh's default preview and --dry-run list the sweep without a declared role tag, while --apply still refuses before it mutates"
  teardown
}

# =============================================================================
# CASE — notify.sh DOES NOT RUN THE WATCHDOG AS A BACKEND.
# scripts/notify/stall.sh sits beside the adapters but has no `send)` arm, so NOTIFY_BACKEND=stall is
# "no adapter", said once with the available list, not a usage dump from the watchdog.
# =============================================================================
case_notify_refuses_the_watchdog_as_a_backend() {
  cf_reset
  make_sandbox
  if [ ! -f "$SB_WORK/scripts/notify.sh" ] || [ ! -f "$SB_WORK/scripts/notify/stall.sh" ]; then skp "notify.sh refuses the watchdog as a backend" "notify.sh or notify/stall.sh is deleted in this tree"; teardown; return; fi
  local out rc
  rc=0; out="$( cd "$SB_WORK" && NOTIFY_BACKEND=stall ./scripts/notify.sh test 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || cf "(test) NOTIFY_BACKEND=stall exited $rc, not the no-adapter refusal's 1: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -F 'not an adapter' >/dev/null || cf "(test) the refusal does not say the watchdog is not an adapter: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -F 'unknown option' >/dev/null && cf "(test) the watchdog was run as an adapter and dumped its usage"
  rc=0; out="$( cd "$SB_WORK" && NOTIFY_BACKEND=stall ./scripts/notify.sh done hi --session s 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep -F 'unknown option' >/dev/null && cf "(send) the watchdog was run as an adapter and dumped its usage"
  printf '%s\n' "$out" | grep -F 'delivery FAILED' >/dev/null && cf "(send) a send through the watchdog reported a delivery failure instead of no adapter"
  printf '#!/usr/bin/env bash\ncase "$1" in send|test) echo "DELIVERED $NOTIFY_TEXT" ;; esac\n' > "$SB_WORK/scripts/notify/mine.sh"
  rc=0; out="$( cd "$SB_WORK" && NOTIFY_BACKEND=mine NOTIFY_WITH_MSG_AND_ALERT=done ./scripts/notify.sh done hi --session s 2>&1 )" || rc=$?
  printf '%s\n' "$out" | grep -F 'DELIVERED' >/dev/null || cf "(adapter) an adapter whose case arm is send|test) was not run: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  finish "notify.sh treats the stall watchdog as no adapter, in test and in send, and never runs it; an adapter with a send|test) arm still delivers"
  teardown
}

# =============================================================================
# CASE — THE HYGIENE INSTRUMENTS REFUSE A ROOT OR A PARAMETER THAT MAKES THEIR ZERO MEAN NOTHING.
# `orphans: 0` over a path that does not exist, a 0-gram, a 500% threshold and a negative day count
# are not measurements. Each exits 2 with a message; the same tool over a real root still exits 0.
# =============================================================================
case_hygiene_instruments_refuse_a_missing_root_and_an_absurd_parameter() {
  cf_reset
  if ! command -v python3 >/dev/null 2>&1; then skp "hygiene instruments refuse a missing root" "python3 absent — these are advisory instruments and Python is their declared carve-out"; return; fi
  make_sandbox
  local hy="$REAL_SCRIPTS/hygiene" rc row tool args root="$SB_WORK"
  if [ ! -d "$hy" ]; then skp "hygiene instruments refuse a missing root" "scripts/hygiene/ absent"; teardown; return; fi
  # <row>@<tool>@<arguments>@<what the message must name>
  while IFS='@' read -r row tool args want; do
    [ -n "$row" ] || continue
    [ -f "$hy/$tool.py" ] || continue
    rc=0; ( cd "$root" && PYTHONDONTWRITEBYTECODE=1 python3 -I "$hy/$tool.py" $args >/dev/null 2>"$SB_TMP/hy.err" ) || rc=$?
    [ "$rc" -eq 2 ] || cf "($row) $tool $args exited $rc, not 2: $(tr '\n' '|' < "$SB_TMP/hy.err" | cut -c1-160)"
    grep -F -- "$want" "$SB_TMP/hy.err" >/dev/null || cf "($row) the message does not name '$want': $(tr '\n' '|' < "$SB_TMP/hy.err" | cut -c1-160)"
  done <<HY_ROWS
reach-root@reachability_walk@--root /nonexistent/kit-no-such-root@not a directory
cite-root@citation_index@--root /nonexistent/kit-no-such-root X@not a directory
dup-root@duplication_scan@--root /nonexistent/kit-no-such-root@not a directory
dup-n@duplication_scan@--root $root --n 0@--n
dup-min@duplication_scan@--root $root --min 5@--min
cold-root@cold_signal@--root /nonexistent/kit-no-such-root@not a directory
cold-days@cold_signal@--root $root --days=-3@--days
HY_ROWS
  for tool in reachability_walk duplication_scan; do
    [ -f "$hy/$tool.py" ] || continue
    rc=0; ( cd "$root" && PYTHONDONTWRITEBYTECODE=1 python3 -I "$hy/$tool.py" --root "$root" >/dev/null 2>"$SB_TMP/hy.err" ) || rc=$?
    [ "$rc" -eq 0 ] || cf "(control) $tool over a real root exited $rc: $(cat "$SB_TMP/hy.err" | tr '\n' '|' | cut -c1-160)"
  done
  finish "reachability_walk, citation_index, duplication_scan and cold_signal exit 2 on a missing --root, and duplication_scan and cold_signal on an out-of-range --n, --min or --days; a real root still runs"
  teardown
}

# =============================================================================
# CASE — verify.sh REFUSES A GATE WHOSE COMMAND IS ONLY WHITESPACE.
# `gate|core| ` passed the shape test (-z on a one-space string) and died later on an empty command array.
# =============================================================================
case_verify_refuses_a_gate_with_a_blank_command() {
  cf_reset
  make_sandbox
  local v="$SB_WORK/scripts/verify.sh" out rc
  if [ ! -f "$v" ] || ! grep -q '^GATES=($' "$v"; then skp "verify.sh refuses a blank gate command" "no GATES=( anchor in scripts/verify.sh"; teardown; return; fi
  perl -i -pe 's/^GATES=\($/GATES=(\n  "blank|core| "/' "$v"
  grep -qF '"blank|core| "' "$v" || _fixture_die "case_verify_refuses_a_gate_with_a_blank_command: the blank gate did not land"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/verify.sh 2>&1 )" || rc=$?
  [ "$rc" -eq 2 ] || cf "a whitespace-only gate command exited $rc, not 2: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -F 'gate-record-malformed' >/dev/null || printf '%s\n' "$out" | grep -F 'malformed gate record' >/dev/null || cf "the refusal does not call the record malformed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -F 'unbound variable' >/dev/null && cf "verify.sh died on an unbound variable instead of refusing"
  finish "verify.sh refuses (exit 2, malformed record) a gate whose command is only whitespace"
  teardown
}

# =============================================================================
# CASE — new-prd.sh MINTS PRD-001 WHEN THE ONLY FILE IS NOT NUMBERED.
# A name the number pattern does not match went through sed whole and broke the arithmetic.
# =============================================================================
case_new_prd_ignores_a_file_that_carries_no_number() {
  cf_reset
  if ! has_issue_template; then skp "new-prd.sh ignores an unnumbered file" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  if [ ! -f "$SB_WORK/scripts/new-prd.sh" ]; then skp "new-prd.sh ignores an unnumbered file" "new-prd.sh is absent"; teardown; return; fi
  local out rc pfx tpl="$REAL_REPO_ROOT/.claude/templates/PRD.template.md"
  [ -f "$tpl" ] || tpl="$REAL_REPO_ROOT/_claude/templates/PRD.template.md"
  if [ ! -f "$tpl" ]; then skp "new-prd.sh ignores an unnumbered file" "no PRD template in the real tree"; teardown; return; fi
  mkdir -p "$SB_WORK/.claude/templates" && cp "$tpl" "$SB_WORK/.claude/templates/PRD.template.md"
  pfx="$( cd "$SB_WORK" && . scripts/config.sh >/dev/null 2>&1; printf '%s' "${PRD_PREFIX:-PRD}" )"
  mkdir -p "$SB_WORK/requirements"
  printf '# overview\n' > "$SB_WORK/requirements/${pfx}-overview.md"
  rc=0; out="$( cd "$SB_WORK" && ./scripts/new-prd.sh first-slug 2>&1 )" || rc=$?
  if printf '%s\n' "$out" | grep -F 'template not found' >/dev/null; then skp "new-prd.sh ignores an unnumbered file" "the sandbox has no PRD template"; teardown; return; fi
  [ "$rc" -eq 0 ] || cf "new-prd.sh exited $rc beside an unnumbered ${pfx}-overview.md: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"
  [ -f "$SB_WORK/requirements/${pfx}-001-first-slug.md" ] || cf "no ${pfx}-001 was minted: $(ls "$SB_WORK/requirements" | tr '\n' ' ')"
  printf '%s\n' "$out" | grep -F 'unbound variable' >/dev/null && cf "new-prd.sh died on an unbound variable"
  # a numbered file counts with or without a slug
  rm -f "$SB_WORK/requirements/${pfx}-"*.md; printf '# x\n' > "$SB_WORK/requirements/${pfx}-003.md"
  ( cd "$SB_WORK" && ./scripts/new-prd.sh second-slug >/dev/null 2>&1 )
  [ -f "$SB_WORK/requirements/${pfx}-004-second-slug.md" ] || cf "(lone 003) beside ${pfx}-003.md no ${pfx}-004 was minted: $(ls "$SB_WORK/requirements" | tr '\n' ' ')"
  rm -f "$SB_WORK/requirements/${pfx}-"*.md; printf '# x\n' > "$SB_WORK/requirements/${pfx}-001.md"
  ( cd "$SB_WORK" && ./scripts/new-prd.sh third-slug >/dev/null 2>&1 )
  [ -f "$SB_WORK/requirements/${pfx}-002-third-slug.md" ] || cf "(lone 001) beside ${pfx}-001.md no ${pfx}-002 was minted (a duplicate id?): $(ls "$SB_WORK/requirements" | tr '\n' ' ')"
  finish "new-prd.sh skips a file that carries no number and mints PRD-001"
  teardown
}

# =============================================================================
# CASE — THE BRAINSTORMING COMPANION'S stop-server.sh DELETES NO SESSION DIRECTORY REACHED THROUGH `..`.
# A prefix test on the text let `/tmp/../<elsewhere>` through, and that directory was deleted whole. (A symlink
# under /tmp that points elsewhere is not covered.)
# =============================================================================
case_brainstorm_stop_server_does_not_delete_through_a_dotdot_path() {
  cf_reset
  local rel=".claude/skills/brainstorming/scripts/stop-server.sh" L="stop-server.sh keeps a session directory reached through /tmp/.." phys arg pid out
  if [ ! -f "$REAL_REPO_ROOT/$rel" ]; then skp "$L" "$rel absent"; return; fi
  make_sandbox
  mkdir -p "$SB_WORK/.brainstorm/s2/state"
  phys="$(cd "$SB_WORK/.brainstorm/s2" && pwd -P)"
  case "$phys" in /tmp/*|/private/tmp/*) teardown; skp "$L" "the sandbox is under /tmp itself"; return ;; esac
  case "$phys" in /private/*) arg="/tmp/..${phys#/private}" ;; *) arg="/tmp/..$phys" ;; esac
  [ -d "$arg" ] || { teardown; skp "$L" "/tmp/.. does not reach the sandbox on this machine ($arg)"; return; }
  sleep 60 & pid=$!
  printf '%s\n' "$pid" > "$SB_WORK/.brainstorm/s2/state/server.pid"
  out="$(bash "$REAL_REPO_ROOT/$rel" "$arg" 2>&1)" || true
  kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true
  [ -d "$phys" ] || cf "a session directory reached through /tmp/.. was deleted: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  teardown
  finish "$L"
}

# =============================================================================
# CASE — check-board's [j] AND [f0] READ AN ID IN ANY CASE AND A PATH GIT QUOTES.
# (j) a lower-case prefix, which ISSUE_ID_PATTERN allows, was not an id: the row of a landed card read as live.
# (f0) a path with a space is quoted in git's porcelain and was never matched to the places the arms read.
# =============================================================================
case_check_board_reads_a_lower_case_id_and_a_quoted_path() {
  cf_reset
  make_sandbox
  mkdir -p "$SB_WORK/dev" "$SB_WORK/requirements"
  cat > "$SB_WORK/dev/downtime-queue.md" <<'DQEOF'
| Item | Origin | Size | Why deferred | Wake condition | Status |
|---|---|---|---|---|---|
| **Landed already** | audit | S | — | now | open (claimed by zzq-101) |
| **Prose first** | audit | S | — | now | open — queued after step-4, claimed by ZZQ-103 |
DQEOF
  : > "$SB_WORK/progress/done/zzq-101-a.md"
  : > "$SB_WORK/progress/done/ZZQ-103-b.md"
  publish_sandbox
  printf 'x\n' > "$SB_WORK/requirements/a b.md"
  printf 'x\n' > "$SB_WORK/requirements/ab.md"
  local out sec
  out="$(cb_run)"
  sec="$(printf '%s\n' "$out" | awk '/^\[j\]/{f=1;print;next} f&&/^\[/{f=0} f')"
  printf '%s\n' "$sec" | grep -F 'zzq-101' >/dev/null || cf "(j) an open row claiming a landed LOWER-CASE id was not reported: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$sec" | grep -F 'ZZQ-103' >/dev/null || cf "(j) a claim after other word-N prose ('queued after step-4, claimed by ZZQ-103') was not reported: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-240)"
  sec="$(printf '%s\n' "$out" | grep -F '[f0]')"
  printf '%s\n' "$sec" | grep -F 'requirements/ab.md' | grep -F '⚠' >/dev/null || cf "(f0, control) an untracked path without a space is not a ⚠: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$sec" | grep -F 'requirements/a b.md' | grep -F '⚠' >/dev/null || cf "(f0) an untracked path WITH a space is not a ⚠: $(printf '%s' "$sec" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$sec" | grep -F '"requirements/a b.md"' >/dev/null && cf "(f0) the path is named with git's quotes around it"
  finish "check-board [j] reports a landed card claimed under a lower-case prefix, and [f0] warns on an untracked path with a space as it does on one without"
  teardown
}
