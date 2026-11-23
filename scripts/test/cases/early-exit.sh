# KIT-CLASS: MIXED — self-test harness, early-exit reader cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/early-exit.sh — sourced by scripts/test/run.sh, never run on its own.
# One class: a program that stops reading before its input ends, fed through a pipe by one that is still
# writing. The writer's next write finds the pipe closed (EPIPE, or SIGPIPE), and under `set -o pipefail` the
# whole pipeline reports it, so a read that found its answer fails the caller. Which write loses the race
# depends on timing, so the failure shows only on a loaded machine; the cases here make the input larger than
# one write, which makes it certain.
# =============================================================================

# =============================================================================
# CASE — AN AC BULLET'S READER FINDS ITS ANSWER WITHOUT FAILING THE CALLER WHEN THE BODY RUNS ON AFTER IT.
# `move-issue.sh` to dev_complete read a card's AC bullet through an awk program that stopped at the next
# bullet while `printf` was still writing the card; kit-init's self-check makes that move, so day one failed
# on a loaded machine with `printf: write error: Broken pipe` and no refusal.
# Rows: a body with the AC bullet, a second bullet and then many lines gives the bullet's line number and its
# text and status 0, under pipefail, with SIGPIPE at its default and again with it ignored (an agent shell
# ignores it); the same body, small, gives the same answers (control).
# =============================================================================
case_an_ac_bullet_reader_does_not_fail_when_the_body_runs_on_after_the_bullet() {
  cf_reset
  local L="the AC bullet readers (_qav_ac_bullet_linenos and _qav_ac_bullet_block) answer with status 0 under pipefail when the card body is far larger than one pipe write and runs on after the bullet, with SIGPIPE default and ignored"
  local lib="$REAL_SCRIPTS/lib/qa-gate.sh"
  [ -f "$lib" ] || { skp "$L" "scripts/lib/qa-gate.sh is absent from this tree"; return; }
  local mode rc out want_l want_t
  want_l="1"; want_t="first bullet"
  for mode in default ignored; do
    rc=0
    out="$(bash -c '
      [ "$2" = ignored ] && trap "" PIPE
      set -o pipefail
      . "$1" 2>/dev/null
      body="$(printf -- "- [ ] AC1 — first bullet\n- [ ] AC2 — second bullet\n"; i=0; while [ $i -lt 6000 ]; do echo "filler line number $i with some padding text to make it long"; i=$((i+1)); done)"
      l="$(_qav_ac_bullet_linenos "$body" AC1)" || exit 21
      t="$(_qav_ac_bullet_block "$body" AC1)" || exit 22
      printf "%s|%s" "$l" "$t"
    ' _ "$lib" "$mode" 2>&1)" || rc=$?
    [ "$rc" -eq 0 ] || cf "($mode) the reader failed with status $rc on a large body (21 = _qav_ac_bullet_linenos, 22 = _qav_ac_bullet_block): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
    [ "$out" = "$want_l|$want_t" ] || [ "$rc" -ne 0 ] || cf "($mode) the reader's answer on a large body was '$(printf '%s' "$out" | cut -c1-100)', want '$want_l|$want_t'"
  done
  # (control) the same bullets with nothing after them: the same answers, so the rows above are about size.
  rc=0
  out="$(bash -c 'set -o pipefail; . "$1" 2>/dev/null; body="$(printf -- "- [ ] AC1 — first bullet\n- [ ] AC2 — second bullet\n")"; printf "%s|%s" "$(_qav_ac_bullet_linenos "$body" AC1)" "$(_qav_ac_bullet_block "$body" AC1)"' _ "$lib" 2>&1)" || rc=$?
  { [ "$rc" -eq 0 ] && [ "$out" = "$want_l|$want_t" ]; } || cf "(control) a small body did not give '$want_l|$want_t' with status 0 (status $rc, got '$(printf '%s' "$out" | cut -c1-100)')"
  finish "$L"
}
