# KIT-CLASS: MIXED — self-test harness, the files a project adds to extend the kit. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/extension-points.sh — sourced by scripts/test/run.sh, never run on its own.
# Each case adds through an extension point exactly as a project would (a file, not an edit to a
# script), proves every reader of that point takes it up, removes it, and proves they refuse again.
# The points pinned here: the role set's layers (process/ROLES, process/roles.d/), the board
# report's arms (scripts/check-board.d/), the QA evidence kinds (process/evidence-kinds.d/), the
# shared-file blocks (scripts/lib/marker-block.sh), the mint's fragments (process/fragments.d/), the
# board mover's checks (scripts/move-check.d/) and the QA rows' cell checks (scripts/qa-cell.d/).
# =============================================================================

# _rl_hook <role> — the commit-msg hook's status on a subject carrying that tag.
_rl_hook() {
  local msg="$SB_TMP/rl-msg.txt"
  printf '[%s] %s-001: extension point\n' "$1" "$SB_PREFIX" > "$msg"
  "$SB_WORK/scripts/githooks/commit-msg" "$msg" >/dev/null 2>&1
}

# _rl_set — the layered set as the library reads it, `|`-joined; empty when unreadable.
_rl_set() { ( . "$SB_WORK/scripts/lib/role-set.sh"; kit_role_set "$SB_WORK" ); }

# _rl_in_set <role> — status 0 when the library's set names it.
_rl_in_set() { local s; s="$(_rl_set)"; case "|$s|" in *"|$1|"*) return 0 ;; esac; return 1; }

# _rl_land <message> — commit what the layers hold and push it: the board is committed from a
# copy of the trunk, which reads the layers there.
_rl_land() {
  git -C "$SB_WORK" add -A process >/dev/null 2>&1
  sbcommit -q -m "[Dev] $SB_PREFIX-001: $1" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
}

# _rl_mover <id> <role> — move the card with move-issue.sh; its status is left in `_rl_rc` and its
# output in `_rl_out`.
_rl_rc=0; _rl_out=""
_rl_mover() {
  _rl_rc=0
  _rl_out="$( cd "$SB_WORK" && ./scripts/move-issue.sh "$1" in_progress --role "$2" --note x 2>&1 )" || _rl_rc=$?
}

# _rl_subtask_refuses_role <role> — status 0 when subtask.sh's --role check refuses the tag. The
# slice does not exist, so an accepted role ends at a later, different refusal.
_rl_subtask_refuses_role() {
  local out
  out="$( cd "$SB_WORK" && ./scripts/subtask.sh move "$SB_PREFIX-001-s1" in_progress --role "$1" --note x 2>&1 || true )"
  [[ "$out" == *"--role must be"* ]]
}

# _rl_cb_flags_role <role> — status 0 when check-board's [e] scan reports a trunk commit tagged
# with the role as lacking a prefix.
_rl_cb_flags_role() {
  local out
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'lacks a [Role] prefix' | grep -F "[$1]" >/dev/null
}

# =============================================================================
# CASE — A ROLE ADDED BY A LAYER FILE IS ACCEPTED BY EVERY READER OF THE SET, AND REFUSED AGAIN
# WHEN THE FILE GOES.
#   The population is every reader, not one: the commit-msg hook, the board mover's --role check,
#   subtask.sh's --role check, the library's own set, a usage text rendered from it, and
#   check-board's attribution scan. A role the hook accepts and the mover does not leaves the seat
#   that holds it unable to move a card. Both layers are driven: the project's process/ROLES and a
#   file under process/roles.d/.
# =============================================================================
case_a_role_added_by_a_layer_file_is_read_by_every_consumer_and_refused_again_when_it_goes() {
  cf_reset
  local L="a role added by a line in process/ROLES or by a file under process/roles.d/ is accepted by the commit-msg hook, move-issue.sh --role, subtask.sh --role, the library's set, a usage text and check-board's [e] scan, and is refused by each of them again once the file is gone; a base role survives a layer; a line that is not a plain tag adds nothing"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local role="Zebra" out i
  local ids=("$SB_PREFIX-710" "$SB_PREFIX-711" "$SB_PREFIX-712")
  for i in 0 1 2; do seed_issue todo "${ids[$i]}" "layer$i" chore "A card for the role layers case $i"; done
  publish_sandbox
  # A trunk commit already carrying the tag: what check-board's scan judges at each step.
  sbcommit -q --allow-empty -m "[$role] ${ids[0]}: a commit by the seat" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1

  # (control) no layer names it, so every reader refuses — the premise of what follows.
  _rl_in_set "$role" && _fixture_die "case_a_role_added_by_a_layer_file_is_read_by_every_consumer_and_refused_again_when_it_goes: '$role' is already in the sandbox's set, so nothing below measures a layer."
  _rl_hook "$role" && cf "(control) the hook accepted [$role] before any layer declared it"
  _rl_mover "${ids[0]}" "$role"
  [ "$_rl_rc" -ne 0 ] || cf "(control) the mover accepted --role $role before any layer declared it: $_rl_out"
  _rl_subtask_refuses_role "$role" || cf "(control) subtask.sh did not refuse --role $role before any layer declared it"
  _rl_cb_flags_role "$role" || cf "(control) check-board did not report the [$role] trunk commit before any layer declared it — the scan this case reads from cannot see the defect"

  # (a) THE PROJECT LAYER: one line in process/ROLES.
  mkdir -p "$SB_WORK/process"
  printf '# project additions\n%s   the seat the project adds\n' "$role" > "$SB_WORK/process/ROLES"
  _rl_land "add the $role role"
  _rl_hook "$role" || cf "(a) the hook refused [$role] after process/ROLES declared it"
  _rl_hook Dev || cf "(a) the hook refused a base role once a layer was added — a layer only adds"
  _rl_in_set "$role" || cf "(a) the library's set does not carry $role: $(_rl_set)"
  _rl_in_set Dev || cf "(a) the library's set lost a base role once a layer was added: $(_rl_set)"
  _rl_subtask_refuses_role "$role" && cf "(a) subtask.sh refused --role $role though process/ROLES declared it"
  out="$( cd "$SB_WORK" && ./scripts/move-issue.sh --help 2>&1 || true )"
  [[ "$out" == *"$role"* ]] || cf "(a) move-issue.sh --help does not list $role, though its usage text renders from the declared set"
  _rl_mover "${ids[0]}" "$role"
  [ "$_rl_rc" -eq 0 ] || cf "(a) the mover refused --role $role though process/ROLES declared it (exit $_rl_rc): $_rl_out"
  origin_has_path "progress/in_progress/${ids[0]}-layer0.md" || cf "(a) the card did not reach in_progress/ on the trunk"
  _rl_cb_flags_role "$role" && cf "(a) check-board still reported a [$role] commit though process/ROLES declares it on the trunk"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'extended by process/ROLES and process/roles.d/' >/dev/null \
    || cf "(a) check-board's [e] arm does not say its set was extended: $(printf '%s' "$out" | grep -F '[e]' | head -1)"

  # (b) REMOVAL: the file goes, and the role is refused again by every reader.
  git -C "$SB_WORK" rm -q -f process/ROLES >/dev/null 2>&1
  _rl_land "remove the $role role"
  [ -e "$SB_WORK/process/ROLES" ] && cf "(b) (control) process/ROLES is still on disk"
  _rl_hook "$role" && cf "(b) the hook still accepts [$role] after process/ROLES was removed"
  _rl_in_set "$role" && cf "(b) the library's set still carries $role after removal"
  _rl_subtask_refuses_role "$role" || cf "(b) subtask.sh still accepts --role $role after process/ROLES was removed"
  _rl_mover "${ids[1]}" "$role"
  [ "$_rl_rc" -ne 0 ] || cf "(b) the mover still accepts --role $role after process/ROLES was removed"
  origin_has_path "progress/todo/${ids[1]}-layer1.md" || cf "(b) the refused move changed the trunk's board"
  _rl_cb_flags_role "$role" || cf "(b) check-board does not report the [$role] commit once the layer is gone from the trunk"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'extended by process/ROLES and process/roles.d/' >/dev/null \
    && cf "(b) check-board still says its set was extended after the layer left the trunk"

  # (c) A FILE UNDER process/roles.d/, one per add-on: the same readers, the same removal.
  mkdir -p "$SB_WORK/process/roles.d"
  printf '# an add-on\n%s   the seat the add-on brings\n' "$role" > "$SB_WORK/process/roles.d/zebra"
  _rl_land "add the $role role by a roles.d file"
  _rl_hook "$role" || cf "(c) the hook refused [$role] after process/roles.d/zebra declared it"
  _rl_in_set "$role" || cf "(c) the library's set does not carry $role: $(_rl_set)"
  _rl_subtask_refuses_role "$role" && cf "(c) subtask.sh refused --role $role though a roles.d file declared it"
  _rl_mover "${ids[1]}" "$role"
  [ "$_rl_rc" -eq 0 ] || cf "(c) the mover refused --role $role though a roles.d file declared it (exit $_rl_rc): $_rl_out"
  _rl_cb_flags_role "$role" && cf "(c) check-board still reported a [$role] commit though a roles.d file declares it on the trunk"
  git -C "$SB_WORK" rm -q -f process/roles.d/zebra >/dev/null 2>&1
  _rl_land "remove the $role role's roles.d file"
  _rl_hook "$role" && cf "(c) the hook still accepts [$role] after its roles.d file was removed"
  _rl_subtask_refuses_role "$role" || cf "(c) subtask.sh still accepts --role $role after its roles.d file was removed"
  _rl_mover "${ids[2]}" "$role"
  [ "$_rl_rc" -ne 0 ] || cf "(c) the mover still accepts --role $role after its roles.d file was removed"
  _rl_cb_flags_role "$role" || cf "(c) check-board does not report the [$role] commit once the roles.d file is gone from the trunk"

  # (d) A LINE THAT WOULD BE A HOLE IN THE HOOK'S PATTERN ADDS NOTHING, so its role stays refused.
  mkdir -p "$SB_WORK/process"
  printf '%s\n' '# bad lines' 'Okapi   a seat' 'Bad|Tag   not a tag' "Quote'd   not a tag" > "$SB_WORK/process/ROLES"
  _rl_hook Okapi || cf "(d) the hook refused [Okapi], a well-formed line beside the malformed ones"
  _rl_hook Bad && cf "(d) the hook accepted [Bad] from the line 'Bad|Tag'"
  _rl_hook 'Bad|Tag' && cf "(d) the hook accepted a tag containing '|'"
  _rl_in_set 'Bad|Tag' && cf "(d) the library's set carries a tag containing '|': $(_rl_set)"
  _rl_in_set "Quote'd" && cf "(d) the library's set carries a tag containing a quote: $(_rl_set)"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A LAYER FILE WITH CRLF LINE ENDINGS IS READ.
#   A checkout with core.autocrlf writes them. A `\r` kept inside the tag makes the role silently
#   unreadable, with nothing to name the cause.
# =============================================================================
case_role_layer_files_with_crlf_lines_are_read() {
  cf_reset
  make_sandbox
  mkdir -p "$SB_WORK/process/roles.d"
  printf '# crlf\r\nWalrus   a seat\r\n' > "$SB_WORK/process/ROLES"
  printf 'Narwhal\r\n' > "$SB_WORK/process/roles.d/narwhal"
  _rl_hook Walrus || cf "the hook refused [Walrus], declared on a CRLF line of process/ROLES"
  _rl_hook Narwhal || cf "the hook refused [Narwhal], declared on a CRLF line of a roles.d file"
  _rl_in_set Walrus || cf "the library's set does not carry Walrus from a CRLF line: $(_rl_set)"
  _rl_in_set Narwhal || cf "the library's set does not carry Narwhal from a CRLF line: $(_rl_set)"
  # (control) the tag carries no `\r`: the set joins it to the next with a bare `|`.
  case "$(_rl_set)" in *$'\r'*) cf "(control) the library's set holds a carriage return: $(_rl_set | od -c | head -3 | tr '\n' ' ')" ;; esac
  finish "a tag declared on a CRLF line of process/ROLES or of a roles.d file is accepted by the hook and carried by the library without the carriage return"
  teardown
}

# =============================================================================
# CASE — AN UNREADABLE BASE STAYS EMPTY, WHATEVER THE LAYERS HOLD.
#   The hook's line is the one layer whose absence makes the whole set unreadable. A set of only
#   the additions would be read by every caller as the complete set, so it must come back empty
#   (callers treat empty as "could not read"). A library the hook cannot load leaves it enforcing
#   the base, never an accept-everything.
# =============================================================================
case_an_unreadable_base_leaves_the_role_set_empty_whatever_the_layers_hold() {
  cf_reset
  make_sandbox
  local hook="$SB_WORK/scripts/githooks/commit-msg" out
  mkdir -p "$SB_WORK/process/roles.d"
  printf 'Zebra\n' > "$SB_WORK/process/ROLES"
  printf 'Okapi\n' > "$SB_WORK/process/roles.d/okapi"
  # (control) with the base readable the layers are read; without that nothing below measures a base.
  if ! _rl_in_set Zebra; then
    cf "(control) the layers are not read with the hook present: $(_rl_set)"
    finish "an unreadable base leaves the role set empty whatever the layers hold"
    teardown; return
  fi

  # (a) the hook file is gone.
  mv "$hook" "$hook.away"
  [ -z "$(_rl_set)" ] || cf "(a) with the hook absent the library returned '$(_rl_set)' — the additions alone would be read as the complete set"
  # (b) the hook is there and holds no ROLE_PREFIXES line.
  grep -v '^ROLE_PREFIXES=' "$hook.away" > "$hook"; chmod +x "$hook"
  [ -z "$(_rl_set)" ] || cf "(b) with no ROLE_PREFIXES line the library returned '$(_rl_set)'"
  # (c) the operator-supplied check still has a set, and says it is the fallback, layers included.
  out="$( . "$SB_WORK/scripts/lib/role-set.sh"; kit_role_resolve "$SB_WORK" 'PM|Dev'; printf '%s;%s;%s' "$KIT_ROLE_SET" "${KIT_ROLE_DEFAULTED:-}" "$KIT_ROLE_SRC" )"
  [[ "$out" == "PM|Dev|Zebra|Okapi;1;THE KIT'S FALLBACK SET"* ]] \
    || cf "(c) kit_role_resolve over an unreadable base returned '$out' — expected the default, then the layers, marked defaulted and named as the fallback"
  rm -f "$hook"; mv "$hook.away" "$hook"

  # (d) the hook cannot load the library: it enforces the base alone.
  mv "$SB_WORK/scripts/lib/role-set.sh" "$SB_WORK/scripts/lib/role-set.sh.away"
  _rl_hook Dev || cf "(d) the hook refused a base role when the library could not load"
  _rl_hook Zebra && cf "(d) the hook accepted a layered role though the library that reads the layers could not load"
  _rl_hook NotARole && cf "(d) the hook accepted a tag in no layer when the library could not load — an accept-everything"
  mv "$SB_WORK/scripts/lib/role-set.sh.away" "$SB_WORK/scripts/lib/role-set.sh"

  finish "with the hook absent, or holding no ROLE_PREFIXES line, the library's set is empty while the layers are readable; kit_role_resolve then returns the caller's default plus the layers, marked defaulted; a hook that cannot load the library enforces the base alone"
  teardown
}

