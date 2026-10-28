# KIT-CLASS: MIXED — self-test harness, the files a project adds to extend the kit. See
# process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/extension-points.sh — sourced by scripts/test/run.sh, never run on its own.
# Each case adds through an extension point exactly as a project would (a file, not an edit to a
# script), proves every reader of that point takes it up, removes it, and proves they refuse again.
# The role set's layers (process/ROLES, process/roles.d/) are the point pinned here.
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