# =============================================================================
# CASE — process/ROLES SHIPS WITH NO ROLE LINE.
#   An upgrade adds the file where it is new. A populated copy would arrive beside the set a
#   project had stamped into the hook and widen it. The shipped file holds comments only. On a tree
#   whose copy the project has edited the case is N/A: the lines are the project's.
# =============================================================================
case_process_roles_ships_with_no_role_line() {
  cf_reset
  local L="process/ROLES, as the kit ships it, holds no role line (comments and blanks only), so an upgrade that adds it cannot widen the role set a project stamped"
  local f="$REAL_REPO_ROOT/process/ROLES" man="$REAL_REPO_ROOT/process/KIT-MANIFEST" want got n probe
  want="$(awk -F'  ' '!/^#/ && $2 == "process/ROLES" { print $1 }' "$man")"
  if [ -z "$want" ]; then
    cf "process/KIT-MANIFEST does not list process/ROLES, so the kit does not ship the file the role set's layers read"
    finish "$L"; return
  fi
  if [ ! -f "$f" ]; then skp_lived "$L" "process/ROLES is listed in process/KIT-MANIFEST but absent from this tree (process/EXTRACTION.md § 2.4 describes it)"; return; fi
  got="$(_old_sha "$f")"
  if [ -n "$got" ] && [ "$got" != "$want" ]; then
    skp_lived "$L" "process/ROLES differs from the sha256 in process/KIT-MANIFEST: the project has written its own role lines there (process/EXTRACTION.md § 2.4)"; return
  fi
  n="$(awk '{ sub(/#.*/, ""); if (NF) c++ } END { print c + 0 }' "$f")"
  [ "$n" -eq 0 ] || cf "the shipped process/ROLES holds $n role line(s); an upgrade would add them to the set a project stamped"
  # (control) the count can fail: a copy with a role line is counted.
  probe="$(mktemp "${TMPDIR:-/tmp}/roles-probe.XXXXXX")" || _fixture_die "case_process_roles_ships_with_no_role_line: no scratch file"
  printf '# comment\nOkapi   a seat\n' > "$probe"
  n="$(awk '{ sub(/#.*/, ""); if (NF) c++ } END { print c + 0 }' "$probe")"; rm -f "$probe"
  [ "$n" -eq 1 ] || cf "(control) the line count read $n for a file with one role line"
  finish "$L"
}

# =============================================================================
# CASE — A check-board.d ARM'S OUTPUT IS IN THE REPORT, AN ABSENT DIRECTORY IS A NO-OP, AND NO ARM
# CAN CHANGE THE EXIT OR END THE RUN.
#   The contract is process/contracts/drift-report.md § 5. Every status is driven: 0, 3, 1 (what a
#   `grep` that found nothing returns), another, and an arm that declares nothing. Expectations are
#   written out, never read back from the report they judge.
# =============================================================================
case_check_board_runs_check_board_d_arms_and_cannot_be_ended_by_one() {
  cf_reset
  make_sandbox
  publish_sandbox   # the report then reads origin/<trunk>, a tree other than the checkout the arms sit in
  local dir="$SB_WORK/scripts/check-board.d" out rc base_verdict verdict hdr filt keep

  # (a) ABSENT directory: no `[+` line, the exit is 0, the closing verdict line is there.
  rm -rf "$dir"
  out="$( cd "$SB_WORK" && env -u CLAUDE_PROJECT_DIR ./scripts/check-board.sh 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) check-board exited $rc with no check-board.d/ (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -F '[+' >/dev/null && cf "(a) a check-board.d header printed with no check-board.d/"
  base_verdict="$(printf '%s\n' "$out" | grep -E '^── board-drift: ' | head -1)"
  [ -n "$base_verdict" ] || cf "(a) (control) no closing verdict line in the baseline run: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  # The rows below compare against this baseline: a dirty one would leave every row that expects a
  # CHANGE green by accident.
  case "$base_verdict" in
    *clean*) : ;;
    *) _fixture_die "case_check_board_runs_check_board_d_arms_and_cannot_be_ended_by_one: the sandbox baseline verdict is not clean ('$base_verdict'), so no row below can show an arm moving it: $(printf '%s' "$out" | grep '⚠' | head -3 | tr '\n' '|')" ;;
  esac

  # (a2) an EMPTY directory, and a directory holding only a README or helpers, are the same no-op.
  mkdir -p "$dir"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F '[+' >/dev/null && cf "(a2) an empty check-board.d/ printed an arm header"
  printf '%s\n' '# not an arm' > "$dir/README.md"; printf 'echo SHOULD-NOT-RUN\n' > "$dir/helper.sh"; printf 'echo SHOULD-NOT-RUN\n' > "$dir/1-short.sh"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'SHOULD-NOT-RUN' >/dev/null && cf "(a2) a file that is not [0-9][0-9]-*.sh was run"
  rm -f "$dir/README.md" "$dir/helper.sh" "$dir/1-short.sh"

  # (b) two arms: both print, in FILE-NAME order, under their own header, with the operands the
  #     contract names; an arm that sets `drift` and moves away in its own subshell changes nothing.
  cat > "$dir/20-second.sh" <<'ARM'
# check-board-arm: advisory
echo "      second arm ran; tree=${CB_TREE:+set} root=${REPO_ROOT:+set} lib=${CB_LIB_DIR:+set} src=$(cb_src | head -1 | cut -c1-9)"
ARM
  cat > "$dir/10-first.sh" <<'ARM'
# check-board-arm: deciding
echo "      first arm ran"
drift=99; CB_TREE=/nonexistent; cd /
exit 0
ARM
  out="$( cb_run )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) check-board exited $rc with arms present (exit 0 ALWAYS)"
  printf '%s\n' "$out" | grep -F '[+first] arm (' >/dev/null || cf "(b) no header for the first arm: $(printf '%s' "$out" | tail -8 | tr '\n' '|')"
  printf '%s\n' "$out" | grep -F 'first arm ran' >/dev/null || cf "(b) the first arm's output is not in the report"
  printf '%s\n' "$out" | grep -F 'second arm ran; tree=set root=set lib=set src=read from' >/dev/null \
    || cf "(b) the second arm did not run, or did not receive CB_TREE/REPO_ROOT/CB_LIB_DIR/cb_src: $(printf '%s' "$out" | grep -F 'second arm' | head -2)"
  [ "$(printf '%s\n' "$out" | grep -nF '[+first]' | head -1 | cut -d: -f1)" -lt "$(printf '%s\n' "$out" | grep -nF '[+second]' | head -1 | cut -d: -f1)" ] \
    || cf "(b) the arms did not run in file-name order (10-first before 20-second)"
  verdict="$(printf '%s\n' "$out" | grep -E '^── board-drift: ' | head -1)"
  [ "$verdict" = "$base_verdict" ] \
    || cf "(b) an arm that set drift=99 in its own subshell changed the verdict line ('$verdict' vs '$base_verdict') — the arm ran in the parent's state"
  # The header carries `reports only` exactly when the arm declared itself advisory.
  hdr="$(printf '%s\n' "$out" | grep -F '[+second] arm (')"
  printf '%s\n' "$hdr" | grep -F 'reports only' >/dev/null || cf "(b) an ADVISORY arm's header lacks the 'reports only' token kit-init keys on: $hdr"
  hdr="$(printf '%s\n' "$out" | grep -F '[+first] arm (')"
  printf '%s\n' "$hdr" | grep -F 'reports only' >/dev/null && cf "(b) a DECIDING arm's header carries 'reports only', so kit-init would drop its findings: $hdr"

  # (c) status 3 from a DECIDING arm = findings that set the verdict line; the EXIT stays 0.
  printf '# check-board-arm: deciding\necho "      ⚠ a finding"\nexit 3\n' > "$dir/30-finding.sh"
  out="$( cb_run )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) check-board exited $rc when an arm returned 3 — no arm may change the exit"
  printf '%s\n' "$out" | grep -F '── board-drift: findings above' >/dev/null || cf "(c) a deciding arm's status 3 did not set the verdict line"
  printf '%s\n' "$out" | grep -F '[+second]' >/dev/null || cf "(c) an arm after a finding one did not run"

  # (c2) status 1 is NOT a finding, from either kind: it is what a `grep` that found nothing returns,
  #      so it is reported as an arm that did not run and the verdict stays as the other arms left it.
  rm -f "$dir/30-finding.sh"
  printf '# check-board-arm: deciding\ngrep -q zzz-no-such-text /dev/null\n' > "$dir/30-miss.sh"
  printf '# check-board-arm: advisory\nfalse\n' > "$dir/31-miss.sh"
  out="$( cb_run )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c2) check-board exited $rc when an arm ended on status 1"
  [ "$(printf '%s\n' "$out" | grep -E '^── board-drift: ' | head -1)" = "$base_verdict" ] \
    || cf "(c2) an arm that ended on an accidental status 1 moved the verdict line: $(printf '%s\n' "$out" | grep -E '^── board-drift: ')"
  printf '%s\n' "$out" | grep -F '30-miss.sh exited 1' >/dev/null || cf "(c2) a deciding arm's accidental status 1 is not reported as an arm that did not run"
  printf '%s\n' "$out" | grep -F '31-miss.sh exited 1' >/dev/null || cf "(c2) an advisory arm's status 1 is not reported as an arm that did not run"
  rm -f "$dir/30-miss.sh" "$dir/31-miss.sh"

  # (c3) an ADVISORY arm that signals findings reports them and never moves the verdict.
  printf '# check-board-arm: advisory\necho "      ⚠ only a note"\nexit 3\n' > "$dir/32-note.sh"
  out="$( cb_run )"
  [ "$(printf '%s\n' "$out" | grep -E '^── board-drift: ' | head -1)" = "$base_verdict" ] \
    || cf "(c3) an advisory arm's status 3 moved the verdict line"
  printf '%s\n' "$out" | grep -F 'only a note' >/dev/null || cf "(c3) the advisory arm's own line is not in the report"
  rm -f "$dir/32-note.sh"

  # (c4) an arm that declares neither is not run, and the report names the line to add.
  printf 'echo "      ⚠ UNDECLARED-RAN"\nexit 3\n' > "$dir/33-bare.sh"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'UNDECLARED-RAN' >/dev/null && cf "(c4) an arm that declares neither advisory nor deciding was run"
  printf '%s\n' "$out" | grep -F '33-bare.sh' | grep -F 'check-board-arm' >/dev/null || cf "(c4) the report does not name the declaration line the arm lacks: $(printf '%s' "$out" | grep -F '33-bare' | head -2)"
  printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(c4) the report names no next step for the undeclared arm"
  [ "$(printf '%s\n' "$out" | grep -E '^── board-drift: ' | head -1)" = "$base_verdict" ] || cf "(c4) an undeclared arm moved the verdict line"
  rm -f "$dir/33-bare.sh"

  # (c5) THROUGH THE REAL CONSUMER: kit-init's board self-check filter, read out of kit-init.sh now.
  #      A [+name] header starts a section like a [x] one does: a deciding arm after the advisory [t]
  #      arm keeps its findings (the advisory section does not carry over into it), and an advisory
  #      one is dropped.
  filt="$(awk '/KI_FINDINGS="\$\(printf/ { f = 1; next } f && /^[[:space:]]*'"'"' \| grep/ { exit } f { print }' "$SB_WORK/scripts/kit-init.sh")"
  [ -n "$filt" ] || _fixture_die "case_check_board_runs_check_board_d_arms_and_cannot_be_ended_by_one: could not extract kit-init's advisory filter (its KI_FINDINGS awk moved), so (c5) would test a copy."
  printf '# check-board-arm: deciding\necho "      ⚠ DECIDING-FINDING"\nexit 3\n' > "$dir/40-deciding.sh"
  printf '# check-board-arm: advisory\necho "      ⚠ ADVISORY-NOTE"\nexit 3\n' > "$dir/41-advisory.sh"
  printf '# check-board-arm: deciding\necho "      ⚠ SECOND-DECIDING"\nexit 3\n' > "$dir/42-deciding.sh"
  out="$( cb_run )"
  keep="$(printf '%s\n' "$out" | awk "$filt" | grep '⚠' || true)"
  printf '%s\n' "$keep" | grep -F 'DECIDING-FINDING' >/dev/null || cf "(c5) kit-init's filter dropped a deciding arm's finding (the [t] advisory section carried over into [+name]): $(printf '%s' "$keep" | head -3 | tr '\n' '|')"
  printf '%s\n' "$keep" | grep -F 'SECOND-DECIDING' >/dev/null || cf "(c5) kit-init's filter dropped a deciding arm that follows an advisory arm"
  printf '%s\n' "$keep" | grep -F 'ADVISORY-NOTE' >/dev/null && cf "(c5) kit-init's filter kept an advisory arm's line as a finding"
  rm -f "$dir/40-deciding.sh" "$dir/41-advisory.sh" "$dir/42-deciding.sh"

  # (c6) A CRLF CHECKOUT writes `\r` after the declaration; it is still read as the declaration.
  printf '# check-board-arm: advisory\r\necho "      CRLF-ARM-RAN"\r\n' > "$dir/43-crlf.sh"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'CRLF-ARM-RAN' >/dev/null || cf "(c6) an arm whose declaration line ends in a carriage return was not run: $(printf '%s' "$out" | grep -F '43-crlf' | head -2)"
  rm -f "$dir/43-crlf.sh"

  # (c7) a name outside letters, digits, `.`, `_` and `-` cannot head a section kit-init's filter and
  #      the session-start hook can find, so the arm is not run and the report says why.
  printf '# check-board-arm: deciding\necho "      ⚠ ODD-NAME-RAN"\nexit 3\n' > "$dir/35-odd name.sh"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'ODD-NAME-RAN' >/dev/null && cf "(c7) an arm whose name holds a space was run"
  printf '%s\n' "$out" | grep -F '35-odd name.sh' | grep -F 'did not run' >/dev/null || cf "(c7) the report does not say the oddly named arm did not run: $(printf '%s' "$out" | grep -F 'odd name' | head -2)"
  [ "$(printf '%s\n' "$out" | grep -E '^── board-drift: ' | head -1)" = "$base_verdict" ] || cf "(c7) an oddly named arm moved the verdict line"
  rm -f "$dir/35-odd name.sh"

  # (d) any other status = did not run, printed, never read as clean, exit still 0.
  printf '# check-board-arm: deciding\nexit 7\n' > "$dir/34-broken.sh"
  out="$( cb_run )"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) check-board exited $rc when an arm exited 7"
  printf '%s\n' "$out" | grep -F '34-broken.sh exited 7' >/dev/null || cf "(d) an arm that exited 7 is not reported as not having run"
  [ "$(printf '%s\n' "$out" | grep -E '^── board-drift: ' | head -1)" = "$base_verdict" ] \
    || cf "(d) a broken arm moved the verdict line — only a deciding arm's status 3 may"
  rm -f "$dir/34-broken.sh"

  # (e) ARMS COME FROM BESIDE THE SCRIPT, NEVER FROM THE TREE REPORTED ON: a file the trunk holds and
  #     the checkout does not is not run (the report reads the trunk's board; it must not execute it).
  printf '# check-board-arm: advisory\necho "      TRUNK-ONLY-RAN"\n' > "$dir/44-trunk-only.sh"
  git -C "$SB_WORK" add -A scripts/check-board.d >/dev/null 2>&1
  sbcommit -q -m "[Dev] $SB_PREFIX-001: an arm only the trunk holds" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  rm -f "$dir/44-trunk-only.sh"
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F 'TRUNK-ONLY-RAN' >/dev/null && cf "(e) an arm that only the trunk's tree holds was executed — arms must be read from beside the script"

  # (f) REMOVAL: the files go and the report is the baseline again.
  rm -f "$SB_WORK"/scripts/check-board.d/[0-9][0-9]-*.sh
  out="$( cb_run )"
  printf '%s\n' "$out" | grep -F '[+' >/dev/null && cf "(f) an arm header printed after every arm file was removed"

  finish "check-board.d/<NN>-<name>.sh arms declare themselves advisory or deciding (a CRLF declaration is read) and print under their own [+name] header (the advisory header carries the 'reports only' token), run in file-name order from beside the script with the operands the contract names in a subshell, a deciding arm's status 3 sets the verdict line and kit-init's own filter keeps it, status 1 and every other status is reported as an arm that did not run, an undeclared arm is not run, nothing changes check-board's exit, and an absent or empty directory is a no-op"
  teardown
}

# =============================================================================
# CASE — THE SESSIONSTART HOOK KEEPS A check-board.d ARM'S HEADING WHEN THE REPORT IS OVER BUDGET.
#   Past the budget the hook prints the arm headings and every finding line. A heading shaped
#   [+name] must count as one, or the line a finding sits under is lost.
# =============================================================================
case_session_start_keeps_a_check_board_d_arm_heading_past_the_budget() {
  cf_reset
  make_sandbox
  publish_sandbox
  local hook="$SB_WORK/scripts/hooks/session-start.sh" stub_root="$SB_TMP/stubroot-arm" i=0 out
  [ -f "$hook" ] || _fixture_die "case_session_start_keeps_a_check_board_d_arm_heading_past_the_budget: no scripts/hooks/session-start.sh in the sandbox"
  mkdir -p "$stub_root/scripts"
  {
    printf '#!/bin/sh\n'
    printf 'echo "[a] first arm — read from: origin/main:"\n'
    while [ "$i" -lt 400 ]; do printf 'echo "      filler line %s that a clean arm prints to explain itself at some length"\n' "$i"; i=$((i + 1)); done
    printf 'echo "[+zebra-arm] arm (scripts/check-board.d/50-zebra-arm.sh) — read from: origin/main:"\n'
    printf 'echo "      ⚠ ARM-FINDING-SENTINEL"\n'
    printf 'echo "── board-drift: findings above ⚠ (informational; exit 0 by convention)"\n'
  } > "$stub_root/scripts/check-board.sh"
  chmod +x "$stub_root/scripts/check-board.sh"
  out="$(CLAUDE_PROJECT_DIR="$stub_root" bash "$hook" 2>&1)" || true
  case "$out" in *"[+zebra-arm] arm"*) : ;; *) cf "an oversized report lost a [+name] arm heading: $(printf '%s' "$out" | tail -4 | tr '\n' '|' | cut -c1-240)" ;; esac
  case "$out" in *ARM-FINDING-SENTINEL*) : ;; *) cf "an oversized report lost a [+name] arm's finding line" ;; esac
  finish "an oversized report keeps a [+name] arm's heading and its finding line, with the verdict last"
  teardown
}

# =============================================================================
# CASE — THE QA GATE'S EVIDENCE KINDS ARE THE BUILT-IN ONES PLUS THE FILES UNDER
# process/evidence-kinds.d/ AT THE TRUNK, AND EVERY PLACE THAT NAMES THEM READS ONE FUNCTION.
#   A kind is added by a file and withdrawn by removing it; the built-in ones cannot be dropped. The
#   layers are read from the project at a revision, never from beside the library: the upgrade's
#   landing pre-check runs a staged COPY of the library, and a landing must not take its rule from
#   the branch it judges.
# =============================================================================
case_qa_gate_reads_its_evidence_kinds_from_one_function_at_the_trunk() {
  cf_reset
  make_sandbox
  local id="$SB_PREFIX-712" card="$SB_TMP/card.md" n=0 out rc kind="observation"
  local builtin='test file:line gate-diff fixture-diff artifact'

  seed_issue dev_complete "$id" kinds chore "Evidence kinds"
  publish_sandbox
  cp "$SB_WORK/progress/dev_complete/$id-kinds.md" "$card"
  # A second AC whose row carries the kind under test; AC1 stays the quoted `test` row the gate requires.
  perl -0pi -e 's/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — the second behaviour holds.\n/; s/(\| shadow-check )/| AC2 | PASS | observation | ARCHIVE.md:1 |\n$1/' "$card"
  grep -qF '| AC2 | PASS | observation | ARCHIVE.md:1 |' "$card" || _fixture_die "case_qa_gate_reads_its_evidence_kinds_from_one_function_at_the_trunk: the AC2 row was not planted"

  _qk_layer_commit() {  # commit whatever process/evidence-kinds.d now holds (added, changed or removed)
    git -C "$SB_WORK" add -A process >/dev/null 2>&1
    sbcommit -qm "[Dev] $id: the evidence-kind layers" >/dev/null 2>&1 || true
  }
  _qk_lib="scripts/lib"
  _qk_gate() {  # [<rev> [<trunk-rev>]] -> status of the gate on $card in $rc; output in $out; records by call
    n=$((n + 1))
    out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/rec-$n" bash -c '. "$1/refuse.sh"; . scripts/config.sh; . "$1/qa-gate.sh"; shift; kit_qa_verdict_check "$@"' _ "$_qk_lib" "$card" "$id" "$SB_WORK" "${1:-HEAD}" ${2:+"$2"} 2>&1 )"; rc=$?
  }
  _qk_refused_for_kind() { grep -q 'refusal=qa-verdict-evidence-missing' "$SB_TMP/rec-$n"/*.tsv 2>/dev/null; }
  _qk_kinds() { ( cd "$SB_WORK" && bash -c '. scripts/lib/refuse.sh; . scripts/lib/qa-gate.sh; kit_qa_evidence_kinds "$@"' _ "$@" ); }

  # (a) the kind is in no layer: refused on THAT rule, and the refusal's list is the built-in kinds.
  _qk_gate
  [ "$rc" -ne 0 ] || cf "(a) (control) a row of kind '$kind' passed with no layer naming it: $out"
  _qk_refused_for_kind || cf "(a) the refusal is not qa-verdict-evidence-missing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  printf '%s\n' "$out" | grep -F 'test|file:line|gate-diff|fixture-diff|artifact' >/dev/null \
    || cf "(a) the refusal does not list the built-in kinds: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  [ "$(_qk_kinds "$SB_WORK" HEAD)" = "$builtin" ] || cf "(a) with no layer the kinds are not the built-in ones: '$(_qk_kinds "$SB_WORK" HEAD)'"

  # (b) a layer file adds it: accepted — the whole gate passes, not merely the one rule.
  mkdir -p "$SB_WORK/process/evidence-kinds.d"
  printf '# an add-on\n%s   a human read the thing\n' "$kind" > "$SB_WORK/process/evidence-kinds.d/review"
  _qk_layer_commit
  _qk_gate
  [ "$rc" -eq 0 ] || cf "(b) a registered kind was refused (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"

  # (b2) the added kind is read like gate-diff: a path:line it carries must still resolve.
  perl -pi -e 's/\| AC2 \| PASS \| observation \| ARCHIVE.md:1 \|/| AC2 | PASS | observation | NO-SUCH-FILE.md:1 |/' "$card"
  _qk_gate
  [ "$rc" -ne 0 ] || cf "(b2) an added kind's unresolvable path:line passed"
  perl -pi -e 's/\| AC2 \| PASS \| observation \| NO-SUCH-FILE.md:1 \|/| AC2 | PASS | observation | ARCHIVE.md:1 |/' "$card"

  # (b3) EVERY PLACE THAT NAMES THE KINDS READS THE FUNCTION: the evidence refusal and the
  #      no-test-row refusal both list the added kind.
  perl -pi -e 's/\| AC2 \| PASS \| observation \|/| AC2 | PASS | vibes |/' "$card"
  _qk_gate
  printf '%s\n' "$out" | grep -F 'test|file:line|gate-diff|fixture-diff|artifact|observation' >/dev/null \
    || cf "(b3) the evidence refusal's list does not carry the added kind: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  perl -pi -e 's/\| AC2 \| PASS \| vibes \|/| AC2 | PASS | observation |/; s/\| AC1 \| PASS \| [^|]* \|/| AC1 | PASS | gate-diff |/' "$card"
  _qk_gate
  grep -q 'refusal=qa-verdict-no-observed' "$SB_TMP/rec-$n"/*.tsv 2>/dev/null \
    || cf "(b3) (control) a table with no test/file:line row was not refused as qa-verdict-no-observed: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$out" | grep -F 'one of gate-diff|fixture-diff|artifact|observation' >/dev/null \
    || cf "(b3) the no-test-row refusal's list does not carry the added kind: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-260)"
  cp "$SB_WORK/progress/dev_complete/$id-kinds.md" "$card"
  perl -0pi -e 's/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — the second behaviour holds.\n/; s/(\| shadow-check )/| AC2 | PASS | observation | ARCHIVE.md:1 |\n$1/' "$card"

  # (c) an UNKNOWN kind is still refused with a layer in force.
  perl -pi -e 's/\| AC2 \| PASS \| observation \|/| AC2 | PASS | vibes |/' "$card"
  _qk_gate
  [ "$rc" -ne 0 ] || cf "(c) an unlisted kind 'vibes' passed with '$kind' registered"
  _qk_refused_for_kind || cf "(c) the unlisted kind was not refused as qa-verdict-evidence-missing: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (c2) A CELL IS ONE KIND. Two listed kinds in one cell are two words, not a kind: matching the cell
  #      as a substring of the list would accept them AND skip the quote rule that binds `test`.
  local two
  for two in 'test file:line' 'gate-diff fixture-diff' 'observation test'; do
    perl -pi -e 'BEGIN { $w = shift @ARGV } s/\| AC2 \| PASS \| [^|]*? \|/| AC2 | PASS | $w |/' "$two" "$card"
    _qk_gate
    [ "$rc" -ne 0 ] || cf "(c2) a two-word kind cell '$two' passed the gate: $out"
    _qk_refused_for_kind || cf "(c2) '$two' was refused, but not on the evidence-kind rule: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  done
  perl -pi -e 's/\| AC2 \| PASS \| [^|]*? \|/| AC2 | PASS | observation |/' "$card"
  _qk_gate
  [ "$rc" -eq 0 ] || cf "(c2) (control) the restored single-kind row was refused: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (d) REMOVAL: the file goes and the kind is refused again.
  rm -f "$SB_WORK/process/evidence-kinds.d/review"
  _qk_layer_commit
  _qk_gate
  [ "$rc" -ne 0 ] || cf "(d) the kind was still accepted after its file was removed"
  _qk_refused_for_kind || cf "(d) refused, but not on the evidence-kind rule: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (e) THE LAYERS ARE READ FROM THE PROJECT AT THE REVISION, NOT FROM BESIDE THE LIBRARY. The
  #     upgrade's landing pre-check runs a staged COPY of this library from a scratch directory; it
  #     must still judge the project's own list. A layer the revision does not hold does not count,
  #     whatever the working tree beside it holds.
  printf '# an add-on\n%s\n' "$kind" > "$SB_WORK/process/evidence-kinds.d/review"
  _qk_layer_commit
  mkdir -p "$SB_TMP/staged"; cp -R "$SB_WORK/scripts/lib" "$SB_TMP/staged/lib"
  _qk_lib="$SB_TMP/staged/lib"
  _qk_gate
  [ "$rc" -eq 0 ] || cf "(e) the gate run from a COPY of the library elsewhere did not read the project's committed kind (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  mkdir -p "$SB_TMP/staged/process/evidence-kinds.d"; printf 'vibes\n' > "$SB_TMP/staged/process/evidence-kinds.d/planted"
  perl -pi -e 's/\| AC2 \| PASS \| observation \|/| AC2 | PASS | vibes |/' "$card"
  _qk_gate
  [ "$rc" -ne 0 ] || cf "(e) a kind file planted beside the staged copy of the library widened the gate"
  perl -pi -e 's/\| AC2 \| PASS \| vibes \|/| AC2 | PASS | observation |/' "$card"
  _qk_lib="scripts/lib"
  printf '# uncommitted\nvibes\n' > "$SB_WORK/process/evidence-kinds.d/local"
  perl -pi -e 's/\| AC2 \| PASS \| observation \|/| AC2 | PASS | vibes |/' "$card"
  _qk_gate
  [ "$rc" -ne 0 ] || cf "(e) an UNCOMMITTED kind file in the working tree widened the gate for the revision being landed"
  rm -f "$SB_WORK/process/evidence-kinds.d/local"
  perl -pi -e 's/\| AC2 \| PASS \| vibes \|/| AC2 | PASS | observation |/' "$card"

  # (e2) A LANDING TAKES THE KINDS FROM THE TRUNK, NOT FROM THE BRANCH IT JUDGES. A branch that adds a
  #      kind file widens nothing for itself; a branch cut before the trunk gained a kind is judged by
  #      the trunk's list.
  git -C "$SB_WORK" checkout -q -b side-branch >/dev/null 2>&1
  printf 'vibes\n' > "$SB_WORK/process/evidence-kinds.d/branch-only"
  git -C "$SB_WORK" add -A process >/dev/null 2>&1
  sbcommit -qm "[Dev] $id: a kind only the branch holds" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  perl -pi -e 's/\| AC2 \| PASS \| observation \|/| AC2 | PASS | vibes |/' "$card"
  _qk_gate side-branch "$SB_TRUNK"
  [ "$rc" -ne 0 ] || cf "(e2) a kind file added on the branch widened the gate for that branch's own landing"
  perl -pi -e 's/\| AC2 \| PASS \| vibes \|/| AC2 | PASS | observation |/' "$card"
  git -C "$SB_WORK" branch -q cut-before "$SB_TRUNK"~1 >/dev/null 2>&1
  _qk_gate cut-before "$SB_TRUNK"
  [ "$rc" -eq 0 ] || cf "(e2) a branch cut before the trunk gained the kind was refused though the trunk lists it (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  _qk_gate side-branch
  [ "$rc" -eq 0 ] || cf "(e2) with no trunk revision given the gate does not read the one revision it was given (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"

  # (f) the list itself: the built-in kinds live in code, so a file named process/EVIDENCE-KINDS is no
  #     layer and a project cannot drop `test` or `file:line`; a malformed line adds nothing; a CRLF
  #     line is read.
  rm -f "$SB_WORK/process/evidence-kinds.d/review" "$SB_WORK/process/evidence-kinds.d/branch-only"
  _qk_layer_commit
  [ "$(_qk_kinds "$SB_WORK" HEAD)" = "$builtin" ] || cf "(f) with no layer the kinds are not the built-in ones: '$(_qk_kinds "$SB_WORK" HEAD)'"
  printf '# only this\nreview-note   a human read\n' > "$SB_WORK/process/EVIDENCE-KINDS"
  _qk_layer_commit
  [ "$(_qk_kinds "$SB_WORK" HEAD)" = "$builtin" ] || cf "(f) a process/EVIDENCE-KINDS file changed the kinds (it must not be a layer): '$(_qk_kinds "$SB_WORK" HEAD)'"
  rm -f "$SB_WORK/process/EVIDENCE-KINDS"
  printf 'Bad Kind\nUPPER\n9lives\nok-kind\r\nb2\r\ntest\r\n# c\r\n' > "$SB_WORK/process/evidence-kinds.d/z"
  _qk_layer_commit
  [ "$(_qk_kinds "$SB_WORK" HEAD)" = "$builtin ok-kind b2" ] \
    || cf "(f) a malformed kind was not skipped, a CRLF line was not read, or a built-in kind was repeated (a kind opens with a lowercase letter, one word): '$(_qk_kinds "$SB_WORK" HEAD)'"
  # (f2) the layers are read at a revision only: no revision, or one that cannot be read, leaves the
  #      built-in kinds - never an empty list, never an accept-all, never the working tree.
  [ "$(_qk_kinds "$SB_WORK")" = "$builtin" ] \
    || cf "(f2) no revision did not give the built-in kinds: '$(_qk_kinds "$SB_WORK")'"
  [ "$(_qk_kinds "$SB_WORK" no-such-revision)" = "$builtin" ] \
    || cf "(f2) an unreadable revision did not fall back to the built-in kinds: '$(_qk_kinds "$SB_WORK" no-such-revision)'"
  rm -f "$SB_WORK/process/evidence-kinds.d/z"
  [ "$(_qk_kinds "$SB_WORK" HEAD)" = "$builtin ok-kind b2" ] \
    || cf "(f2) a layer file removed from the working tree only still changed the list read at a revision: '$(_qk_kinds "$SB_WORK" HEAD)'"

  finish "the QA gate's evidence kinds are the built-in ones plus every file under process/evidence-kinds.d/ at the trunk (a copy of the library elsewhere reads the project's, an uncommitted file and a branch's own file do not count, a CRLF line is read, an unreadable revision leaves the built-in kinds): an added kind is accepted by the whole gate and read like gate-diff, both refusals that name the kinds list it, an unlisted kind and a cell of two listed kinds are refused, removing the file refuses the kind again, and process/EVIDENCE-KINDS is no layer"
  teardown
}

# =============================================================================
# CASE — THE MARKER-BLOCK HELPER INSERTS, REPLACES AND REMOVES ONE NAMED BLOCK, IDEMPOTENTLY.
#   Insert is a no-op the second time (byte-equal); remove restores the ORIGINAL BYTES; a second
#   block and the text around it are never touched; a refusal writes nothing. The shipped files'
#   slots are what a block goes before, so they are checked here too.
# =============================================================================
case_marker_block_insert_is_idempotent_and_remove_restores_the_bytes() {
  cf_reset
  make_sandbox
  local d="$SB_TMP/mb" f rc out

  mkdir -p "$d"
  f="$d/shared.md"
  printf 'intro\n\n| h |\n|---|\n| r |\n\n<!-- KIT-MODULES:gates the slot -->\n\ntail\n' > "$f"
  cp "$f" "$d/original.md"
  printf '| Gate | C |\n|---|---|\n| g1 | c1 |\n' > "$d/one.txt"
  printf '| Gate | C |\n|---|---|\n| g1 | c1 |\n| g2 | c2 |\n' > "$d/one-v2.txt"
  printf '| Gate | C |\n|---|---|\n| h1 | d1 |\n' > "$d/two.txt"

  _mb() { ( . "$SB_WORK/scripts/lib/marker-block.sh"; "$@"; rc=$?; printf 'CHANGED=%s\n' "$KIT_MB_CHANGED"; exit "$rc" ) 2>&1; }

  # (a) insert: the block is before the slot, framed by its markers, followed by one blank line.
  out="$(_mb kit_mb_insert "$f" alpha gates "$d/one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) insert exited $rc: $out"
  printf '%s\n' "$out" | grep -x 'CHANGED=1' >/dev/null || cf "(a) the first insert did not report a change: $out"
  [ "$(grep -c -F '<!-- KIT-MODULE:alpha BEGIN -->' "$f")" = 1 ] && [ "$(grep -c -F '<!-- KIT-MODULE:alpha END -->' "$f")" = 1 ] \
    || cf "(a) the block's markers are not each present once"
  [ "$(grep -n -F '<!-- KIT-MODULE:alpha END -->' "$f" | cut -d: -f1)" -lt "$(grep -n -F '<!-- KIT-MODULES:gates' "$f" | cut -d: -f1)" ] \
    || cf "(a) the block is not before the slot"
  [ "$(sed -n "$(( $(grep -n -F '<!-- KIT-MODULE:alpha END -->' "$f" | cut -d: -f1) + 1 ))p" "$f")" = "" ] \
    || cf "(a) the block is not followed by one blank line"

  # (b) RE-INSERT of the same content is byte-equal and says it changed nothing.
  cp "$f" "$d/after-insert.md"
  out="$(_mb kit_mb_insert "$f" alpha gates "$d/one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) re-insert exited $rc: $out"
  cmp -s "$f" "$d/after-insert.md" || cf "(b) re-inserting the same block changed the file's bytes"
  printf '%s\n' "$out" | grep -x 'CHANGED=0' >/dev/null || cf "(b) the re-insert did not report CHANGED=0: $out"
  _mb kit_mb_has "$f" alpha >/dev/null || cf "(b) kit_mb_has does not see the block"
  _mb kit_mb_has "$f" nosuch >/dev/null && cf "(b) kit_mb_has sees a block that is not there"

  # (c) a CHANGED content replaces the block in place: one block, new rows, nothing else moved.
  out="$(_mb kit_mb_insert "$f" alpha gates "$d/one-v2.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) replace exited $rc: $out"
  grep -qF '| g2 | c2 |' "$f" || cf "(c) the new content is not in the file"
  [ "$(grep -c -F 'KIT-MODULE:alpha BEGIN' "$f")" = 1 ] || cf "(c) replacing left two blocks"

  # (d) a SECOND block sits beside the first and removing either leaves the other and the rest.
  out="$(_mb kit_mb_insert "$f" beta gates "$d/two.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) a second block's insert exited $rc: $out"
  out="$(_mb kit_mb_remove "$f" alpha)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(d) removing alpha exited $rc: $out"
  grep -qF 'KIT-MODULE:beta BEGIN' "$f" && grep -qF '| h1 | d1 |' "$f" || cf "(d) removing alpha took beta's block with it"
  grep -qF 'KIT-MODULE:alpha' "$f" && cf "(d) alpha's markers survived its removal"

  # (e) REMOVE restores the ORIGINAL BYTES once every block is gone, and a repeat remove is a no-op.
  out="$(_mb kit_mb_remove "$f" beta)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) removing beta exited $rc: $out"
  cmp -s "$f" "$d/original.md" || cf "(e) insert-then-remove did not restore the original bytes: $(diff "$d/original.md" "$f" | head -4 | tr '\n' '|')"
  out="$(_mb kit_mb_remove "$f" beta)"; rc=$?
  [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -x 'CHANGED=0' >/dev/null || cf "(e) removing an absent block was not a clean no-op: rc=$rc $out"
  cmp -s "$f" "$d/original.md" || cf "(e) a no-op remove changed the file"

  # (e2) ONE NAME, SEVERAL SLOTS: the id may carry `:<slot>`, so one name holds a block in each.
  out="$(_mb kit_mb_insert "$f" alpha:one gates "$d/one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e2) inserting alpha:one exited $rc: $out"
  out="$(_mb kit_mb_insert "$f" alpha:two gates "$d/two.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e2) inserting alpha:two exited $rc: $out"
  _mb kit_mb_has "$f" alpha:one >/dev/null && _mb kit_mb_has "$f" alpha:two >/dev/null || cf "(e2) the two blocks of one name are not both present"
  _mb kit_mb_remove "$f" alpha:one >/dev/null; _mb kit_mb_remove "$f" alpha:two >/dev/null
  cmp -s "$f" "$d/original.md" || cf "(e2) removing both blocks of one name did not restore the original bytes"

  # (f) REFUSALS write nothing and name a next step: no slot, a lone marker, a bad name, no newline.
  out="$(_mb kit_mb_insert "$f" alpha nosuchslot "$d/one.txt")"; rc=$?
  [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(f) a missing slot was not refused with a Next: line: rc=$rc $out"
  cmp -s "$f" "$d/original.md" || cf "(f) the refused insert still wrote the file"
  printf '<!-- KIT-MODULE:lone BEGIN -->\nstray\n<!-- KIT-MODULES:gates x -->\n' > "$d/lone.md"; cp "$d/lone.md" "$d/lone.orig"
  out="$(_mb kit_mb_insert "$d/lone.md" lone gates "$d/one.txt")"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f) a lone BEGIN marker was accepted: $out"
  out="$(_mb kit_mb_remove "$d/lone.md" lone)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f) removing a lone BEGIN marker was accepted: $out"
  cmp -s "$d/lone.md" "$d/lone.orig" || cf "(f) a refused call modified the lone-marker file"
  out="$(_mb kit_mb_insert "$f" 'Bad Name' gates "$d/one.txt")"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f) a name with a space and capitals was accepted"
  printf 'no newline at the end' > "$d/nonl.md"
  out="$(_mb kit_mb_remove "$d/nonl.md" alpha)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f) a file with no final newline was accepted"
  [ "$(cat "$d/nonl.md")" = 'no newline at the end' ] || cf "(f) a refused call modified the no-newline file"

  # (f2) the slot is matched as a WORD: `gates` does not take a `gates-extra` slot line, and the content
  #      may not carry a marker or slot line of its own (it would leave a file every later call refuses).
  printf 'x\n\n<!-- KIT-MODULES:gates-extra other -->\n\n<!-- KIT-MODULES:gates the real slot -->\n\ntail\n' > "$d/slots.md"
  out="$(_mb kit_mb_insert "$d/slots.md" alpha gates "$d/one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f2) inserting into a slot that shares a prefix with another exited $rc: $out"
  [ "$(grep -n -F 'KIT-MODULE:alpha END' "$d/slots.md" | cut -d: -f1)" -gt "$(grep -n -F 'KIT-MODULES:gates-extra' "$d/slots.md" | cut -d: -f1)" ] \
    || cf "(f2) the block went before the 'gates-extra' slot: slot 'gates' matched a longer slot name"
  printf 'row\n<!-- KIT-MODULE:inner END -->\n' > "$d/bad-content.txt"; cp "$f" "$d/before-bad.md"
  out="$(_mb kit_mb_insert "$f" inner gates "$d/bad-content.txt")"; rc=$?
  [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(f2) content carrying a marker line was accepted, or refused with no Next: line: rc=$rc $out"
  cmp -s "$f" "$d/before-bad.md" || cf "(f2) the refused content still wrote the file"
  printf '<!-- KIT-MODULES:gates a slot of its own -->\n' > "$d/slot-content.txt"
  out="$(_mb kit_mb_insert "$f" inner gates "$d/slot-content.txt")"; rc=$?
  [ "$rc" -ne 0 ] || cf "(f2) content carrying a slot line was accepted: $out"

  # (f3) a FILE MODE survives a write (the bytes go to a copy made beside the file and are moved over it).
  cp "$d/original.md" "$d/mode.md"; chmod 750 "$d/mode.md"
  out="$(_mb kit_mb_insert "$d/mode.md" alpha gates "$d/one.txt")"; rc=$?
  [ "$rc" -eq 0 ] && [ -x "$d/mode.md" ] || cf "(f3) an insert changed the file's executable bit or failed: rc=$rc $out"

  # (f4) CRLF: a file that already holds a block (a Windows checkout) is found, not duplicated; a
  #      re-insert is a no-op; removal takes it; a plain CRLF file takes a block in ITS line endings;
  #      every other byte stays.
  local crlf="$d/crlf.md"
  printf 'intro\r\n\r\n<!-- KIT-MODULES:gates the slot -->\r\n\r\ntail\r\n' > "$crlf"; cp "$crlf" "$d/crlf.orig"
  out="$(_mb kit_mb_insert "$crlf" alpha gates "$d/one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f4) insert into a CRLF file exited $rc: $out"
  [ "$(grep -c -F 'KIT-MODULE:alpha BEGIN' "$crlf")" = 1 ] || cf "(f4) the block is not present once in the CRLF file"
  [ "$(grep -c $'\r$' "$crlf")" = "$(wc -l < "$crlf" | tr -d ' ')" ] \
    || cf "(f4) the lines written into a CRLF file are not CRLF: $(od -c "$crlf" | head -3 | tr '\n' '|')"
  cp "$crlf" "$d/crlf.once"
  _mb kit_mb_has "$crlf" alpha >/dev/null || cf "(f4) kit_mb_has does not see a block in a CRLF file"
  out="$(_mb kit_mb_insert "$crlf" alpha gates "$d/one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f4) re-insert into a CRLF file exited $rc: $out"
  cmp -s "$crlf" "$d/crlf.once" || cf "(f4) re-inserting into a CRLF file that already held the block changed it (a second block above the slot?): $(grep -c -F 'KIT-MODULE:alpha BEGIN' "$crlf") BEGIN line(s)"
  printf '%s\n' "$out" | grep -x 'CHANGED=0' >/dev/null || cf "(f4) the CRLF re-insert did not report CHANGED=0: $out"
  out="$(_mb kit_mb_insert "$crlf" alpha gates "$d/one-v2.txt")"; rc=$?
  [ "$rc" -eq 0 ] && [ "$(grep -c -F 'KIT-MODULE:alpha BEGIN' "$crlf")" = 1 ] && grep -qF '| g2 | c2 |' "$crlf" \
    || cf "(f4) replacing a block in a CRLF file failed or duplicated it: rc=$rc"
  out="$(_mb kit_mb_remove "$crlf" alpha)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(f4) remove from a CRLF file exited $rc: $out"
  cmp -s "$crlf" "$d/crlf.orig" || cf "(f4) removing from a CRLF file did not restore its bytes: $(grep -c -F 'KIT-MODULE:alpha' "$crlf") marker line(s) left"

  # (g) the SHIPPED files carry the slots a block goes before, and the round trip is exact on them.
  local shipped slot lived
  lived="$(_tree_has_lived)"   # a tree that finished day one owns these files; their shape is its own
  for shipped in "PROJECT.md gates" "requirements/CORPUS.md corpus-manifest" "requirements/CORPUS.md corpus-buckets"; do
    f="$REAL_REPO_ROOT/${shipped% *}"; slot="${shipped#* }"
    if [ ! -f "$f" ] || [ -n "$lived" ]; then continue; fi
    grep -qE "^<!-- KIT-MODULES:${slot}( |-->)" "$f" || { cf "(g) ${shipped% *} carries no '<!-- KIT-MODULES:${slot}' slot line"; continue; }
    cp "$f" "$d/ship.md"; cp "$d/ship.md" "$d/ship.orig"
    out="$(_mb kit_mb_insert "$d/ship.md" probe "$slot" "$d/one.txt")"; rc=$?
    [ "$rc" -eq 0 ] || cf "(g) inserting into ${shipped% *}'s $slot slot exited $rc: $out"
    out="$(_mb kit_mb_remove "$d/ship.md" probe)"
    cmp -s "$d/ship.md" "$d/ship.orig" || cf "(g) ${shipped% *}: insert then remove did not restore the shipped bytes"
  done

  finish "the marker-block helper inserts a block before the file's slot, re-inserting the same content is byte-equal and reports CHANGED=0, new content replaces in place, two blocks are independent (one name may hold a block in each of several slots), removing every block restores the original bytes exactly (and again is a no-op), a CRLF file keeps its endings, every refusal writes nothing and names a next step, and PROJECT.md's and CORPUS.md's shipped slots take a block and give it back byte for byte"
  teardown
}

# =============================================================================
# CASE — A .gitignore BLOCK GOES AT THE END OF THE FILE IN # COMMENTS, AND A FILE THE INSERT CREATED
# IS DELETED WHEN ITS LAST BLOCK GOES.
#   .gitignore has no slot line and no place for an HTML comment (`<!--` there is a pattern). Proved
#   through git itself: the block's pattern ignores a path while the block is there and stops when
#   it is gone.
# =============================================================================
case_marker_block_gitignore_block_goes_at_the_end_and_a_created_file_is_removed() {
  cf_reset
  make_sandbox
  local d="$SB_TMP/mbi" rc out
  mkdir -p "$d"; git -C "$d" init -q >/dev/null 2>&1 || _fixture_die "case_marker_block_gitignore_block_goes_at_the_end_and_a_created_file_is_removed: git init failed"
  printf 'zebra-cache/\n*.zebra\n' > "$d/ignore-one.txt"
  printf '*.okapi\n' > "$d/ignore-two.txt"
  _mb() { ( . "$SB_WORK/scripts/lib/marker-block.sh"; "$@"; rc=$?; printf 'CHANGED=%s\n' "$KIT_MB_CHANGED"; exit "$rc" ) 2>&1; }
  _ignored() { git -C "$d" check-ignore -q "$1"; }

  # (a) the file does not exist: it is created, the pattern takes effect, and removal deletes the file.
  rm -f "$d/.gitignore"
  out="$(_mb kit_mb_insert "$d/.gitignore" alpha:gitignore gitignore "$d/ignore-one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) inserting into an absent .gitignore exited $rc: $out"
  _ignored a.zebra || cf "(a) the block's pattern ignores nothing: $(cat "$d/.gitignore" 2>/dev/null | tr '\n' '|')"
  grep -qF '<!--' "$d/.gitignore" && cf "(a) the block holds an HTML comment, which .gitignore reads as a pattern"
  grep -qxF '# KIT-MODULE:alpha:gitignore BEGIN' "$d/.gitignore" && grep -qxF '# KIT-MODULE:alpha:gitignore END' "$d/.gitignore" \
    || cf "(a) the block is not framed by # comment markers: $(cat "$d/.gitignore" | tr '\n' '|')"
  _mb kit_mb_has "$d/.gitignore" alpha:gitignore >/dev/null || cf "(a) kit_mb_has does not see the block"
  out="$(_mb kit_mb_remove "$d/.gitignore" alpha:gitignore)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(a) removing the only block exited $rc: $out"
  [ ! -e "$d/.gitignore" ] || cf "(a) the file the insert created survived its last block's removal"
  _ignored a.zebra && cf "(a) the pattern still ignores a path after the block went"

  # (b) an existing file: the block is appended AFTER its lines (which stay byte for byte) and removal restores them.
  printf 'node_modules/\n*.log\n' > "$d/.gitignore"; cp "$d/.gitignore" "$d/gitignore.orig"
  out="$(_mb kit_mb_insert "$d/.gitignore" alpha:gitignore gitignore "$d/ignore-one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) inserting into an existing .gitignore exited $rc: $out"
  [ "$(head -2 "$d/.gitignore")" = "$(head -2 "$d/gitignore.orig")" ] || cf "(b) the file's own lines moved"
  [ "$(grep -n -F 'KIT-MODULE:alpha:gitignore BEGIN' "$d/.gitignore" | cut -d: -f1)" = 3 ] || cf "(b) the block does not start on the line after the file's last: $(cat "$d/.gitignore" | tr '\n' '|')"
  _ignored x.zebra && _ignored y.log || cf "(b) the block's pattern, or the file's own, ignores nothing"
  cp "$d/.gitignore" "$d/gitignore.once"
  out="$(_mb kit_mb_insert "$d/.gitignore" alpha:gitignore gitignore "$d/ignore-one.txt")"; rc=$?
  cmp -s "$d/.gitignore" "$d/gitignore.once" && printf '%s\n' "$out" | grep -x 'CHANGED=0' >/dev/null || cf "(b) a re-insert of the same block changed the file or did not report CHANGED=0: rc=$rc $out"
  out="$(_mb kit_mb_insert "$d/.gitignore" beta:gitignore gitignore "$d/ignore-two.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(b) a second block exited $rc: $out"
  _ignored z.okapi || cf "(b) the second block's pattern ignores nothing"
  out="$(_mb kit_mb_remove "$d/.gitignore" alpha:gitignore)"
  _ignored x.zebra && cf "(b) removing alpha left its pattern in force"
  _ignored z.okapi || cf "(b) removing alpha took beta's block with it"
  out="$(_mb kit_mb_remove "$d/.gitignore" beta:gitignore)"
  cmp -s "$d/.gitignore" "$d/gitignore.orig" || cf "(b) insert-then-remove did not restore the file's bytes: $(diff "$d/gitignore.orig" "$d/.gitignore" | head -4 | tr '\n' '|')"

  # (c) CRLF: the block takes the file's line endings and restores its bytes.
  printf 'build/\r\n*.tmp\r\n' > "$d/.gitignore"; cp "$d/.gitignore" "$d/gitignore.crlf"
  out="$(_mb kit_mb_insert "$d/.gitignore" alpha:gitignore gitignore "$d/ignore-one.txt")"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) inserting into a CRLF .gitignore exited $rc: $out"
  [ "$(grep -c $'\r$' "$d/.gitignore")" = "$(wc -l < "$d/.gitignore" | tr -d ' ')" ] || cf "(c) the lines written into a CRLF .gitignore are not CRLF"
  out="$(_mb kit_mb_insert "$d/.gitignore" alpha:gitignore gitignore "$d/ignore-one.txt")"
  printf '%s\n' "$out" | grep -x 'CHANGED=0' >/dev/null || cf "(c) re-inserting into a CRLF .gitignore changed it: $out"
  out="$(_mb kit_mb_remove "$d/.gitignore" alpha:gitignore)"
  cmp -s "$d/.gitignore" "$d/gitignore.crlf" || cf "(c) removing from a CRLF .gitignore did not restore its bytes"

  # (d) refusals: a file with no final newline is not appended to (the library would add one to its
  #     last line), and the file is not changed.
  printf 'node_modules/' > "$d/.gitignore"
  out="$(_mb kit_mb_insert "$d/.gitignore" alpha:gitignore gitignore "$d/ignore-one.txt")"; rc=$?
  [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F 'Next:' >/dev/null || cf "(d) a .gitignore with no final newline was accepted, or refused with no Next: line: rc=$rc $out"
  [ "$(cat "$d/.gitignore")" = 'node_modules/' ] || cf "(d) the refused insert still wrote the file"

  finish "a .gitignore block is appended at the end of the file in # comments (never an HTML comment), the pattern takes effect through git itself and stops when the block goes, a file the insert created is deleted with its last block, an existing file's bytes are restored exactly (CRLF included), and a file with no final newline is refused unchanged"
  teardown
}

# =============================================================================
# CASE — A TEMPLATE FRAGMENT IS MINTED INTO A NEW PRD OR CARD ONLY WHILE ITS FILE IS THERE, AND A
# PROJECT WITH NONE HAS NO TRACE OF THE SLOT.
#   The fragments are files under process/fragments.d/<template>/: <name>.frontmatter, <name>.body-end
#   and <name>.slot-<slot>. The core PRD template owns one slot (story-fields), a line the mint
#   always removes. The proof of "no trace" is a comparison of bytes: the PRD minted with nothing
#   enabled equals the PRD minted from the template with the slot line deleted, and the PRD minted
#   again after a fragment is withdrawn equals the first.
# =============================================================================
_tf_files="" _tf_n=0 _tf_out="" _tf_rc=0
_tf_mint() {  # prd <slug> | issue <slug> <id> -> status in _tf_rc, output in _tf_out; the new file in _tf_files
  _tf_n=$((_tf_n + 1)); _tf_rc=0
  case "$1" in
    prd)   _tf_out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/tf-rec-$_tf_n" ./scripts/new-prd.sh "$2" 2>&1 )" || _tf_rc=$? ;;
    issue) _tf_out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/tf-rec-$_tf_n" ./scripts/new-issue.sh "$2" --id "$3" 2>&1 )" || _tf_rc=$? ;;
  esac
}
_tf_refused_for() { grep -q "refusal=$1" "$SB_TMP/tf-rec-$_tf_n"/*.tsv 2>/dev/null; }
_tf_listing() { ls -A "$SB_WORK/requirements" "$SB_WORK/progress/todo" 2>/dev/null; }

case_a_template_fragment_is_minted_only_when_enabled_and_is_byte_absent_when_not() {
  cf_reset
  local L="a fragment under process/fragments.d/ is minted into a new PRD and card (frontmatter, body end, and the PRD's story-fields slot) only while its file is there; with none the minted bytes equal those of a template without the slot line; a bad fragment is refused with a Next: line and mints nothing"
  if ! has_issue_template || [ ! -f "$REAL_REPO_ROOT/.claude/templates/PRD.template.md" ]; then skp "$L" "$ISSUE_TEMPLATE_ABSENT, or .claude/templates/PRD.template.md absent"; return; fi
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates" "$SB_WORK/requirements"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  publish_sandbox
  local tpl="$SB_WORK/.claude/templates/PRD.template.md" real="$SB_TMP/PRD.template.real" fd="$SB_WORK/process/fragments.d"
  local id="$SB_PREFIX-901" prd="" card="" base_prd="$SB_TMP/prd-none.md" base_card="$SB_TMP/card-none.md" with_prd="$SB_TMP/prd-with.md" with_card="$SB_TMP/card-with.md"
  cp "$tpl" "$real"

  _tf_mint_now() {  # mint a PRD and a card under fixed slugs; copy them to $1 and $2; remove both
    local pf cf2
    _tf_mint prd probe; pf="$(probe_pick "$SB_WORK/requirements" -name 'PRD-*-probe.md')" || true
    _tf_prd_rc=$_tf_rc; _tf_prd_out="$_tf_out"
    _tf_mint issue probe "$id"; cf2="$SB_WORK/progress/todo/$id-probe.md"
    [ -f "$pf" ] && cp "$pf" "$1" || : > "$1"
    [ -f "$cf2" ] && cp "$cf2" "$2" || : > "$2"
    rm -f "$pf" "$cf2"
  }
  local _tf_prd_rc=0 _tf_prd_out=""

  # (control) the shipped template carries the slot line exactly once, in the story block.
  if [ "$(grep -c '^<!-- KIT-MODULES:story-fields' "$real")" -ne 1 ]; then
    cf "(control) PRD.template.md carries $(grep -c '^<!-- KIT-MODULES:story-fields' "$real") story-fields slot line(s), not one — the premise of every comparison below"
    finish "$L"; teardown; return
  fi

  # (a) NOTHING ENABLED: no trace of the slot, and the bytes are those of a template with no slot line.
  _tf_mint_now "$base_prd" "$base_card"
  [ "$_tf_prd_rc" -eq 0 ] && [ -s "$base_prd" ] || _fixture_die "${FUNCNAME[0]}: new-prd.sh refused a plain mint (exit $_tf_prd_rc): $(printf '%s' "$_tf_prd_out" | tr '\n' '|' | cut -c1-200)"
  [ -s "$base_card" ] || _fixture_die "${FUNCNAME[0]}: new-issue.sh refused a plain mint: $(printf '%s' "$_tf_out" | tr '\n' '|' | cut -c1-200)"
  grep -F 'KIT-MODULES' "$base_prd" "$base_card" >/dev/null && cf "(a) a minted file still carries a KIT-MODULES slot line"
  grep -F 'story-fields' "$base_prd" "$base_card" >/dev/null && cf "(a) a minted file still names the story-fields slot"
  grep -v '^<!-- KIT-MODULES:story-fields' "$real" > "$tpl"
  _tf_mint_now "$SB_TMP/prd-stripped.md" "$SB_TMP/card-stripped.md"
  cmp -s "$base_prd" "$SB_TMP/prd-stripped.md" \
    || cf "(a) the PRD minted with nothing enabled differs from the PRD minted from a template with no slot line: $(diff "$SB_TMP/prd-stripped.md" "$base_prd" | head -4 | tr '\n' '|')"
  cp "$real" "$tpl"

  # (b) ENABLED: two add-ons' files. The fragments land where their mode says, and in file-name order.
  mkdir -p "$fd/PRD" "$fd/ISSUE"
  printf '**Probe:** none\n' > "$fd/PRD/probe.slot-story-fields"
  printf 'probe_flag: yes\n' > "$fd/PRD/probe.frontmatter"
  printf 'aaa_flag: first\n' > "$fd/PRD/aaa.frontmatter"
  printf '## Probe notes\n\nPROBE-BODY-END\n' > "$fd/PRD/probe.body-end"
  printf 'probe_card: yes\n' > "$fd/ISSUE/probe.frontmatter"
  printf 'PROBE-ISSUE-END\n' > "$fd/ISSUE/probe.body-end"
  printf 'PROBE-README-MUST-NOT-APPEAR\n' > "$fd/PRD/README.md"
  _tf_mint_now "$with_prd" "$with_card"
  [ "$_tf_prd_rc" -eq 0 ] && [ -s "$with_prd" ] || cf "(b) new-prd.sh refused an enabled fragment (exit $_tf_prd_rc): $(printf '%s' "$_tf_prd_out" | tr '\n' '|' | cut -c1-240)"
  [ -s "$with_card" ] || cf "(b) new-issue.sh refused an enabled fragment: $(printf '%s' "$_tf_out" | tr '\n' '|' | cut -c1-240)"
  grep -F 'KIT-MODULES' "$with_prd" "$with_card" >/dev/null && cf "(b) a slot line survived into a minted file"
  grep -F 'PROBE-README' "$with_prd" >/dev/null && cf "(b) a README.md in the fragment directory was minted as a fragment"
  [ "$(grep -c -F '**Probe:** none' "$with_prd")" -eq 1 ] || cf "(b) the slot fragment is not in the PRD exactly once"
  awk '/^##### F1-S1 /{h=NR} h && NR==h+1 && $0!="" {bad=1} /^\*\*Probe:\*\* none$/{p=NR} p && NR==p+1 && $0!="" {bad=1} p && NR==p+2 && $0 !~ /^\*\*Acceptance Criteria\*\*/ {bad=1} END{exit (p && h && p==h+2 && !bad) ? 0 : 1}' "$with_prd" \
    || cf "(b) the slot fragment is not placed as: story heading, blank line, fragment, blank line, **Acceptance Criteria**"
  awk '$0=="---"{n++; next} n==1 && /^aaa_flag: first$/{a=NR} n==1 && /^probe_flag: yes$/{b=NR} END{exit (a && b && a<b && n>=2) ? 0 : 1}' "$with_prd" \
    || cf "(b) the PRD's frontmatter fragments are not both inside the frontmatter in file-name order"
  [ "$(tail -1 "$with_prd")" = "PROBE-BODY-END" ] || cf "(b) the PRD's body-end fragment is not the last text of the file: $(tail -1 "$with_prd")"
  [ "$(tail -4 "$with_prd" | sed -n 1p)" = "" ] || cf "(b) no blank line separates the PRD's body-end fragment from what precedes it"
  awk '$0=="---"{n++; next} n==1 && /^probe_card: yes$/{a=1} END{exit (a && n>=2) ? 0 : 1}' "$with_card" || cf "(b) the card's frontmatter fragment is not inside its frontmatter"
  awk '/^PROBE-ISSUE-END$/{p=NR} /^## Activity$/{a=NR} END{exit (p && a && a==p+2) ? 0 : 1}' "$with_card" \
    || cf "(b) the card's body-end fragment is not placed one blank line above the ## Activity heading"
  awk '/^## /{l=$0} END{exit (l=="## Activity") ? 0 : 1}' "$with_card" || cf "(b) ## Activity is no longer the card's last section"
  grep -q "^- $(date +%Y-%m-%d) \[" "$with_card" || cf "(b) the seed Activity entry is gone from the card"

  # (c) WITHDRAWN: remove the files and the minted bytes are the first mint's again.
  rm -rf "$fd"
  _tf_mint_now "$SB_TMP/prd-again.md" "$SB_TMP/card-again.md"
  cmp -s "$base_prd" "$SB_TMP/prd-again.md" || cf "(c) the PRD minted after the fragments were withdrawn differs from the first: $(diff "$base_prd" "$SB_TMP/prd-again.md" | head -4 | tr '\n' '|')"
  cmp -s "$base_card" "$SB_TMP/card-again.md" || cf "(c) the card minted after the fragments were withdrawn differs from the first: $(diff "$base_card" "$SB_TMP/card-again.md" | head -4 | tr '\n' '|')"

  # (d) REFUSALS name a Next: line, record their rule id and leave the directories as they were.
  local before after name rule
  _tf_bad() {  # <file under fragments.d> <content> <expected rule id> <label> [issue]
    mkdir -p "$fd/$(dirname "$1")"; printf '%s\n' "$2" > "$fd/$1"
    before="$(_tf_listing)"
    if [ "${5:-}" = issue ]; then _tf_mint issue probe "$id"; else _tf_mint prd probe; fi
    after="$(_tf_listing)"
    [ "$_tf_rc" -ne 0 ] || cf "(d) $4: the mint was not refused"
    printf '%s\n' "$_tf_out" | grep '^Next:' >/dev/null || cf "(d) $4: the refusal carries no Next: line: $(printf '%s' "$_tf_out" | tr '\n' '|' | cut -c1-200)"
    _tf_refused_for "$3" || cf "(d) $4: no refusal=$3 record: $(printf '%s' "$_tf_out" | tr '\n' '|' | cut -c1-200)"
    [ "$before" = "$after" ] || cf "(d) $4: the refused mint left files behind: $(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | tr '\n' '|' | cut -c1-200)"
    rm -rf "$fd"
  }
  _tf_bad PRD/probe.slot-no-such-slot 'text' fragment-slot-missing "a slot the template does not carry"
  _tf_bad ISSUE/probe.slot-story-fields 'text' fragment-slot-missing "a slot fragment for a template with no slots" issue
  _tf_bad PRD/probe.weird 'text' fragment-name-unknown "a file name that is no mode"
  _tf_bad PRD/Probe.body-end 'text' fragment-name-unknown "an add-on name that is not lowercase"
  _tf_bad PRD/probe.body-end '<!-- KIT-MODULES:story-fields leaked -->' fragment-content-markers "a fragment that carries a slot line of its own"
  printf '# PRD-NNN — frontmatter-less\n\nbody\n' > "$tpl"
  _tf_bad PRD/probe.frontmatter 'probe_flag: yes' fragment-frontmatter-missing "a frontmatter fragment for a template with no frontmatter"
  cp "$real" "$tpl"

  finish "a fragment under process/fragments.d/<template>/ is minted into a new PRD (frontmatter in file-name order, the story-fields slot between the heading and the criteria, body end last) and a new card (frontmatter, body end above ## Activity) only while its file is there; the PRD minted with nothing enabled has the bytes of a template with no slot line, and the same bytes again once the files are withdrawn; a slot the template lacks, an unknown name, a fragment carrying a slot line and a frontmatter fragment for a template with none are each refused with a Next: line, a rule id and nothing minted"
  teardown
}

# =============================================================================
# CASE — A MOVE CHECK ON THE TRUNK REFUSES A TRANSITION WITH A NEXT: LINE AND CHANGES NOTHING.
#   A check is scripts/move-check.d/<target folder>/<NN>-<name>.sh, run by move-issue.sh before it
#   touches the board, in file-name order, with the card, the repo and the trunk's commit as
#   arguments. Status 0 allows, 3 refuses, anything else is a broken check, and a broken check
#   refuses too: a gate that cannot answer must not read as armed. The checks are the TRUNK's, not
#   the operator's checkout's, so a card cannot be moved past a check by not having pushed it.
# =============================================================================
_mc_rc=0 _mc_out="" _mc_n=0
_mc_move() {  # <id> <target> [more move-issue.sh args…] -> _mc_rc, _mc_out; record in $SB_TMP/mc-rec-N
  local id="$1" target="$2"; shift 2
  _mc_n=$((_mc_n + 1)); _mc_rc=0
  _mc_out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/mc-rec-$_mc_n" ./scripts/move-issue.sh "$id" "$target" --role "$SB_ROLE" "$@" 2>&1 )" || _mc_rc=$?
}
_mc_refused_for() { grep -q "refusal=$1" "$SB_TMP/mc-rec-$_mc_n"/*.tsv 2>/dev/null; }
_mc_sync() {  # publish the checkout's commits: the mover has pushed board commits of its own since
  git -C "$SB_WORK" pull -q --rebase origin "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
}
_mc_land() {  # <repo-relative path> <body> [local] — commit a file to the trunk and, unless "local", push it
  mkdir -p "$SB_WORK/$(dirname "$1")"; printf '%s' "$2" > "$SB_WORK/$1"
  git -C "$SB_WORK" add -A scripts >/dev/null 2>&1
  sbcommit -qm "[Dev] $SB_PREFIX-800: move check $1" >/dev/null 2>&1
  [ "${3:-}" = local ] || _mc_sync
}
_mc_unland() {  # <repo-relative path> — remove a file from the trunk
  git -C "$SB_WORK" rm -q -f "$1" >/dev/null 2>&1
  sbcommit -qm "[Dev] $SB_PREFIX-800: remove move check $1" >/dev/null 2>&1
  _mc_sync
}
_mc_trunk_sha() { origin_fetch_or_die; git -C "$SB_WORK" rev-parse "origin/$SB_TRUNK"; }

case_a_move_check_on_the_trunk_refuses_with_a_next_line_and_changes_nothing() {
  cf_reset
  local L="a move check under scripts/move-check.d/<target>/ on the trunk refuses the transition before anything changes (a Next: line, a rule id, the card still in its column and the trunk's commit unchanged), is called with the card, the repo and the trunk's commit, runs in file-name order and stops at the first refusal, is not read from an unpushed or uncommitted copy, is lifted by removing the file, is skipped by a note-only record, and a broken check refuses too"
  make_sandbox
  local a="$SB_PREFIX-801" b="$SB_PREFIX-802" c="$SB_PREFIX-803" e="$SB_PREFIX-805" f="$SB_PREFIX-806"
  seed_issue todo "$a" one chore "Move check one"
  seed_issue todo "$b" two chore "Move check two"
  seed_issue todo "$c" three chore "Move check three"
  seed_issue dev_complete "$e" five chore "Move check five"
  seed_issue dev_complete "$f" six chore "Move check six"
  publish_sandbox
  local dir="scripts/move-check.d/in_progress" args="$SB_TMP/mc-args" order="$SB_TMP/mc-order" tip want
  : > "$order"

  # (a) A REFUSING CHECK on the trunk: refused with its reason and its own Next: line; the card stays in
  #     todo/ on the trunk and the trunk does not move.
  _mc_land "$dir/10-probe.sh" "#!/usr/bin/env bash
printf '%s\\n' \"\$@\" > '$args'
echo 'PROBE-REASON the card lacks the thing'
echo 'Next: add the thing, then re-run.'
exit 3
"
  tip="$(_mc_trunk_sha)"
  _mc_move "$a" in_progress --note x
  [ "$_mc_rc" -eq 1 ] || cf "(a) the move was not refused with status 1 (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"
  [[ "$_mc_out" == *PROBE-REASON* ]] || cf "(a) the check's reason is not in the refusal: $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"
  [[ "$_mc_out" == *"Next: add the thing, then re-run."* ]] || cf "(a) the check's own Next: line is not in the refusal"
  [[ "$_mc_out" == *"NOTHING WAS CHANGED"* ]] || cf "(a) the refusal does not say nothing was changed"
  _mc_refused_for move-check-refused || cf "(a) no refusal=move-check-refused record"
  origin_has_path "progress/todo/$a-one.md" || cf "(a) the card left todo/ on the trunk though the move was refused"
  [ "$(_mc_trunk_sha)" = "$tip" ] || cf "(a) the trunk moved though the move was refused"
  [ "$(git -C "$SB_WORK" status --porcelain --untracked-files=no | wc -l | tr -d ' ')" = 0 ] || cf "(a) the refused move left the checkout dirty"

  # (a2) THE ARGUMENTS: id, from, to, role, the card file, the repo, the trunk's commit — in that order.
  want="$a
todo
in_progress
$SB_ROLE"
  [ "$(sed -n 1,4p "$args" 2>/dev/null)" = "$want" ] || cf "(a2) the first four arguments are not <id> <from> <to> <role>: $(sed -n 1,4p "$args" 2>/dev/null | tr '\n' '|')"
  [ "$(awk 'END{print NR}' "$args")" = 7 ] || cf "(a2) the check was not called with seven arguments: $(tr '\n' '|' < "$args")"
  case "$(sed -n 5p "$args")" in */progress/todo/"$a"-one.md) : ;; *) cf "(a2) argument 5 is not the trunk's copy of the card in the board worktree: $(sed -n 5p "$args")" ;; esac
  [ "$(cd -P "$(sed -n 6p "$args")" 2>/dev/null && pwd -P)" = "$(cd -P "$SB_WORK" && pwd -P)" ] || cf "(a2) argument 6 is not the repository: $(sed -n 6p "$args")"
  [ "$(sed -n 7p "$args")" = "$tip" ] || cf "(a2) argument 7 is not the trunk's commit $tip: $(sed -n 7p "$args")"

  # (b) A REFUSAL WITH NO Next: LINE gets one from the mover: no refusal is left without a way on.
  _mc_land "$dir/10-probe.sh" "#!/usr/bin/env bash
echo 'PROBE-NO-NEXT only a reason'
exit 3
"
  _mc_move "$a" in_progress --note x
  [ "$_mc_rc" -eq 1 ] && printf '%s\n' "$_mc_out" | grep '^Next:' >/dev/null \
    || cf "(b) a check that printed no Next: line was refused without one (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"

  # (c) A BROKEN CHECK (any status but 0 and 3) refuses too, with its own rule id and a Next: line.
  _mc_land "$dir/10-probe.sh" "#!/usr/bin/env bash
echo 'PROBE-BROKEN could not look'
exit 1
"
  _mc_move "$a" in_progress --note x
  [ "$_mc_rc" -eq 1 ] || cf "(c) a broken check did not refuse (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-200)"
  _mc_refused_for move-check-broken || cf "(c) no refusal=move-check-broken record: $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-200)"
  printf '%s\n' "$_mc_out" | grep '^Next:' >/dev/null || cf "(c) the broken-check refusal has no Next: line"
  origin_has_path "progress/todo/$a-one.md" || cf "(c) the card left todo/ though the broken check refused"

  # (d) ORDER, AND THE FIRST REFUSAL STOPS THE REST: 10 allows, 20 refuses, 30 never runs.
  _mc_unland "$dir/10-probe.sh"
  _mc_land "$dir/10-first.sh" "#!/usr/bin/env bash
echo first >> '$order'
exit 0
"
  _mc_land "$dir/20-second.sh" "#!/usr/bin/env bash
echo second >> '$order'
echo 'Next: nothing to do here'
exit 3
"
  _mc_land "$dir/30-third.sh" "#!/usr/bin/env bash
echo third >> '$order'
exit 0
"
  _mc_move "$a" in_progress --note x
  [ "$_mc_rc" -eq 1 ] || cf "(d) the second check's refusal did not refuse the move (exit $_mc_rc)"
  [ "$(tr '\n' ' ' < "$order")" = "first second " ] || cf "(d) the checks did not run in file-name order and stop at the refusal: '$(tr '\n' ' ' < "$order")'"

  # (e) A CHECK UNDER ANOTHER FOLDER DOES NOT JUDGE THIS MOVE; a name that is no check, and a folder
  #     that is no status folder, are said not to run.
  _mc_unland "$dir/20-second.sh"
  _mc_land "scripts/move-check.d/qa_complete/10-never.sh" "#!/usr/bin/env bash
exit 3
"
  _mc_land "$dir/README.txt" "not a check
"
  _mc_land "scripts/move-check.d/no-such-folder/10-x.sh" "#!/usr/bin/env bash
exit 3
"
  : > "$order"
  _mc_move "$a" in_progress --note x
  [ "$_mc_rc" -eq 0 ] || cf "(e) a move was refused by checks that do not judge it (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"
  [ "$(tr '\n' ' ' < "$order")" = "first third " ] || cf "(e) the in_progress checks did not run, in order, when all allowed: '$(tr '\n' ' ' < "$order")'"
  origin_has_path "progress/in_progress/$a-one.md" || cf "(e) the allowed move did not reach in_progress/ on the trunk"
  [[ "$_mc_out" == *"README.txt"*"not run"* ]] || cf "(e) a file in the check directory that is no check is not reported as not run: $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-300)"
  [[ "$_mc_out" == *"no-such-folder"* ]] || cf "(e) a check directory that names no status folder is not reported: $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-300)"

  # (f) THE TRUNK'S CHECKS, NOT THE CHECKOUT'S: a refusing check that is committed but not pushed, and
  #     one that is not committed, are not read; the trunk's own copy is.
  _mc_unland "$dir/10-first.sh"; _mc_unland "$dir/30-third.sh"
  _mc_land "$dir/40-local.sh" "#!/usr/bin/env bash
exit 3
" local
  printf '#!/usr/bin/env bash\nexit 3\n' > "$SB_WORK/$dir/50-uncommitted.sh"
  _mc_move "$b" in_progress --note x
  [ "$_mc_rc" -eq 0 ] || cf "(f) an unpushed or uncommitted check refused a move (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"
  rm -f "${SB_WORK:?}/$dir/50-uncommitted.sh"
  _mc_sync
  _mc_move "$c" in_progress --note x
  [ "$_mc_rc" -eq 1 ] || cf "(f) the check once pushed did not refuse (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"

  # (g) REMOVAL lifts it; a note-only record runs no check at all.
  _mc_land "$dir/10-always.sh" "#!/usr/bin/env bash
exit 3
"
  _mc_move "$c" --note-only --note "recorded without a move"
  [ "$_mc_rc" -eq 0 ] || cf "(g) a note-only record ran a move check (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-200)"
  _mc_unland "$dir/10-always.sh"; _mc_unland "$dir/40-local.sh"
  _mc_move "$c" in_progress --note x
  [ "$_mc_rc" -eq 0 ] || cf "(g) the move was still refused after the checks were removed (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-200)"

  # (h) A LANDED CARD IS NOT STRANDED: finish-pr.sh moves to qa_complete AFTER its squash, naming the
  #     commit with --landed-at; a refusal there would leave the code merged and the card in
  #     dev_complete/, so the check is skipped for that move, and said to be. Without --landed-at it runs.
  _mc_land "scripts/move-check.d/qa_complete/10-never.sh" "#!/usr/bin/env bash
echo 'PROBE-QA-CHECK refuses every landing'
exit 3
"
  sbcommit -q --allow-empty -m "[Dev] $e: landed (squash-merge feature/$e-five)" >/dev/null 2>&1
  _mc_sync
  _mc_move "$f" qa_complete --note x
  { [ "$_mc_rc" -eq 1 ] && _mc_refused_for move-check-refused; } || cf "(h) the qa_complete check did not refuse a move without --landed-at (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"
  _mc_move "$e" qa_complete --note x --landed-at "$(git -C "$SB_WORK" rev-parse HEAD)"
  [ "$_mc_rc" -eq 0 ] || cf "(h) a verified --landed-at move was refused by a move check (exit $_mc_rc): $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"
  [[ "$_mc_out" == *"Move checks skipped"* ]] || cf "(h) the skip is not said: $(printf '%s' "$_mc_out" | tr '\n' '|' | cut -c1-240)"
  origin_has_path "progress/qa_complete/$e-five.md" || cf "(h) the landed card did not reach qa_complete/"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A QA CELL CHECK IS THE TRUNK'S CODE, RUN AGAINST THE REVISION BEING LANDED.
#   A check is scripts/qa-cell.d/<evidence kind>/<NN>-<name>.sh. kit_qa_verdict_check calls it for each
#   PASS row of that kind, with the AC id, the pointer cell, the repo and both revisions, and reads
#   its own rule at the TRUNK: a branch that adds a check, or weakens one, changes nothing about the
#   gate it is judged by. What the check examines is read at the landed revision, never in the
#   working tree. Status 0 passes, 3 refuses, anything else is a broken check, which refuses too.
# =============================================================================
_qc_n=0 _qc_rc=0 _qc_out=""
_qc_gate() {  # <card> [<rev> [<trunk-rev>]] -> _qc_rc, _qc_out; records in $SB_TMP/qc-rec-N
  local card="$1"; shift
  _qc_n=$((_qc_n + 1)); _qc_rc=0
  _qc_out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/qc-rec-$_qc_n" bash -c '. scripts/lib/refuse.sh; . scripts/config.sh; . scripts/lib/qa-gate.sh; kit_qa_verdict_check "$@"' _ "$card" "$QC_ID" "$SB_WORK" "${1:-HEAD}" ${2:+"$2"} 2>&1 )" || _qc_rc=$?
}
_qc_refused_for() { grep -q "refusal=$1" "$SB_TMP/qc-rec-$_qc_n"/*.tsv 2>/dev/null; }
_qc_land() {  # <repo-relative path> <body> — commit a file to the current branch
  mkdir -p "$SB_WORK/$(dirname "$1")"; printf '%s' "$2" > "$SB_WORK/$1"
  git -C "$SB_WORK" add -A scripts process probe.txt >/dev/null 2>&1
  sbcommit -qm "[Dev] $QC_ID: $1" >/dev/null 2>&1
}
_qc_unland() {
  git -C "$SB_WORK" rm -q -f "$1" >/dev/null 2>&1
  sbcommit -qm "[Dev] $QC_ID: remove $1" >/dev/null 2>&1
}

case_a_qa_cell_check_runs_from_the_trunk_and_reads_the_landed_revision() {
  cf_reset
  local L="a QA cell check under scripts/qa-cell.d/<kind>/ refuses a PASS row with a Next: line and a rule id, is called with the id, the cell, the repo and both revisions, examines the landed revision and not the working tree, is the trunk's own code (a branch cannot add one, remove one or weaken one), skips a FAIL row, a placeholder pointer and another kind's row, refuses when broken, and is lifted by removing the file"
  make_sandbox
  QC_ID="$SB_PREFIX-820"
  local card="$SB_TMP/card.md" args="$SB_TMP/qc-args" dir="scripts/qa-cell.d/observation" good bad want
  seed_issue dev_complete "$QC_ID" cell chore "Cell checks"
  printf 'all good here\n' > "$SB_WORK/probe.txt"
  mkdir -p "$SB_WORK/process/evidence-kinds.d"
  printf 'observation\n' > "$SB_WORK/process/evidence-kinds.d/probe"
  publish_sandbox
  cp "$SB_WORK/progress/dev_complete/$QC_ID-cell.md" "$card"
  perl -0pi -e 's/(- \[ \] AC1 — [^\n]*\n)/$1- [ ] AC2 — the second behaviour holds.\n/; s/(\| shadow-check )/| AC2 | PASS | observation | ARCHIVE.md:1 |\n$1/' "$card"
  grep -qF '| AC2 | PASS | observation | ARCHIVE.md:1 |' "$card" || _fixture_die "${FUNCNAME[0]}: the AC2 row was not planted"
  good="all good here"; bad="BAD content"
  _qc_check_body() {  # the probe check: refuses when probe.txt AT THE LANDED REVISION holds BAD
    printf '%s' "#!/usr/bin/env bash
printf '%s\\n' \"\$@\" > '$args'
body=\"\$(git -C \"\$4\" show \"\$5:probe.txt\" 2>/dev/null)\" || { echo 'PROBE-CELL probe.txt is not at the landed revision'; exit 3; }
case \"\$body\" in *BAD*) echo \"PROBE-CELL probe.txt holds BAD at \${5:0:7}\"; echo 'Next: put the right text in probe.txt'; exit 3 ;; esac
exit 0
"
  }

  # (a) NO CHECK: the row passes (the premise), and a branch-only check is no check (see (d)).
  _qc_gate "$card"
  [ "$_qc_rc" -eq 0 ] || _fixture_die "${FUNCNAME[0]}: the plain gate refused the sandbox card (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-240)"

  # (d1) A BRANCH-ONLY CHECK CHANGES NOTHING for that branch's own landing: set up before the trunk has one.
  git -C "$SB_WORK" checkout -q -b branch-adds >/dev/null 2>&1
  printf '%s\n' "$bad" > "$SB_WORK/probe.txt"
  _qc_land "$dir/10-probe.sh" "$(_qc_check_body)"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  _qc_gate "$card" branch-adds "$SB_TRUNK"
  [ "$_qc_rc" -eq 0 ] || cf "(d1) a check that only the branch holds judged the branch's own landing (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-240)"

  # (b) THE TRUNK HOLDS THE CHECK: a good probe.txt passes; the arguments are the six the contract names.
  _qc_land "$dir/10-probe.sh" "$(_qc_check_body)"
  _qc_gate "$card"
  [ "$_qc_rc" -eq 0 ] || cf "(b) a row whose evidence satisfies the check was refused (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-240)"
  want="$QC_ID
AC2
ARCHIVE.md:1"
  [ "$(sed -n 1,3p "$args" 2>/dev/null)" = "$want" ] || cf "(b) the first three arguments are not <id> <ac id> <cell>: $(sed -n 1,3p "$args" 2>/dev/null | tr '\n' '|')"
  [ "$(awk 'END{print NR}' "$args")" = 6 ] || cf "(b) the check was not called with six arguments: $(tr '\n' '|' < "$args")"
  [ "$(cd -P "$(sed -n 4p "$args")" 2>/dev/null && pwd -P)" = "$(cd -P "$SB_WORK" && pwd -P)" ] || cf "(b) argument 4 is not the repository: $(sed -n 4p "$args")"
  [ "$(sed -n 5p "$args")" = "$(git -C "$SB_WORK" rev-parse HEAD)" ] || cf "(b) argument 5 is not the landed revision's commit: $(sed -n 5p "$args")"
  [ "$(sed -n 6p "$args")" = "$(git -C "$SB_WORK" rev-parse HEAD)" ] || cf "(b) argument 6 is not the trunk revision's commit: $(sed -n 6p "$args")"

  # (c) THE LANDED REVISION, NOT THE WORKING TREE. A branch whose probe.txt is BAD is refused though
  #     the checked-out tree holds the good one; a BAD probe.txt in the working tree only is not read.
  git -C "$SB_WORK" checkout -q -b branch-bad >/dev/null 2>&1
  printf '%s\n' "$bad" > "$SB_WORK/probe.txt"
  git -C "$SB_WORK" add probe.txt >/dev/null 2>&1; sbcommit -qm "[Dev] $QC_ID: bad content" >/dev/null 2>&1
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  _qc_gate "$card" branch-bad "$SB_TRUNK"
  [ "$_qc_rc" -eq 2 ] || cf "(c) a revision whose evidence fails the check was not refused with status 2 (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-240)"
  _qc_refused_for qa-verdict-cell-refused || cf "(c) no refusal=qa-verdict-cell-refused record: $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-240)"
  [[ "$_qc_out" == *"PROBE-CELL probe.txt holds BAD at $(git -C "$SB_WORK" rev-parse --short=7 branch-bad)"* ]] || cf "(c) the check did not read the landed revision (its message names another commit, or none): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-300)"
  [[ "$_qc_out" == *"AC2"* ]] || cf "(c) the refusal does not name the row AC2"
  printf '%s\n' "$_qc_out" | grep '^Next:' >/dev/null || cf "(c) the refusal has no Next: line"
  [[ "$_qc_out" == *"NOTHING WAS CHANGED"* ]] || cf "(c) the refusal does not say nothing was changed"
  printf '%s\n' "$bad" > "$SB_WORK/probe.txt"
  _qc_gate "$card"
  [ "$_qc_rc" -eq 0 ] || cf "(c) a BAD probe.txt in the working tree only was read (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-240)"
  git -C "$SB_WORK" checkout -q -- probe.txt >/dev/null 2>&1

  # (d2) A BRANCH CANNOT WEAKEN OR REMOVE THE TRUNK'S CHECK: the trunk's code judges the branch whose
  #      own copy of the check allows everything, or has none.
  git -C "$SB_WORK" checkout -q -b branch-weakens branch-bad >/dev/null 2>&1
  _qc_land "$dir/10-probe.sh" "#!/usr/bin/env bash
exit 0
"
  git -C "$SB_WORK" checkout -q -b branch-removes branch-bad >/dev/null 2>&1
  _qc_unland "$dir/10-probe.sh"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  _qc_gate "$card" branch-weakens "$SB_TRUNK"
  [ "$_qc_rc" -eq 2 ] || cf "(d2) a branch that weakened the trunk's check judged itself (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-200)"
  _qc_gate "$card" branch-removes "$SB_TRUNK"
  [ "$_qc_rc" -eq 2 ] || cf "(d2) a branch that deleted the trunk's check escaped it (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-200)"

  # (e) ONLY A PASS ROW OF THE CHECK'S OWN KIND IS CHECKED: a FAIL_AC row is not (the gate's own
  #     FAIL refusal speaks), a placeholder pointer is not (the gate's evidence refusal speaks), and a
  #     check under another kind's folder is never called for this row.
  perl -pi -e 's/\| AC2 \| PASS \| observation \|/| AC2 | FAIL_AC | observation |/' "$card"
  _qc_gate "$card" branch-bad "$SB_TRUNK"
  { [ "$_qc_rc" -eq 2 ] && _qc_refused_for qa-verdict-fail; } || cf "(e) a FAIL_AC row was judged by the cell check, or not refused as a FAIL (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-200)"
  perl -pi -e 's/\| AC2 \| FAIL_AC \| observation \| ARCHIVE.md:1 \|/| AC2 | PASS | observation | tbd |/' "$card"
  rm -f "${args:?}"
  _qc_gate "$card" branch-bad "$SB_TRUNK"
  { [ "$_qc_rc" -eq 2 ] && _qc_refused_for qa-verdict-evidence-missing && [ ! -e "$args" ]; } || cf "(e) a placeholder pointer reached the cell check, or was not refused as missing evidence (exit $_qc_rc, check ran: $([ -e "$args" ] && echo yes || echo no))"
  perl -pi -e 's/\| AC2 \| PASS \| observation \| tbd \|/| AC2 | PASS | observation | ARCHIVE.md:1 |/' "$card"
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  _qc_unland "$dir/10-probe.sh"
  _qc_land "scripts/qa-cell.d/gate-diff/10-never.sh" "#!/usr/bin/env bash
exit 3
"
  _qc_gate "$card" branch-bad "$SB_TRUNK"
  [ "$_qc_rc" -eq 0 ] || cf "(e) a check under another kind's folder judged an observation row (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-200)"

  # (f) A BROKEN CHECK refuses on its own rule id, with a Next: line.
  _qc_land "$dir/10-probe.sh" "#!/usr/bin/env bash
echo 'PROBE-BROKEN could not look'
exit 1
"
  _qc_gate "$card"
  { [ "$_qc_rc" -eq 2 ] && _qc_refused_for qa-verdict-cell-check-broken; } || cf "(f) a broken check did not refuse as qa-verdict-cell-check-broken (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-240)"
  printf '%s\n' "$_qc_out" | grep '^Next:' >/dev/null || cf "(f) the broken-check refusal has no Next: line"

  # (g) REMOVAL lifts it.
  _qc_unland "$dir/10-probe.sh"
  _qc_gate "$card" branch-bad "$SB_TRUNK"
  [ "$_qc_rc" -eq 0 ] || cf "(g) the row was still refused after the check was removed from the trunk (exit $_qc_rc): $(printf '%s' "$_qc_out" | tr '\n' '|' | cut -c1-200)"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A qa_complete MOVE CHECK STOPS finish-pr.sh BEFORE THE SQUASH, AND A SLICE'S MOVE RUNS THE CHECKS TOO.
#   finish-pr.sh is the route nearly every card lands by, and its own move to qa_complete comes after the
#   squash with --landed-at, which move-issue.sh answers by skipping the checks. So the landing runs them
#   itself, first: a refusal leaves the trunk as it was, the card in dev_complete/ and the branch where it
#   was, and names the check and its Next:. The same checks judge subtask.sh's own mover.
# =============================================================================
case_a_qa_complete_move_check_stops_finish_pr_before_the_squash() {
  cf_reset
  local L="a qa_complete move check on the trunk refuses finish-pr.sh before the squash (status 1, the trunk unchanged, the card in dev_complete/, the branch kept, the check named with its Next:), the landing succeeds once the check is withdrawn, and subtask.sh's own move runs the checks of its target"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  make_sandbox
  local id="$SB_PREFIX-830" par="$SB_PREFIX-831" out rc tip n=0
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  seed_issue dev_complete "$id" landing chore "Landing behind a move check" "feature/$id-work"
  seed_issue todo "$par" parent chore "Parent of a slice"
  publish_sandbox
  seed_branch "$id" work CHANGE.txt
  _mc_land "scripts/move-check.d/qa_complete/10-never.sh" "#!/usr/bin/env bash
echo 'PROBE-LANDING-CHECK refuses every landing'
echo 'Next: do what the probe wants'
exit 3
"
  _fp() { n=$((n + 1)); rc=0; out="$( cd "$SB_WORK" && env "${FPR_STUB[@]}" KIT_PROGRESS_DIR="$SB_TMP/fp-rec-$n" ./scripts/finish-pr.sh "$id" 2>&1 )" || rc=$?; }

  # (a) REFUSED BEFORE ANYTHING IS DONE.
  tip="$(_mc_trunk_sha)"
  _fp
  [ "$rc" -eq 1 ] || cf "(a) the landing was not refused with status 1 (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [[ "$out" == *"10-never.sh"* && "$out" == *PROBE-LANDING-CHECK* ]] || cf "(a) the refusal does not name the check and quote its reason: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [[ "$out" == *"Next: do what the probe wants"* ]] || cf "(a) the check's Next: line is not in the refusal"
  [[ "$out" == *"NOTHING WAS CHANGED"* ]] || cf "(a) the refusal does not say nothing was changed"
  grep -q 'refusal=move-check-refused' "$SB_TMP/fp-rec-$n"/*.tsv 2>/dev/null || cf "(a) no refusal=move-check-refused record"
  [ "$(_mc_trunk_sha)" = "$tip" ] || cf "(a) the trunk moved though the landing was refused"
  origin_has_path "CHANGE.txt" && cf "(a) the branch was squashed onto the trunk before the refusal"
  origin_has_path "progress/dev_complete/$id-landing.md" || cf "(a) the card left dev_complete/ on the trunk"
  git -C "$SB_WORK" rev-parse --verify --quiet "refs/heads/feature/$id-work" >/dev/null 2>&1 || cf "(a) the local branch was deleted"
  [ -n "$(git -C "$SB_WORK" ls-remote --heads origin "feature/$id-work" 2>/dev/null)" ] || cf "(a) the remote branch was deleted"

  # (b) WITHDRAWN: the same landing goes through, and move-issue.sh's own move says it skipped the checks.
  _mc_unland "scripts/move-check.d/qa_complete/10-never.sh"
  _fp
  [ "$rc" -eq 0 ] || cf "(b) the landing was refused after the check was withdrawn (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/qa_complete/$id-landing.md" || cf "(b) the card did not reach qa_complete/"

  # (c) A SLICE: subtask.sh's own mover runs the checks of its target and changes nothing on a refusal.
  git -C "$SB_WORK" checkout -q "$SB_TRUNK" >/dev/null 2>&1
  git -C "$SB_WORK" pull -q --rebase origin "$SB_TRUNK" >/dev/null 2>&1
  ( cd "$SB_WORK" && ./scripts/subtask.sh new "$par" s1 slice --title "Slice" ) >/dev/null 2>&1 \
    || _fixture_die "${FUNCNAME[0]}: subtask.sh new refused a legal slice"
  _mc_land "scripts/move-check.d/in_progress/10-slice.sh" "#!/usr/bin/env bash
echo 'PROBE-SLICE-CHECK refuses'
exit 3
"
  n=$((n + 1)); rc=0
  out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/fp-rec-$n" ./scripts/subtask.sh move "$par-s1" in_progress --role "$SB_ROLE" --note x 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] && [[ "$out" == *PROBE-SLICE-CHECK* ]] && grep -q 'refusal=move-check-refused' "$SB_TMP/fp-rec-$n"/*.tsv 2>/dev/null \
    || cf "(c) the slice's move was not refused by the move check (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/subtasks/$par/todo/$par-s1-slice.md" || cf "(c) the slice left todo/ on the trunk though the move was refused"
  _mc_unland "scripts/move-check.d/in_progress/10-slice.sh"
  ( cd "$SB_WORK" && ./scripts/subtask.sh move "$par-s1" in_progress --role "$SB_ROLE" --note x ) >/dev/null 2>&1 \
    || cf "(c) the slice's move was refused after the check was withdrawn"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A done/ MOVE CHECK STOPS THE ARCHIVE SWEEP BEFORE IT WRITES ANYTHING.
#   archive.sh moves qa_complete -> done, so it is a mover like move-issue.sh: the trunk's
#   scripts/move-check.d/done/ checks judge each card it would retire, and the first refusal ends the
#   sweep with the trunk, ARCHIVE.md and the column as they were. A preview runs them too, so it does not
#   promise a sweep the apply would refuse.
# =============================================================================
case_a_done_move_check_stops_the_archive_sweep_before_it_writes() {
  cf_reset
  local L="a done/ move check on the trunk refuses archive.sh --apply and the preview with the check's reason and Next: line, a rule id and nothing changed (the card still in qa_complete/ on the trunk, ARCHIVE.md and the trunk's commit as they were), and the sweep goes through once the check is withdrawn"
  make_sandbox
  local id="$SB_PREFIX-840" tip arch out rc n=0
  seed_issue qa_complete "$id" sweep chore "A card behind a done check"
  publish_sandbox
  _mc_land "scripts/move-check.d/done/10-never.sh" "#!/usr/bin/env bash
echo 'PROBE-ARCHIVE-CHECK refuses every retirement'
echo 'Next: do what the probe wants'
exit 3
"
  _ar() { n=$((n + 1)); rc=0; out="$( cd "$SB_WORK" && env KIT_PROGRESS_DIR="$SB_TMP/ar-rec-$n" ./scripts/archive.sh "$@" 2>&1 )" || rc=$?; }
  tip="$(_mc_trunk_sha)"; arch="$(git -C "$SB_WORK" show "origin/$SB_TRUNK:ARCHIVE.md" 2>/dev/null)"

  _ar --apply
  [ "$rc" -eq 1 ] || cf "(a) the sweep was not refused with status 1 (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [[ "$out" == *PROBE-ARCHIVE-CHECK* && "$out" == *"10-never.sh"* ]] || cf "(a) the refusal does not name the check and quote its reason: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  [[ "$out" == *"Next: do what the probe wants"* ]] || cf "(a) the check's own Next: line is not in the refusal"
  [[ "$out" == *"NOTHING WAS CHANGED"* ]] || cf "(a) the refusal does not say nothing was changed"
  grep -q 'refusal=move-check-refused' "$SB_TMP/ar-rec-$n"/*.tsv 2>/dev/null || cf "(a) no refusal=move-check-refused record"
  [ "$(_mc_trunk_sha)" = "$tip" ] || cf "(a) the trunk moved though the sweep was refused"
  origin_has_path "progress/qa_complete/$id-sweep.md" || cf "(a) the card left qa_complete/ on the trunk"
  [ "$(git -C "$SB_WORK" show "origin/$SB_TRUNK:ARCHIVE.md" 2>/dev/null)" = "$arch" ] || cf "(a) ARCHIVE.md changed though the sweep was refused"

  _ar
  { [ "$rc" -eq 1 ] && [[ "$out" == *PROBE-ARCHIVE-CHECK* ]]; } || cf "(b) the preview was not refused by the check (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"

  _mc_unland "scripts/move-check.d/done/10-never.sh"
  _ar --apply
  [ "$rc" -eq 0 ] || cf "(c) the sweep was refused after the check was withdrawn (exit $rc): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
  origin_has_path "progress/done/$id-sweep.md" || cf "(c) the card did not reach done/"

  finish "$L"
  teardown
}

# =============================================================================
# CASE — A FRAGMENT FOR ISSUE-SHAPED CARDS REACHES A BUG, A REFACTOR AND A SLICE.
#   new-bug.sh, new-refactor.sh and subtask.sh mint from a template as new-issue.sh does, so they
#   place what an add-on contributes under process/fragments.d/ISSUE/ the same way: only while the
#   file is there, and byte-absent once it is withdrawn. A slice reads the fragment from the
#   trunk's tree, like its template.
# =============================================================================
case_an_issue_fragment_reaches_a_minted_bug_refactor_and_slice_only_while_enabled() {
  cf_reset
  local L="a fragment under process/fragments.d/ISSUE/ (frontmatter and body end) is in a minted bug, refactor and slice only while its files are there, and the cards minted before it and after its withdrawal carry no trace of it (the bug and the refactor are byte-equal to the first mint)"
  if ! has_issue_template; then skp "$L" "$ISSUE_TEMPLATE_ABSENT"; return; fi
  local t
  for t in BUG REFACTOR SUBTASK; do
    if [ ! -f "$REAL_REPO_ROOT/.claude/templates/$t.template.md" ]; then skp "$L" ".claude/templates/$t.template.md is absent from this tree"; return; fi
  done
  make_sandbox
  mkdir -p "$SB_WORK/.claude/templates"
  cp -R "$REAL_REPO_ROOT/.claude/templates/." "$SB_WORK/.claude/templates/"
  _kit_neutral_claude
  local pid="$SB_PREFIX-910" bug="$SB_PREFIX-911" ref="$SB_PREFIX-912" fd="$SB_WORK/process/fragments.d/ISSUE"
  seed_issue todo "$pid" parent chore "Slice parent"
  publish_sandbox
  local out rc=0 slice_rel=""

  _fb_mint() {  # <stage> -> the three cards in $SB_TMP/<kind>-<stage>.md; the bug and the refactor are removed from the board again
    local stage="$1" n
    n="$stage"
    rc=0; out="$( cd "$SB_WORK" && ./scripts/new-bug.sh probe --id "$bug" --prd n/a 2>&1 )" || rc=$?
    [ "$rc" -eq 0 ] || _fixture_die "${FUNCNAME[1]}: new-bug.sh exited $rc ($stage): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    cp "$SB_WORK/progress/todo/$bug-probe.md" "$SB_TMP/bug-$n.md"; rm -f "$SB_WORK/progress/todo/$bug-probe.md"
    rc=0; out="$( cd "$SB_WORK" && ./scripts/new-refactor.sh probe --id "$ref" --prd n/a 2>&1 )" || rc=$?
    [ "$rc" -eq 0 ] || _fixture_die "${FUNCNAME[1]}: new-refactor.sh exited $rc ($stage): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    cp "$SB_WORK/progress/todo/$ref-probe.md" "$SB_TMP/ref-$n.md"; rm -f "$SB_WORK/progress/todo/$ref-probe.md"
    rc=0; out="$( cd "$SB_WORK" && ./scripts/subtask.sh new "$pid" "$n" probe --title "Slice" 2>&1 )" || rc=$?
    [ "$rc" -eq 0 ] || _fixture_die "${FUNCNAME[1]}: subtask.sh new exited $rc ($stage): $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
    slice_rel="progress/subtasks/$pid/todo/$pid-$n-probe.md"
    git -C "$SB_WORK" fetch -q origin >/dev/null 2>&1
    git -C "$SB_WORK" show "origin/$SB_TRUNK:$slice_rel" > "$SB_TMP/slice-$n.md" 2>/dev/null \
      || _fixture_die "${FUNCNAME[1]}: the slice $slice_rel is not on the trunk ($stage)"
  }

  # (a) NOTHING ENABLED.
  _fb_mint s1
  # (b) ENABLED: the add-on's files are on the trunk (the slice reads them there) and in the checkout.
  mkdir -p "$fd"
  printf 'probe_card: yes\n' > "$fd/probe.frontmatter"
  printf 'PROBE-ISSUE-END\n' > "$fd/probe.body-end"
  git -C "$SB_WORK" add process/fragments.d >/dev/null 2>&1
  sbcommit -m "[PM] enable the probe fragment" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  _fb_mint s2
  # (c) WITHDRAWN.
  git -C "$SB_WORK" rm -q -r -f process/fragments.d >/dev/null 2>&1
  sbcommit -m "[PM] withdraw the probe fragment" --quiet >/dev/null 2>&1
  git -C "$SB_WORK" push -q origin "$SB_TRUNK" >/dev/null 2>&1
  _fb_mint s3

  local k
  for k in bug ref slice; do
    grep -F 'probe_card' "$SB_TMP/$k-s1.md" "$SB_TMP/$k-s3.md" >/dev/null && cf "a $k minted with the fragment not enabled carries its frontmatter"
    grep -F 'PROBE-ISSUE-END' "$SB_TMP/$k-s1.md" "$SB_TMP/$k-s3.md" >/dev/null && cf "a $k minted with the fragment not enabled carries its body end"
    awk '$0=="---"{n++; next} n==1 && /^probe_card: yes$/{a=1} END{exit (a && n>=2) ? 0 : 1}' "$SB_TMP/$k-s2.md" \
      || cf "the $k minted with the fragment enabled has no frontmatter fragment inside its frontmatter"
    [ "$(grep -c -F 'PROBE-ISSUE-END' "$SB_TMP/$k-s2.md")" -eq 1 ] || cf "the $k minted with the fragment enabled does not carry the body-end fragment exactly once"
    [ "$(grep -n -F 'PROBE-ISSUE-END' "$SB_TMP/$k-s2.md" | cut -d: -f1)" -lt "$(grep -n '^## Activity' "$SB_TMP/$k-s2.md" | cut -d: -f1)" ] \
      || cf "the $k's body-end fragment is not above ## Activity"
  done
  for k in bug ref; do
    cmp -s "$SB_TMP/$k-s1.md" "$SB_TMP/$k-s3.md" || cf "the $k minted after the fragment was withdrawn differs from the first: $(diff "$SB_TMP/$k-s1.md" "$SB_TMP/$k-s3.md" | head -4 | tr '\n' '|')"
  done
  finish "$L"
  teardown
}
