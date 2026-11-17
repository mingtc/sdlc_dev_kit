#!/usr/bin/env bash
# KIT-CLASS: KIT — the modules library: read a module's manifest, plan what enabling places, record it in process/MODULES. See process/EXTRACTION.md.
#
# WHAT A MODULE IS: an optional overlay stored under modules/<name>/ in the kit, disarmed (a harness
# reads nothing there), with a module.manifest. Enabling copies the overlay into place and registers
# it with the extension points process/MODULES.md lists; disabling takes back exactly what enabling
# wrote. process/MODULES (the record) is the one statement of what is enabled and of the sha256 of every
# file and block enable placed, so disable can tell a file the module wrote from one the project then
# edited. The contract is process/contracts/module-lifecycle.md; the program is scripts/module.sh.
# kit-init.sh (--with) asks kit_mod_would_place before it writes and then runs module.sh; kit-upgrade.sh
# carries an enabled module's new version through kit_mod_upgrade_scan, _apply, _stage_record and _finish_record.
#
# THE CALLER SETS, before any call:
#   KIT_MOD_ROOT   the project's top level (where process/MODULES lives, where files are placed)
#   KIT_MOD_SRC    the kit that holds modules/ (defaults to KIT_MOD_ROOT)
#   KIT_MOD_TMP    a scratch directory the caller owns and removes
# A refusal goes through kit_refuse (lib/refuse.sh: what is wrong, a `Next:` line, a progress record)
# and EXITS. Enable and disable check everything before the first write. Bash 3.2, POSIX tools only.
#
# THE RECORD, process/MODULES (created by the first enable, deleted by the last disable):
#   module  <name> <version>        enabled
#   pending <name> <version>        an enable that was started and has not finished (beside a `module` line of the
#                                   same name: the rows an upgrade is about to write; a path may then hold the sha256 of
#                                   either section, and status and disable read both)
#   kept    <name> <version>        what a disable left because the project had edited it
#   file  <sha256> <path>           rows belong to the nearest header line above them
#   block <sha256> <path> <slot>
# `#` lines are comments. A path holds no space. ENABLE WRITES THE RECORD AHEAD OF THE FILES, as
# `pending`, so an enable that is killed part-way leaves the proof of which paths are the module's:
# running enable again finishes it, and disable takes it back.
#
# PLACEHOLDERS a module's files may carry, replaced as they are placed once kit-init has stamped the
# project: <PREFIX> the issue prefix, <trunk> the trunk, <project name>. Before the stamp they stay.
#
# REQUIREMENTS, from the manifest's `requires:` and `requires-agent:` lines (process/MODULES.md § What a module
# needs). A `requires:` check is a SHELL COMMAND THE MANIFEST DECLARES. It runs with the person's rights, in the
# project's top directory, under `sh -c`, with no input and its output discarded, and the kit stops waiting for it
# after KIT_MOD_CHECK_SECONDS (10 when unset); one that does not finish counts as failing. The kit cannot stop it
# writing: read-only is its author's duty (contracts/module-lifecycle.md § 2 states the rule). Enable, the day-one
# preflight and status run the checks; list never does; NOTHING in the kit runs a module's setup.sh.

# shellcheck source=refuse.sh
. "$(dirname "${BASH_SOURCE[0]}")/refuse.sh" || return 1   # return-class: internal
# shellcheck source=marker-block.sh
. "$(dirname "${BASH_SOURCE[0]}")/marker-block.sh" || return 1   # return-class: internal

KIT_MOD_STATE_REL='process/MODULES'
# The names a harness reads. A module stores them disarmed (`_claude/`, not `.claude/`); a source
# path carrying one is refused here and by the builder, which reads this line.
KIT_MOD_ARMED_NAMES='.claude AGENTS.md CLAUDE.md'
# Targets a module may never write: the kit's own bookkeeping.
KIT_MOD_RESERVED='process/MODULES process/KIT-MANIFEST process/KIT-VERSION'

# ── small helpers ─────────────────────────────────────────────────────────────

_kit_mod_sha_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else cat >/dev/null; fi
}
# kit_mod_have_sha — status 0 when a sha256 tool exists.
kit_mod_have_sha() { command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; }
_kit_mod_sha() { _kit_mod_sha_stdin < "$1"; }
# _kit_mod_block_text <file> <id> — the lines between the block's markers, as written, with a CRLF
# file's `\r` taken off so the sha of a block does not depend on the checkout's line endings.
_kit_mod_block_text() {
  KMB_B="$(kit_mb_begin_line "$2")" KMB_E="$(kit_mb_end_line "$2")" awk '
    BEGIN { b = ENVIRON["KMB_B"]; e = ENVIRON["KMB_E"] }
    { l = $0; sub(/\r$/, "", l) }
    !inb && l == b { inb = 1; next }
    inb && l == e { exit }
    inb { print l }' "$1"
}
_kit_mod_block_sha() { _kit_mod_block_text "$1" "$2" | _kit_mod_sha_stdin; }
# _kit_mod_block_view <file> <block id> — `none` (no block, or no file), `bad` (a lone, repeated or misordered marker), or
# `one <sha>` of the block's lines.
_kit_mod_block_view() {
  local st=none
  [ ! -f "$1" ] || st="$(_kit_mb_state "$1" "$2")"
  if [ "$st" = one ]; then echo "one $(_kit_mod_block_sha "$1" "$2")"; else echo "$st"; fi
}
# kit_mod_block_changed <path> <module> <slot> — status 0 unless the module's block in <path> reads the same in the
# working tree, the index and HEAD: no block in all three, or one well-formed block with the same lines in all three.
# A path HEAD or the index lacks reads as holding no block.
kit_mod_block_changed() {
  local t="$KIT_MOD_TMP/head-block" bid w h i
  bid="$(_kit_mod_bid "$2" "$3")"
  w="$(_kit_mod_block_view "$KIT_MOD_ROOT/$1" "$bid")"
  if ! ( cd "$KIT_MOD_ROOT" && git show "HEAD:./$1" ) > "$t" 2>/dev/null; then : > "$t"; fi
  h="$(_kit_mod_block_view "$t" "$bid")"
  if ! ( cd "$KIT_MOD_ROOT" && git show ":./$1" ) > "$t" 2>/dev/null; then : > "$t"; fi
  i="$(_kit_mod_block_view "$t" "$bid")"
  rm -f "$t"
  [ "$w" = bad ] || [ "$w" != "$h" ] || [ "$i" != "$h" ]
}
# _kit_mod_text_sha <file> — the sha of a block content file as marker-block writes it (every line ended).
_kit_mod_text_sha() { awk '1' "$1" | _kit_mod_sha_stdin; }

# _kit_mod_safe_rel <path> — status 0 for a relative path in its one canonical form: plain characters, no
# `.` or `..` component, no empty one (`a//b`, a trailing `/`). A path that reaches a place by another
# spelling would miss every exact-string check made against it (the core files, the kit's own bookkeeping,
# `.git/`).
_kit_mod_safe_rel() {
  case "$1" in
    ''|/*|*[!A-Za-z0-9._/@+-]*|../*|*/../*|*/..|..|./*|*/./*|*/.|.|*//*|*/) return 1 ;;   # return-class: predicate
  esac
  return 0
}
# _kit_mod_armed_component <path> — status 0 when a path component is one a harness reads.
_kit_mod_armed_component() {
  local n
  for n in $KIT_MOD_ARMED_NAMES; do
    case "/$1/" in */"$n"/*) return 0 ;; esac
  done
  return 1   # return-class: predicate
}
_kit_mod_name_ok() {
  case "$1" in ''|[!a-z]*|*[!a-z0-9-]*) return 1 ;; esac   # return-class: predicate
  return 0
}

# _kit_mod_need_name <name> — refuse a name that cannot be a module's.
_kit_mod_need_name() {
  _kit_mod_name_ok "$1" || kit_refuse 1 module-name-bad \
    "Error: '$1' is not a module name (lowercase letters, digits and '-', opening with a letter)." \
    "Next: ./scripts/module.sh list names the modules this kit ships."
}

_kit_mod_src() { printf '%s' "${KIT_MOD_SRC:-$KIT_MOD_ROOT}"; }
_kit_mod_state() { printf '%s/%s' "$KIT_MOD_ROOT" "$KIT_MOD_STATE_REL"; }

# ── the record ────────────────────────────────────────────────────────────────

# kit_mod_enabled_names — one name per line.
kit_mod_enabled_names() {
  [ -f "$(_kit_mod_state)" ] || return 0
  awk '$1 == "module" { print $2 }' "$(_kit_mod_state)"
}
# kit_mod_pending_names — one name per line: the modules whose enable was started and has not finished (a name
# that is also enabled has an upgrade that did not finish, and is not listed).
kit_mod_pending_names() {
  [ -f "$(_kit_mod_state)" ] || return 0
  awk '$1 == "module" { en[$2] = 1 } $1 == "pending" { pe[$2] = 1 } END { for (n in pe) if (!(n in en)) print n }' "$(_kit_mod_state)" | LC_ALL=C sort
}
# kit_mod_is_enabled <name> — status 0 when recorded as enabled.
kit_mod_is_enabled() { local n; n="$(kit_mod_enabled_names)"; grep -qxF -- "$1" <<< "$n"; }
# kit_mod_is_pending <name> — status 0 when an enable of it was started and has not finished.
kit_mod_is_pending() {
  [ -f "$(_kit_mod_state)" ] || return 1   # return-class: predicate
  awk -v n="$1" '$1 == "pending" && $2 == n { f = 1 } END { exit !f }' "$(_kit_mod_state)"
}
# kit_mod_enabled_version <name>
kit_mod_enabled_version() {
  [ -f "$(_kit_mod_state)" ] || return 0
  awk -v n="$1" '$1 == "module" && $2 == n { print $3; exit }' "$(_kit_mod_state)"
}
# _kit_mod_rows_of <name> <keyword…> — the rows under the first header line `<keyword> <name>`, checked:
# a row whose path is not a plain relative path means process/MODULES was edited or merged badly, and
# nothing may act on it.
_kit_mod_rows_of() {
  local name="$1" kws=" ${*:2} " rows bad
  [ -f "$(_kit_mod_state)" ] || return 0
  rows="$(awk -v k="$kws" -v n="$name" '$1 == "module" || $1 == "kept" || $1 == "pending" { on = ($2 == n && index(k, " " $1 " ") > 0); next } on && ($1 == "file" || $1 == "block") { print }' "$(_kit_mod_state)")"
  while read -r _ _ bad _; do
    [ -n "$bad" ] || continue
    _kit_mod_safe_rel "$bad" || kit_refuse 1 module-record-bad \
      "Error: $KIT_MOD_STATE_REL records the path '$bad' for module $name, which is not a plain relative path inside the project." \
      "Next: restore $KIT_MOD_STATE_REL from version control (it is written by scripts/module.sh and edited by nothing else); nothing was changed."
  done <<ROWS_EOF
$rows
ROWS_EOF
  [ -z "$rows" ] || printf '%s\n' "$rows"
}
# kit_mod_rows <name> — `<kind> <sha> <path> [<slot>]`, one per line, of an enabled or interrupted module.
kit_mod_rows() { _kit_mod_rows_of "$1" module pending; }
# kit_mod_pending_rows <name> — the rows an interrupted enable of <name> recorded ahead of its writes.
kit_mod_pending_rows() { _kit_mod_rows_of "$1" pending; }
# kit_mod_rows_merged <name> — `<kind> <sha>|<sha>… <path> [<slot>]`, one row per thing: the shas a path may hold when an upgrade
# was started and not finished (its module rows and its `pending` rows name different ones). disable and status read these.
kit_mod_rows_merged() {
  # read through a file: a refusal (a row that leaves the project) must end the caller, which a pipe's left side cannot
  kit_mod_rows "$1" > "$KIT_MOD_TMP/rows-union"
  awk '{ k = $1 SUBSEP $3 SUBSEP $4; if (!(k in sha)) { order[++n] = k; first[k] = $0; sha[k] = $2 } else sha[k] = sha[k] "|" $2 }
    END { for (i = 1; i <= n; i++) { k = order[i]; split(first[k], f, " "); printf "%s %s %s", f[1], sha[k], f[3]; if (f[4] != "") printf " %s", f[4]; printf "\n" } }' "$KIT_MOD_TMP/rows-union"
}
# _kit_mod_sha_in <sha> <sha>|<sha>… — status 0 when the first is one of the alternatives.
_kit_mod_sha_in() {
  case "|$2|" in *"|$1|"*) return 0 ;; esac
  return 1   # return-class: predicate
}
# _kit_mod_sha_pick <current sha> <alternatives> — the alternative the tree holds, else the first one.
_kit_mod_sha_pick() { if _kit_mod_sha_in "$1" "$2"; then printf '%s' "$1"; else printf '%s' "${2%%|*}"; fi; }
# kit_mod_kept_rows <name> — the rows a disable of <name> left in the tree, as recorded then.
kit_mod_kept_rows() { _kit_mod_rows_of "$1" kept; }
# kit_mod_kept_version <name> — the version <name> had when it was disabled with files kept, or nothing.
kit_mod_kept_version() {
  [ -f "$(_kit_mod_state)" ] || return 0
  awk -v n="$1" '$1 == "kept" && $2 == n { print $3; exit }' "$(_kit_mod_state)"
}
# _kit_mod_state_put <name> <version> <rows-file> [module|pending|kept] — replace (or add) the module's
# record, dropping any record of it of another kind; an empty <version> only drops. With nothing left the
# file is removed. The new copy is written beside the record and moved over it, so a kill never leaves a
# half-written record.
_kit_mod_state_put() {
  local name="$1" ver="$2" rows="$3" kw="${4:-module}" f tmp
  f="$(_kit_mod_state)"; tmp="$KIT_MOD_TMP/state.new"
  {
    printf '%s\n' \
      '# KIT-CLASS: MIXED — the modules this project has enabled, written by scripts/module.sh. See process/EXTRACTION.md.' \
      '# One `module <name> <version>` line per module, then a row per thing enable placed: `file <sha256> <path>` or' \
      '# `block <sha256> <path> <slot>`, the sha256 being what enable wrote. disable removes what still matches its' \
      '# sha256 and keeps, and reports, what the project edited since, under a `kept <name> <version>` line. A' \
      '# `pending` line is an enable that has not finished: run enable again to finish it, or disable to take it back.' \
      '# Do not edit this file by hand.'
    if [ -f "$f" ]; then
      awk -v n="$name" '$1 == "module" || $1 == "kept" || $1 == "pending" { skip = ($2 == n) } skip { next } /^#/ || NF == 0 { next } { print }' "$f"
    fi
    if [ -n "$ver" ]; then
      printf '%s %s %s\n' "$kw" "$name" "$ver"
      cat "$rows"
    fi
  } > "$tmp" || { _kit_mod_state_fail; return 1; }   # return-class: internal
  if ! awk '$1 == "module" || $1 == "kept" || $1 == "pending" { f = 1 } END { exit !f }' "$tmp"; then
    rm -f "$f" && [ ! -e "$f" ] || { _kit_mod_state_fail; return 1; }   # return-class: internal
  else
    mkdir -p "$(dirname "$f")" && cp "$tmp" "$f.kit-mod-new" && mv "$f.kit-mod-new" "$f" \
      || { _kit_mod_state_fail; return 1; }   # return-class: internal
  fi
}

# _kit_mod_state_ahead <name> <version> <rows-file> — add (or replace) a `pending` section for a module that is
# already enabled: the rows an upgrade is about to write, recorded BEFORE the files, so a kill between a file and
# the record that names it leaves the proof that the file is the module's. The module's own section is untouched.
# The next _kit_mod_state_put of the module drops it.
_kit_mod_state_ahead() {
  local name="$1" ver="$2" rows="$3" f tmp
  f="$(_kit_mod_state)"; tmp="$KIT_MOD_TMP/state.new"
  {
    awk -v n="$name" '$1 == "module" || $1 == "kept" || $1 == "pending" { skip = ($1 == "pending" && $2 == n) } skip { next } { print }' "$f"
    printf 'pending %s %s\n' "$name" "$ver"
    cat "$rows"
  } > "$tmp" || { _kit_mod_state_fail; return 1; }   # return-class: internal
  cp "$tmp" "$f.kit-mod-new" && mv "$f.kit-mod-new" "$f" \
    || { _kit_mod_state_fail; return 1; }   # return-class: internal
}
# _kit_mod_state_fail — the record could not be written: a refusal, or, for a caller that sets KIT_MOD_FAIL_RETURNS because
# it has already written other files and words the failure itself, nothing (the caller sees the status).
# KIT_MOD_STATE_NOTE, when set, is a sentence the refusal adds: what the caller had already done.
_kit_mod_state_fail() {
  [ -z "${KIT_MOD_FAIL_RETURNS:-}" ] || return 0
  kit_refuse 1 module-write-failed "Error: could not write $KIT_MOD_STATE_REL.${KIT_MOD_STATE_NOTE:+ $KIT_MOD_STATE_NOTE}" "Next: check the permissions of process/ and the temp directory, then re-run."
}

# ── the manifest and the plan ─────────────────────────────────────────────────

_kit_mod_bad() {  # <name> <what>
  kit_refuse 1 module-manifest-bad \
    "Error: modules/$1/module.manifest: $2" \
    "Next: fix the manifest (process/MODULES.md § Writing a module says what each line takes), or restore the module from the release; nothing was changed."
}

# _kit_mod_stamp — sets KMS_PREFIX, KMS_TRUNK, KMS_NAME from what kit-init stamped, or all empty
# when this tree has not been stamped (the placeholders then stay in what is placed).
_kit_mod_stamp() {
  local cfg="$KIT_MOD_ROOT/scripts/config.sh" line
  KMS_PREFIX=""; KMS_TRUNK=""; KMS_NAME=""
  [ -f "$cfg" ] || return 0
  line="$(sed -n 's/^# Stamped by scripts\/kit-init\.sh on [^ ]* .* prefix \([^ ,]*\), trunk \([^ ]*\) (kit-init.*$/\1 \2/p' "$cfg" | head -1)"
  [ -n "$line" ] || return 0
  KMS_PREFIX="${line%% *}"; KMS_TRUNK="${line#* }"
  KMS_NAME="$(sed -n 's/^PROJECT_NAME="${PROJECT_NAME:-\(.*\)}"$/\1/p' "$cfg" | head -1)"
  return 0
}
_kit_mod_esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
# _kit_mod_render <source> <destination> — the source with the stamped values put in.
_kit_mod_render() {
  if [ -z "$KMS_PREFIX" ]; then cp "$1" "$2"; return $?; fi   # return-class: relay
  LC_ALL=C sed -e "s|<PREFIX>|$(_kit_mod_esc "$KMS_PREFIX")|g" \
      -e "s|<trunk>|$(_kit_mod_esc "$KMS_TRUNK")|g" \
      -e "s|<project name>|$(_kit_mod_esc "$KMS_NAME")|g" "$1" > "$2"
}

# _kit_mod_status_folders — the board's status folders as the project's own scripts/lib/status-folders.sh
# declares them, `|`-separated, or nothing when that line cannot be read.
_kit_mod_status_folders() {
  sed -n "s/^KIT_STATUS_FOLDERS='\(.*\)'/\1/p" "$KIT_MOD_ROOT/scripts/lib/status-folders.sh" 2>/dev/null | head -1
}

# kit_mod_plan <name> <plan-file> — read modules/<name>/module.manifest in the source kit and write
# the plan: one tab-separated row per thing enabling places,
#   file<TAB><target><TAB><rendered copy><TAB>x|-            (a copied file)
#   block<TAB><target><TAB><rendered copy><TAB><slot>        (a marker block; the `gitignore` slot is the end of .gitignore)
# the rendered copies living under $KIT_MOD_TMP, <plan>.needs beside it (one line per extension point the
# module uses, for the reader check) and <plan>.reqs (one tab-separated record per requirement:
# kind R|A, id, severity required|optional|agent, check or call, how to get it, what is lost or what a pass
# looks like). Sets KIT_MOD_VERSION, KIT_MOD_PURPOSE and KIT_MOD_NOTES (the module's release-notes file, or
# nothing), and KIT_MOD_SETUP and KIT_MOD_SETUP_SH (the module's SETUP.md and setup.sh, as paths under the kit, or
# nothing). Refuses a manifest that is wrong.
kit_mod_plan() {
  local name="$1" plan="$2" dir man line key val src tgt slot extra n=0 gen mode seen tpl fmode folders rec
  _kit_mod_need_name "$name"
  dir="$(_kit_mod_src)/modules/$name"; man="$dir/module.manifest"
  [ -f "$man" ] || kit_refuse 1 module-unknown \
    "Error: this kit has no module '$name' (no modules/$name/module.manifest)." \
    "Next: ./scripts/module.sh list names the modules this kit ships."
  _kit_mod_stamp
  : > "$plan"
  KIT_MOD_VERSION=""; KIT_MOD_PURPOSE=""; KIT_MOD_NOTES=""; KIT_MOD_SETUP=""; KIT_MOD_SETUP_SH=""
  # The rendered copies live in a directory of this module's own, so two plans never share a name.
  local wd="$KIT_MOD_TMP/render-of-$name" mname="" roles_f kinds_f needs
  rm -rf "$wd"; mkdir -p "$wd" || _kit_mod_bad "$name" "could not make a scratch directory under $KIT_MOD_TMP."
  roles_f="$wd/gen-roles"; kinds_f="$wd/gen-kinds"; needs="$plan.needs"
  : > "$roles_f"; : > "$kinds_f"; : > "$needs"; : > "$plan.reqs"
  folders="$(_kit_mod_status_folders)"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *:*) ;; *) _kit_mod_bad "$name" "line '$line' is not '<key>: <value>'." ;; esac
    key="${line%%:*}"; val="$(printf '%s' "${line#*:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -n "$val" ] || _kit_mod_bad "$name" "'$key:' has no value."
    case "$key" in
      name)     mname="$val" ;;
      version)  grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' <<< "$val" || _kit_mod_bad "$name" "version '$val' is not X.Y.Z."
                KIT_MOD_VERSION="$val" ;;
      purpose)  KIT_MOD_PURPOSE="$val" ;;
      release-notes)
                _kit_mod_safe_rel "$val" && [ -f "$dir/$val" ] || _kit_mod_bad "$name" "release-notes '$val' is not a file of the module (plain characters, no '..')."
                ! _kit_mod_armed_component "$val" || _kit_mod_bad "$name" "release-notes '$val' carries a name a harness reads; store it disarmed."
                KIT_MOD_NOTES="$val" ;;
      requires|requires-agent)
                rec="$(_kit_mod_req_parse "$key" "$val")" || _kit_mod_bad "$name" "$key '$val': $rec"
                awk -F'\t' -v i="$(printf '%s' "$rec" | cut -f2)" '$2 == i { f = 1 } END { exit !f }' "$plan.reqs" \
                  && _kit_mod_bad "$name" "requires and requires-agent lines may not repeat an id: '$(printf '%s' "$rec" | cut -f2)' is declared twice."
                printf '%s\n' "$rec" >> "$plan.reqs" ;;
      role)     tgt="${val%%[[:space:]]*}"
                grep -qE '^[A-Za-z][A-Za-z0-9_-]*$' <<< "$tgt" || _kit_mod_bad "$name" "role '$tgt' is not a role tag (letters, digits, '_' and '-', opening with a letter)."
                printf '%s\n' "$val" >> "$roles_f"
                printf 'roles\n' >> "$needs" ;;
      evidence-kind)
                tgt="${val%%[[:space:]]*}"
                grep -qE '^[a-z][a-z0-9:_-]*$' <<< "$tgt" || _kit_mod_bad "$name" "evidence-kind '$tgt' is not a kind (lowercase letters, digits, ':', '_' and '-', opening with a letter)."
                printf '%s\n' "$val" >> "$kinds_f"
                printf 'kinds\n' >> "$needs" ;;
      file|arm|move-check|qa-cell)
                case "$val" in *" -> "*) ;; *) _kit_mod_bad "$name" "$key '$val' is not '<source> -> <target>'." ;; esac
                src="${val%% -> *}"; tgt="${val#* -> }"
                _kit_mod_safe_rel "$src" && [ -f "$dir/$src" ] || _kit_mod_bad "$name" "source '$src' is not a file of the module (plain characters, no '..')."
                ! _kit_mod_armed_component "$src" || _kit_mod_bad "$name" "source '$src' carries a name a harness reads (.claude, AGENTS.md, CLAUDE.md); store it disarmed (_claude/, _AGENTS.md)."
                _kit_mod_safe_rel "$tgt" || _kit_mod_bad "$name" "target '$tgt' is not a plain relative path."
                case "$key" in
                  arm)
                    grep -qE '^[0-9][0-9]-[A-Za-z0-9._-]+\.sh$' <<< "$tgt" || _kit_mod_bad "$name" "arm target '$tgt' is not NN-<name>.sh."
                    grep -qE '^# check-board-arm:[[:space:]]*(advisory|deciding)[[:space:]]*$' "$dir/$src" \
                      || _kit_mod_bad "$name" "arm source '$src' has no '# check-board-arm: advisory' or '# check-board-arm: deciding' line, and check-board.sh will not run an arm that declares neither."
                    tgt="scripts/check-board.d/$tgt"; printf 'arms\n' >> "$needs" ;;
                  move-check)
                    grep -qE '^[a-z_]+/[0-9][0-9]-[A-Za-z0-9._-]+\.sh$' <<< "$tgt" || _kit_mod_bad "$name" "move-check target '$tgt' is not <status folder>/NN-<name>.sh."
                    if [ -n "$folders" ]; then
                      case "|$folders|" in *"|${tgt%%/*}|"*) ;; *) _kit_mod_bad "$name" "move-check target '$tgt' names '${tgt%%/*}', which is no status folder of this project ($folders), so no move would read it." ;; esac
                    fi
                    printf 'move-check %s\n' "${tgt%%/*}" >> "$needs"; tgt="scripts/move-check.d/$tgt" ;;
                  qa-cell)
                    grep -qE '^[a-z][a-z0-9:_-]*/[0-9][0-9]-[A-Za-z0-9._-]+\.sh$' <<< "$tgt" || _kit_mod_bad "$name" "qa-cell target '$tgt' is not <evidence kind>/NN-<name>.sh."
                    printf 'qa-cell\n' >> "$needs"; tgt="scripts/qa-cell.d/$tgt" ;;
                esac
                n=$((n + 1)); gen="$wd/r$n"
                _kit_mod_render "$dir/$src" "$gen" || _kit_mod_bad "$name" "could not render $src (read it, and put the stamped values in) — the file is unreadable or the temp directory is not writable."
                fmode=-; [ -x "$dir/$src" ] && fmode=x
                printf 'file\t%s\t%s\t%s\n' "$tgt" "$gen" "$fmode" >> "$plan" ;;
      fragment)
                extra=""
                read -r tpl mode src extra <<FRAG_EOF
$val
FRAG_EOF
                [ -n "$src" ] && [ -z "$extra" ] || _kit_mod_bad "$name" "fragment '$val' is not '<PRD|ISSUE> <frontmatter|body-end|slot-<slot>> <source>'."
                case "$tpl" in PRD|ISSUE) ;; *) _kit_mod_bad "$name" "fragment template '$tpl' is not PRD or ISSUE." ;; esac
                slot=""
                case "$mode" in
                  frontmatter|body-end) ;;
                  slot-*) slot="${mode#slot-}"; _kit_mod_name_ok "$slot" || _kit_mod_bad "$name" "fragment mode '$mode' names no slot (slot-<slot>: lowercase letters, digits and '-')." ;;
                  *) _kit_mod_bad "$name" "fragment mode '$mode' is not frontmatter, body-end or slot-<slot>." ;;
                esac
                _kit_mod_safe_rel "$src" && [ -f "$dir/$src" ] || _kit_mod_bad "$name" "fragment source '$src' is not a file of the module."
                ! _kit_mod_armed_component "$src" || _kit_mod_bad "$name" "source '$src' carries a name a harness reads; store it disarmed."
                n=$((n + 1)); gen="$wd/r$n"
                _kit_mod_render "$dir/$src" "$gen" || _kit_mod_bad "$name" "could not render $src (read it, and put the stamped values in) — the file is unreadable or the temp directory is not writable."
                printf 'file\tprocess/fragments.d/%s/%s.%s\t%s\t-\n' "$tpl" "$name" "$mode" "$gen" >> "$plan"
                printf 'fragment %s %s\n' "$tpl" "$slot" >> "$needs" ;;
      block)
                extra=""
                read -r tgt slot src extra <<BLOCK_EOF
$val
BLOCK_EOF
                [ -n "$src" ] && [ -z "$extra" ] || _kit_mod_bad "$name" "block '$val' is not '<target file> <slot> <source>'."
                _kit_mod_safe_rel "$tgt" || _kit_mod_bad "$name" "block target '$tgt' is not a plain relative path."
                _kit_mod_name_ok "$slot" || _kit_mod_bad "$name" "block slot '$slot' is not a slot name."
                [ "$slot" != gitignore ] || _kit_mod_bad "$name" "block slot 'gitignore' is reserved for the .gitignore extension point; declare it with 'gitignore: <source>'."
                _kit_mod_safe_rel "$src" && [ -f "$dir/$src" ] || _kit_mod_bad "$name" "block source '$src' is not a file of the module."
                ! _kit_mod_armed_component "$src" || _kit_mod_bad "$name" "source '$src' carries a name a harness reads; store it disarmed."
                n=$((n + 1)); gen="$wd/r$n"
                _kit_mod_render "$dir/$src" "$gen" || _kit_mod_bad "$name" "could not render $src (read it, and put the stamped values in) — the file is unreadable or the temp directory is not writable."
                printf 'block\t%s\t%s\t%s\n' "$tgt" "$gen" "$slot" >> "$plan" ;;
      gitignore)
                _kit_mod_safe_rel "$val" && [ -f "$dir/$val" ] || _kit_mod_bad "$name" "gitignore source '$val' is not a file of the module."
                ! _kit_mod_armed_component "$val" || _kit_mod_bad "$name" "source '$val' carries a name a harness reads; store it disarmed."
                n=$((n + 1)); gen="$wd/r$n"
                _kit_mod_render "$dir/$val" "$gen" || _kit_mod_bad "$name" "could not render $val (read it, and put the stamped values in) — the file is unreadable or the temp directory is not writable."
                printf 'block\t.gitignore\t%s\tgitignore\n' "$gen" >> "$plan" ;;
      *)        _kit_mod_bad "$name" "unknown key '$key'." ;;
    esac
  done < "$man"
  [ "$mname" = "$name" ] || _kit_mod_bad "$name" "name is '${mname:-<missing>}', and the directory is '$name'."
  [ -n "$KIT_MOD_VERSION" ] || _kit_mod_bad "$name" "no version."
  [ -n "$KIT_MOD_PURPOSE" ] || _kit_mod_bad "$name" "no purpose."
  [ ! -f "$dir/SETUP.md" ] || KIT_MOD_SETUP="modules/$name/SETUP.md"
  [ ! -f "$dir/setup.sh" ] || KIT_MOD_SETUP_SH="modules/$name/setup.sh"
  # The generated files: one role layer and one evidence-kind layer, whole files so that removing one
  # is removing a file.
  if [ -s "$roles_f" ]; then
    n=$((n + 1)); gen="$wd/r$n"
    { printf '# The %s module (scripts/module.sh). Removed by disabling it.\n' "$name"; cat "$roles_f"; } > "$gen"
    printf 'file\tprocess/roles.d/%s\t%s\t-\n' "$name" "$gen" >> "$plan"
  fi
  if [ -s "$kinds_f" ]; then
    n=$((n + 1)); gen="$wd/r$n"
    { printf '# The %s module (scripts/module.sh). Removed by disabling it.\n' "$name"; cat "$kinds_f"; } > "$gen"
    printf 'file\tprocess/evidence-kinds.d/%s\t%s\t-\n' "$name" "$gen" >> "$plan"
  fi
  # No two things may land on one path, and none on the kit's own bookkeeping or on modules/.
  # (compared in lower case: on a case-insensitive filesystem `Note.md` and `note.md` are one path)
  seen="$(awk -F'\t' '$1 == "file" { print tolower($2) } $1 == "block" { print tolower($2) "#" $4 }' "$plan" | sort | uniq -d | head -1)"
  [ -z "$seen" ] || _kit_mod_bad "$name" "two entries write '$seen'."
  local lc
  while IFS="$(printf '\t')" read -r key tgt _ _; do
    [ "$key" = file ] || [ "$key" = block ] || continue
    lc="$(_kit_mod_lc "$tgt")"
    case " $(_kit_mod_lc "$KIT_MOD_RESERVED") " in *" $lc "*) _kit_mod_bad "$name" "target '$tgt' is the kit's own bookkeeping." ;; esac
    case "$lc" in modules/*|.git|.git/*) _kit_mod_bad "$name" "target '$tgt' is inside modules/ or .git/." ;; esac
  done < "$plan"
  return 0
}

# ── requirements ──────────────────────────────────────────────────────────────

# _kit_mod_trim — stdin, without leading and trailing white space.
_kit_mod_trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# _kit_mod_req_parse <key> <value> — the one reader of a requirement line. On success prints the record
#   R|A <TAB> id <TAB> required|optional|agent <TAB> check-or-call <TAB> how to get it <TAB> lost-or-pass
# and returns 0; otherwise prints why the line does not read and returns 1.
#   requires:       <id> | <shell check> | <how to get it> | required
#   requires:       <id> | <shell check> | <how to get it> | optional: <what is lost>
#   requires-agent: <id> | <the call> | <what a pass looks like> | <how to get it>
# The fields are split at ` | ` and read from both ends, so a shell check may itself contain a pipe. THE HOW AND THE
# `optional:` TEXT MAY NOT CONTAIN ` | `: a how that does is read as more check, and runs. Nothing can tell the two
# apart, so it is documented, not refused.
_kit_mod_req_parse() {
  local key="$1" val="$2" tab n=0 f id last how check pass i
  local -a F
  tab="$(printf '\t')"
  case "$val" in *"$tab"*) echo "a tab character cannot be in a requirement line."; return 1 ;; esac   # return-class: predicate
  while IFS= read -r f; do n=$((n + 1)); F[$n]="$(printf '%s' "$f" | _kit_mod_trim)"; done <<REQ_SPLIT_EOF
$(RV="$val" awk 'BEGIN { c = split(ENVIRON["RV"], a, / \| /); for (i = 1; i <= c; i++) print a[i] }')
REQ_SPLIT_EOF
  id="${F[1]}"
  case "$id" in
    ''|[!a-z0-9]*|*[!a-z0-9._-]*) echo "'$id' is not a requirement id (lowercase letters, digits, '.', '_' and '-')."; return 1 ;;   # return-class: predicate
  esac
  if [ "$key" = requires-agent ]; then
    [ "$n" -eq 4 ] || { echo "takes '<id> | <the call> | <what a pass looks like> | <how to get it>': four fields split at ' | ', not $n."; return 1; }   # return-class: predicate
    check="${F[2]}"; pass="${F[3]}"; how="${F[4]}"
    { [ -n "$check" ] && [ -n "$pass" ] && [ -n "$how" ]; } || { echo "a field is empty."; return 1; }   # return-class: predicate
    printf 'A\t%s\tagent\t%s\t%s\t%s\n' "$id" "$check" "$how" "$pass"
    return 0
  fi
  [ "$n" -ge 4 ] || { echo "takes '<id> | <shell check> | <how to get it> | required' or '... | optional: <what is lost>': at least four fields split at ' | ', not $n."; return 1; }   # return-class: predicate
  last="${F[$n]}"; how="${F[$((n - 1))]}"; check=""
  i=2
  while [ "$i" -le $((n - 2)) ]; do check="${check:+$check | }${F[$i]}"; i=$((i + 1)); done
  { [ -n "$check" ] && [ -n "$how" ]; } || { echo "the check or the way to get it is empty."; return 1; }   # return-class: predicate
  case "$last" in
    required) printf 'R\t%s\trequired\t%s\t%s\t\n' "$id" "$check" "$how" ;;
    optional:*)
      pass="$(printf '%s' "${last#optional:}" | _kit_mod_trim)"
      [ -n "$pass" ] || { echo "'optional:' must say what is lost without it."; return 1; }   # return-class: predicate
      printf 'R\t%s\toptional\t%s\t%s\t%s\n' "$id" "$check" "$how" "$pass" ;;
    *) echo "the last field is '$last', which is neither 'required' nor 'optional: <what is lost>'."; return 1 ;;   # return-class: predicate
  esac
  return 0
}

# _kit_mod_check_seconds — how long a check may run: KIT_MOD_CHECK_SECONDS when it is a positive integer, else 10.
_kit_mod_check_seconds() {
  case "${KIT_MOD_CHECK_SECONDS:-}" in ''|*[!0-9]*|0*) echo 10 ;; *) echo "$KIT_MOD_CHECK_SECONDS" ;; esac
}

# _kit_mod_probe <shell check> — run it and report: 0 it held, 1 it failed, 2 it did not finish in time and the
# kit stopped waiting. No input, output discarded, in the project's top directory, under `sh -c`, with the person's
# rights: nothing here stops it writing, and a child it started may outlive it (the limit ends the kit's wait).
_kit_mod_probe() {
  local limit pid ticks n=0 tick=0.1 rc
  limit="$(_kit_mod_check_seconds)"; ticks=$((limit * 10))
  sleep 0.1 2>/dev/null || { tick=1; ticks=$limit; }
  ( cd "$KIT_MOD_ROOT" 2>/dev/null && exec sh -c "$1" ) </dev/null >/dev/null 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$n" -ge "$ticks" ]; then
      pkill -P "$pid" 2>/dev/null
      kill "$pid" 2>/dev/null; sleep "$tick"; kill -9 "$pid" 2>/dev/null
      { wait "$pid"; } 2>/dev/null
      return 2   # return-class: predicate
    fi
    sleep "$tick"; n=$((n + 1))
  done
  rc=0; { wait "$pid"; } 2>/dev/null || rc=$?
  [ "$rc" -eq 0 ] || return 1   # return-class: predicate
  return 0
}

# _kit_mod_req_run <reqs-file> <results-file> — run the checks of a plan's requirements. One line per requirement:
#   holds|fails|timeout|agent <TAB> id <TAB> severity <TAB> check-or-call <TAB> how <TAB> lost-or-pass
# An agent check is not run: only an agent can make the call.
_kit_mod_req_run() {
  local kind id sev check how extra tab st rc
  tab="$(printf '\t')"
  : > "$2"
  while IFS="$tab" read -r kind id sev check how extra; do
    [ -n "$kind" ] || continue
    if [ "$kind" = A ]; then st=agent
    else
      rc=0; _kit_mod_probe "$check" 2>/dev/null || rc=$?
      case "$rc" in 0) st=holds ;; 2) st=timeout ;; *) st=fails ;; esac
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$st" "$id" "$sev" "$check" "$how" "$extra" >> "$2"
  done < "$1"
}

# _kit_mod_req_blockers <results-file> — one line for each required requirement that does not hold, or nothing.
_kit_mod_req_blockers() {
  local st id sev check how extra tab why
  tab="$(printf '\t')"
  while IFS="$tab" read -r st id sev check how extra; do
    [ "$sev" = required ] || continue
    case "$st" in
      fails)   why="its check failed" ;;
      timeout) why="its check did not finish within $(_kit_mod_check_seconds)s; a slow tool that is there needs KIT_MOD_CHECK_SECONDS set higher" ;;
      *)       continue ;;
    esac
    echo "  - $id: $how ($why: $check)"
  done < "$1"
  return 0
}

# _kit_mod_req_lines <results-file> <warn|status> — the report on the requirements, one line each. enable prints, with
# `warn`, the optional ones that do not hold and every agent check; status prints, with `status`, every requirement.
_kit_mod_req_lines() {
  local st id sev check how extra tab why
  tab="$(printf '\t')"
  while IFS="$tab" read -r st id sev check how extra; do
    case "$st" in
      holds)   if [ "$2" = status ]; then echo "  requirement $id: holds"; fi ;;
      agent)   echo "  agent check $id: $check — a pass looks like: $extra; if it fails: $how (a script cannot make this call; the module's first use does)" ;;
      fails|timeout)
        if [ "$st" = timeout ]; then why="its check did not finish within $(_kit_mod_check_seconds)s (KIT_MOD_CHECK_SECONDS sets the limit)"; else why="its check failed"; fi
        if [ "$sev" = required ]; then
          if [ "$2" = status ]; then echo "  requirement $id: NOT HOLDING (required) — $why; get it: $how"; fi
        elif [ "$2" = status ]; then echo "  requirement $id: not holding (optional) — $why; loses: $extra; get it: $how"
        else echo "  warning: optional requirement $id does not hold ($why): loses $extra. Get it: $how"; fi ;;
    esac
  done < "$1"
  return 0
}

# kit_mod_needs <name> — what the module declares it needs, for the catalogue: `id (required), id (optional), id (agent check)`
# in manifest order, or `declares nothing`. Reads the manifest's requirement lines through the reader enable uses
# and runs no check; a line that does not read is shown as `?`.
kit_mod_needs() {
  local man tab k v rec out="" sev
  man="$(_kit_mod_src)/modules/$1/module.manifest"
  tab="$(printf '\t')"
  [ -f "$man" ] || { echo "?"; return 0; }
  while IFS="$tab" read -r k v; do
    [ -n "$k" ] || continue
    if rec="$(_kit_mod_req_parse "$k" "$v")"; then
      sev="$(printf '%s' "$rec" | cut -f3)"; [ "$sev" != agent ] || sev="agent check"
      out="${out:+$out, }$(printf '%s' "$rec" | cut -f2) ($sev)"
    else out="${out:+$out, }?"; fi
  done <<NEEDS_EOF
$(awk '/^(requires|requires-agent):/ { k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t\r]*$/, "", v); print k "\t" v }' "$man")
NEEDS_EOF
  echo "${out:-declares nothing}"
}

# ── the readers ───────────────────────────────────────────────────────────────

# _kit_mod_reader_blockers <needs-file> — one line per extension point the module uses whose reader is
# missing from THIS project's copy of the kit, nothing when every reader is there. A project that took
# an older kit and then enabled a module would otherwise get a check that is placed and never run; the
# reader is found by the token it must carry, in the file that holds it.
_kit_mod_reader_blockers() {
  local point a b f tok why
  {
    sort -u "$1" | while read -r point a b; do
      case "$point" in
        roles)
          printf '%s|%s|%s\n' scripts/githooks/commit-msg kit_role_extend "the commit-msg hook would not accept the module's role" \
                              scripts/check-board.sh kit_role_extend "check-board.sh would report the module's role as lacking a [Role] prefix" \
                              scripts/lib/role-set.sh roles.d "the role set would not read process/roles.d/" ;;
        kinds)
          printf '%s|%s|%s\n' scripts/lib/qa-gate.sh kit_qa_evidence_kinds "the QA gate would not accept the module's evidence kind" ;;
        arms)
          printf '%s|%s|%s\n' scripts/check-board.sh check-board.d "check-board.sh would not run the module's arm" ;;
        move-check)
          printf '%s|%s|%s\n' scripts/lib/addon-check.sh kit_move_checks "no move check would run" \
                              scripts/move-issue.sh kit_move_checks "the board mover would not run the module's move check" \
                              scripts/subtask.sh kit_move_checks "a slice move would not run the module's move check"
          [ "$a" != qa_complete ] || printf '%s|%s|%s\n' scripts/finish-pr.sh kit_move_checks "the landing script would not run the module's qa_complete check"
          [ "$a" != done ] || printf '%s|%s|%s\n' scripts/archive.sh kit_move_checks "the archive sweep would not run the module's done check" ;;
        qa-cell)
          printf '%s|%s|%s\n' scripts/lib/addon-check.sh kit_addon_check_run "no cell check would run" \
                              scripts/lib/qa-gate.sh qa-cell.d "the QA gate would not run the module's cell check" ;;
        fragment)
          printf '%s|%s|%s\n' scripts/lib/card-head.sh kit_card_fragments "no fragment would be minted"
          if [ "$a" = PRD ]; then printf '%s|%s|%s\n' scripts/new-prd.sh kit_card_fragments "new-prd.sh would not mint the module's PRD fragment"
          else printf '%s|%s|%s\n' scripts/new-issue.sh kit_card_fragments "new-issue.sh would not mint the module's card fragment"; fi
          if [ -n "$b" ]; then printf '%s|%s|%s\n' ".claude/templates/$a.template.md" "<!-- KIT-MODULES:$b" "the $a template has no '$b' slot line to place the module's fragment at"; fi ;;
      esac
    done
  } | sort -u | while IFS='|' read -r f tok why; do
    if [ ! -f "$KIT_MOD_ROOT/$f" ]; then echo "  $f is absent: $why"
    elif ! grep -qF -- "$tok" "$KIT_MOD_ROOT/$f"; then echo "  $f does not carry '$tok': $why"; fi
  done
  return 0
}

# ── conflicts ─────────────────────────────────────────────────────────────────

# _kit_mod_lc <text> — lower case, because a case-insensitive filesystem reads `.GIT/` as `.git/`.
_kit_mod_lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# _kit_mod_is_core <path> — status 0 when the kit's shipped manifest lists the path (any case).
_kit_mod_is_core() {
  local m="$KIT_MOD_ROOT/process/KIT-MANIFEST"
  [ -f "$m" ] || return 1   # return-class: predicate
  awk -F'  ' -v p="$(_kit_mod_lc "$1")" '!/^#/ && tolower($2) == p { f = 1 } END { exit !f }' "$m"
}

# _kit_mod_slot_present <file> <slot> — status 0 when the file has the slot line.
_kit_mod_slot_present() {
  grep -qE "^<!-- KIT-MODULES:$2( |-->|[[:space:]]*\$)" "$1" 2>/dev/null
}

# _kit_mod_bid <name> <slot> — the id a block's markers carry: the module and the slot, so one module can
# put a block in each of two slots of one file and the two are not each other.
_kit_mod_bid() { printf '%s:%s' "$1" "$2"; }

# _kit_mod_block_blocker <host-file> <block-id> <slot> — why a block cannot be put in <host-file> now, in
# words, or nothing when it can. The one reader of that question: enable's conflict scan asks it before
# anything is written, so marker-block's own refusals, which come mid-write, are the ones that cannot happen.
_kit_mod_block_blocker() {
  local dst="$1" bid="$2" slot="$3"
  if [ ! -f "$dst" ] && [ "$slot" = gitignore ] && [ ! -e "$dst" ]; then return 0; fi
  if [ -L "$dst" ]; then echo "the file is a symbolic link, and writing the block would replace the link with a regular file"; return 0; fi
  if [ ! -f "$dst" ]; then echo "the file the block goes in does not exist"; return 0; fi
  if [ -s "$dst" ] && [ -n "$(tail -c1 "$dst" | tr -d '\n')" ]; then echo "the file does not end with a newline"; return 0; fi
  if kit_mb_has "$dst" "$bid"; then return 0; fi
  if [ "$(_kit_mb_state "$dst" "$bid")" != none ]; then echo "the file carries a lone, repeated or misordered marker for $bid"; return 0; fi
  [ "$slot" = gitignore ] || _kit_mod_slot_present "$dst" "$slot" || echo "the file has no '<!-- KIT-MODULES:$slot' slot line"
  return 0
}

# _kit_mod_ancestor_problem <target> — why a path under the project cannot take <target>: a parent that is a
# file, or a symbolic link (the write would land wherever it points). Nothing when all is well.
_kit_mod_ancestor_problem() {
  local d
  d="$(dirname "$1")"
  while [ "$d" != . ] && [ "$d" != / ]; do
    if [ -e "$KIT_MOD_ROOT/$d" ] && [ ! -d "$KIT_MOD_ROOT/$d" ]; then echo "$d is a file, so $1 cannot be placed under it"; return 0; fi
    if [ -L "$KIT_MOD_ROOT/$d" ]; then echo "$d is a symbolic link, so $1 would land wherever it points"; return 0; fi
    d="$(dirname "$d")"
  done
  return 0
}

# _kit_mod_file_is_ours <rendered copy> <target> <recorded sha> — status 0 when the target is a plain file
# holding the planned bytes, or the bytes the record says an earlier run of this module wrote there (an
# interrupted enable, or a file a disable kept that has been put back as it was).
_kit_mod_file_is_ours() {
  [ -f "$2" ] && [ ! -L "$2" ] || return 1   # return-class: predicate
  cmp -s "$1" "$2" && return 0
  [ -n "$3" ] && [ "$(_kit_mod_sha "$2")" = "$3" ]
}

# _kit_mod_rec_sha <rows-text> <kind> <path> [<slot>] — the sha a record row holds for a path, or nothing.
_kit_mod_rec_sha() {
  printf '%s\n' "$1" | awk -v k="$2" -v p="$3" -v s="${4:-}" '$1 == k && $3 == p && (k == "file" || $4 == s) { print $2; exit }'
}

# _kit_mod_case_problem <target> <file|block> — why a path is spelt in another case than the project spells it, or nothing: a
# directory above the target, or a block's host, whose name differs only in case from an entry the project has. Placed as
# written, the record would carry a spelling no path of the project has (and, where case counts, a file the project does not
# read). A new file's own name is not asked: one that exists is refused as occupied, one that does not is the module's to name.
_kit_mod_case_problem() {
  local rest="$1" d="" comp ents e exact twin
  while [ -n "$rest" ]; do
    comp="${rest%%/*}"
    if [ "$rest" = "$comp" ]; then
      [ "$2" = block ] || return 0
      rest=""
    else rest="${rest#*/}"; fi
    ents="$(ls -A "$KIT_MOD_ROOT${d:+/${d%/}}" 2>/dev/null || true)"
    exact=""; twin=""
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      if [ "$e" = "$comp" ]; then exact=1
      elif [ -z "$twin" ] && [ "$(_kit_mod_lc "$e")" = "$(_kit_mod_lc "$comp")" ]; then twin="$e"; fi
    done <<CASE_ENTS_EOF
$ents
CASE_ENTS_EOF
    if [ -z "$exact" ] && [ -n "$twin" ]; then
      echo "$1 spells '$d$comp' where this project has '$d$twin': the record would carry a spelling no path here has, and status and disable would not find it. Use the project's spelling in the module's manifest."
      return 0
    fi
    d="$d$comp/"
  done
  return 0
}

# _kit_mod_role_clash <role layer file> — one line per role tag the layer declares that the project's role set already carries
# (scripts/githooks/commit-msg's base set, or process/ROLES; any case), or nothing. Such a tag stays in force when the module
# is disabled, and a disable keeps the whole layer for as long as history carries it.
_kit_mod_role_clash() {
  local t b where base rs
  rs="$(dirname "${BASH_SOURCE[0]}")/role-set.sh"
  [ -f "$rs" ] || return 0   # a copy of this library with no role-set reader beside it cannot read the base set, so it does not judge
  # shellcheck source=role-set.sh
  . "$rs" || return 0
  base="$(_kit_role_base "$KIT_MOD_ROOT")"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    where=""
    case "|$(_kit_mod_lc "$base")|" in *"|$(_kit_mod_lc "$t")|"*) where="the base set in scripts/githooks/commit-msg" ;; esac
    if [ -z "$where" ]; then
      while IFS= read -r b; do
        [ -n "$b" ] && [ "$(_kit_mod_lc "$b")" = "$(_kit_mod_lc "$t")" ] && where="process/ROLES"
      done <<ROLE_CLASH_EOF
$(_kit_mod_role_tags "$KIT_MOD_ROOT/process/ROLES")
ROLE_CLASH_EOF
    fi
    [ -z "$where" ] || echo "  the role '$t' is already in this project's role set ($where), so the module would add nothing and a disable would keep its layer while history carries the tag. Drop the role line from the module's manifest, or give the seat a tag of its own."
  done <<ROLE_LAYER_EOF
$(_kit_mod_role_tags "$1")
ROLE_LAYER_EOF
  return 0
}

# _kit_mod_conflicts <plan> <name> — print one line per row that cannot be placed; nothing when
# all can. A target that EXISTS is a conflict whatever it holds: enable cannot tell a file it wrote from one
# the project had, or one another module placed, so it takes none of them. The one exception is a path THIS
# module's record names, as written by an interrupted enable or kept by a disable, that still holds the
# bytes the record says: that is the module's own, finished or taken up again, not refused.
_kit_mod_conflicts() {
  local kind tgt rend extra dst name="$2" why bid pendr keptr rec prob
  pendr="$(kit_mod_pending_rows "$name")"; keptr="$(kit_mod_kept_rows "$name")"
  while IFS="$(printf '\t')" read -r kind tgt rend extra; do
    dst="$KIT_MOD_ROOT/$tgt"
    prob="$(_kit_mod_ancestor_problem "$tgt")"
    if [ -n "$prob" ]; then echo "  $prob"; continue; fi
    prob="$(_kit_mod_case_problem "$tgt" "$kind")"
    if [ -n "$prob" ]; then echo "  $prob"; continue; fi
    if [ "$kind" = file ] && [ "$tgt" = "process/roles.d/$name" ]; then
      prob="$(_kit_mod_role_clash "$rend")"
      if [ -n "$prob" ]; then echo "$prob"; continue; fi
    fi
    if [ "$kind" = file ]; then
      if _kit_mod_is_core "$tgt"; then echo "  $tgt is one of the kit's own files (process/KIT-MANIFEST lists it)"; continue; fi
      if [ -d "$dst" ]; then echo "  $tgt is a directory"; continue; fi
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        rec="$(_kit_mod_rec_sha "$pendr" file "$tgt")"
        if [ -n "$rec" ] && _kit_mod_file_is_ours "$rend" "$dst" "$rec"; then :
        elif [ -n "$rec" ]; then echo "  $tgt was written by an enable of $name that did not finish, and has changed since"
        else
          rec="$(_kit_mod_rec_sha "$keptr" file "$tgt")"
          if [ -n "$rec" ] && _kit_mod_file_is_ours "$rend" "$dst" "$rec"; then :
          elif [ -n "$rec" ]; then echo "  $tgt was left by an earlier disable of $name (you had edited it) and still differs from the module's copy"
          elif cmp -s "$rend" "$dst"; then echo "  $tgt already exists, byte-equal to the module's copy; enable takes no file it did not write — delete it so the module writes it"
          else echo "  $tgt exists and differs from the module's copy"; fi
        fi
      fi
    else
      bid="$(_kit_mod_bid "$name" "$extra")"
      why="$(_kit_mod_block_blocker "$dst" "$bid" "$extra")"
      if [ -n "$why" ]; then echo "  $tgt: $why"; continue; fi
      if kit_mb_has "$dst" "$bid"; then
        rec="$(_kit_mod_rec_sha "$pendr" block "$tgt" "$extra")"
        [ -n "$rec" ] || rec="$(_kit_mod_rec_sha "$keptr" block "$tgt" "$extra")"
        if [ -n "$rec" ] && { [ "$(_kit_mod_block_sha "$dst" "$bid")" = "$rec" ] || [ "$(_kit_mod_block_sha "$dst" "$bid")" = "$(_kit_mod_text_sha "$rend")" ]; }; then :
        else echo "  $tgt already holds a block for $name in slot $extra; enable takes no block it did not write — remove it so the module writes it"; fi
      fi
    fi
  done < "$1"
}

# _kit_mod_clean_strays <relative path> — remove what a killed run leaves beside a path: the module's own
# side file, and marker-block's.
_kit_mod_clean_strays() {
  local base="${KIT_MOD_ROOT:?}/${1:?}"
  rm -f "${base}.kit-mod-new" "${base}".kit-mb.*
}

# _kit_mod_put_block <host> <block id> <slot> <content file> — marker-block's insert; a .gitignore that does
# not exist is built aside and moved in whole, so a kill never leaves the empty file the insert starts from.
_kit_mod_put_block() {
  local dst="$1" bid="$2" slot="$3" rend="$4" t="$KIT_MOD_TMP/gitignore.new"
  if [ "$slot" = gitignore ] && [ ! -e "$dst" ]; then
    rm -f "${t:?}"
    ( kit_mb_insert "$t" "$bid" "$slot" "$rend" ) || return 1   # return-class: relay
    cp "$t" "${dst:?}.kit-mod-new" && mv "${dst:?}.kit-mod-new" "$dst"
  else
    kit_mb_insert "$dst" "$bid" "$slot" "$rend"
  fi
}

# _kit_mod_place_file <rendered copy> <destination> <x|-> — write the file beside its path and move it in, so
# a kill never leaves a half-written file at the path; <x> sets the executable bit. Status 1 when a step fails.
_kit_mod_place_file() {
  local rend="$1" dst="$2" mode="$3"
  mkdir -p "$(dirname "$dst")" && cp "$rend" "$dst.kit-mod-new" && { [ "$mode" != x ] || chmod +x "$dst.kit-mod-new"; } && mv "$dst.kit-mod-new" "$dst" \
    || return 1   # return-class: internal
}

# _kit_mod_unplace <placed-list> — take back what a failed enable placed (lines `file <path>` and
# `block <path> <id>`), newest first, so the failure leaves the tree as it found it.
_kit_mod_unplace() {
  local kind tgt id
  while IFS=' ' read -r kind tgt id; do
    [ -n "$kind" ] || continue
    _kit_mod_clean_strays "$tgt"
    if [ "$kind" = file ]; then rm -f "${KIT_MOD_ROOT:?}/$tgt"; _kit_mod_prune "$tgt"
    else ( kit_mb_remove "$KIT_MOD_ROOT/$tgt" "$id" ) >/dev/null 2>&1 || true; fi
  done <<UNPLACE_EOF
$(awk '{ l[NR] = $0 } END { for (i = NR; i >= 1; i--) print l[i] }' "$1")
UNPLACE_EOF
}

# _kit_mod_rows_put <rows-file> <kind> <sha> <path> [<slot>] — set the row for a path (replacing a row of
# the same path, and slot for a block), in place.
_kit_mod_rows_put() {
  local f="$1" kind="$2" sha="$3" tgt="$4" slot="${5:-}" t="$1.new"
  awk -v k="$kind" -v p="$tgt" -v s="$slot" '!($1 == k && $3 == p && (k == "file" || $4 == s))' "$f" > "$t"
  if [ "$kind" = file ]; then printf 'file %s %s\n' "$sha" "$tgt" >> "$t"; else printf 'block %s %s %s\n' "$sha" "$tgt" "$slot" >> "$t"; fi
  mv "$t" "$f"
}

# kit_mod_would_place <name> — what stops enable placing <name> in this tree as it stands, one line each, or
# nothing: the question kit-init asks before it writes anything. It reads the manifest as enable does (one that
# does not read refuses and exits, so call it in a subshell), leaves out the blanks check (kit-init fills the
# blanks in before it enables), and adds one question enable does not ask, whether git would add what enable
# places: a file an ignore rule matches would be left out of the initialization commit. The paths after the name are ones
# the caller itself writes before it enables the module; a module target among them is reported.
kit_mod_would_place() {
  local name="$1" plan="$KIT_MOD_TMP/would-$1" kind tgt rend extra own
  shift
  kit_mod_plan "$name" "$plan"
  kit_mod_have_sha || echo "  no sha256 tool (shasum or sha256sum) is on this machine, and enable records one per file"
  _kit_mod_req_run "$plan.reqs" "$KIT_MOD_TMP/would-req-$name"
  _kit_mod_req_blockers "$KIT_MOD_TMP/would-req-$name"
  _kit_mod_reader_blockers "$plan.needs"
  _kit_mod_conflicts "$plan" "$name"
  while IFS="$(printf '\t')" read -r kind tgt rend extra; do
    if git -C "$KIT_MOD_ROOT" check-ignore -q --no-index -- "$tgt" 2>/dev/null; then
      echo "  $tgt is ignored by git, so the initialization commit would leave it out"
    fi
    for own in "$@"; do
      if _kit_mod_same_path "$tgt" "$own"; then echo "  $tgt: kit-init writes it itself before it enables the module, which would then find it occupied"; fi
    done
  done < "$plan"
  return 0
}

# _kit_mod_same_path <a> <b> — status 0 when two relative paths name one file here: the same spelling, or, on a
# filesystem that reads upper and lower case as one (the project's `.git` is found under `.GIT`, as the same directory), the same
# in lower case. A directory a project made and named `.GIT` on a filesystem that tells the two apart is not that.
_kit_mod_same_path() {
  [ "$1" = "$2" ] && return 0
  [ "$KIT_MOD_ROOT/.GIT" -ef "$KIT_MOD_ROOT/.git" ] && [ "$(_kit_mod_lc "$1")" = "$(_kit_mod_lc "$2")" ]
}

# _kit_mod_path_under <path> <directory> — status 0 when <path> is below <directory> (one path here, in the sense above).
_kit_mod_path_under() {
  local d="$1"
  while [ "$d" != . ] && [ "$d" != / ]; do
    d="$(dirname "$d")"
    [ "$d" != . ] || return 1   # return-class: predicate
    _kit_mod_same_path "$d" "$2" && return 0
  done
  return 1   # return-class: predicate
}

# _kit_mod_ignores <ignore block file> <path> — status 0 when git would ignore <path> under the patterns in the file.
_kit_mod_ignores() {
  local g="$KIT_MOD_TMP/ignore-probe"
  rm -rf "${g:?}"; mkdir -p "$g" && git -C "$g" init -q . >/dev/null 2>&1 && cp "$1" "$g/.gitignore" || return 1   # return-class: predicate
  git -C "$g" check-ignore -q --no-index -- "$2" 2>/dev/null
}

# kit_mod_plans_collide <name>… — one line per pair of modules whose plans cannot both be placed, nothing when none does: a
# file on one path, a file below another's file (a directory the second cannot make), and an ignore block that covers a path
# the other places (the initialization commit would leave it out) — the questions kit_mod_would_place cannot ask of one
# module alone. Reads the plans kit_mod_would_place left in $KIT_MOD_TMP; a name with no plan (a module it refused) is left out.
kit_mod_plans_collide() {
  local n kind tgt rend extra tab i j nm=() tg=() gn=() gr=()
  tab="$(printf '\t')"
  for n in "$@"; do
    [ -f "$KIT_MOD_TMP/would-$n" ] || continue
    while IFS="$tab" read -r kind tgt rend extra; do
      if [ "$kind" = file ]; then nm+=("$n"); tg+=("$tgt")
      elif [ "$kind" = block ] && [ "$tgt" = .gitignore ] && [ "$extra" = gitignore ]; then gn+=("$n"); gr+=("$rend"); fi
    done < "$KIT_MOD_TMP/would-$n"
  done
  i=0
  while [ "$i" -lt "${#nm[@]}" ]; do
    j=$((i + 1))
    while [ "$j" -lt "${#nm[@]}" ]; do
      if [ "${nm[$i]}" != "${nm[$j]}" ]; then
        if _kit_mod_same_path "${tg[$i]}" "${tg[$j]}"; then
          echo "  module ${nm[$i]} places ${tg[$i]} and module ${nm[$j]} places ${tg[$j]}: one path here, so the second would find it occupied"
        elif _kit_mod_path_under "${tg[$j]}" "${tg[$i]}"; then
          echo "  module ${nm[$i]} places ${tg[$i]} and module ${nm[$j]} places ${tg[$j]}: the first is a file, so the second has no directory to go in"
        elif _kit_mod_path_under "${tg[$i]}" "${tg[$j]}"; then
          echo "  module ${nm[$j]} places ${tg[$j]} and module ${nm[$i]} places ${tg[$i]}: the first is a file, so the second has no directory to go in"
        fi
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
  i=0
  while [ "$i" -lt "${#gn[@]}" ]; do
    j=0
    while [ "$j" -lt "${#nm[@]}" ]; do
      if [ "${gn[$i]}" != "${nm[$j]}" ] && _kit_mod_ignores "${gr[$i]}" "${tg[$j]}"; then
        echo "  module ${gn[$i]}'s .gitignore block ignores ${tg[$j]}, which module ${nm[$j]} places: the initialization commit would leave it out"
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
  return 0
}

# ── enable ────────────────────────────────────────────────────────────────────

# kit_mod_enable <name> — place the module, register it, record it. Idempotent: an enabled module is
# a no-op with a message; an interrupted enable is finished. Sets KIT_MOD_TOUCHED (the paths written, one
# per line, plus the record).
kit_mod_enable() {
  local name="$1" plan="$KIT_MOD_TMP/plan" rows="$KIT_MOD_TMP/rows" placed_f="$KIT_MOD_TMP/placed" conflicts blockers kind tgt rend extra dst placed=0 blocks=0 bid out resuming=0 sha has next_text unfilled=""
  KIT_MOD_TOUCHED=""; KIT_MOD_STATE_NOTE=""
  _kit_mod_clean_strays "$KIT_MOD_STATE_REL"   # before any refusal, as disable does: a killed run's side file of the record
  kit_mod_plan "$name" "$plan"
  if kit_mod_is_enabled "$name"; then
    echo "module: $name is already enabled (version $(kit_mod_enabled_version "$name")); nothing to do."
    if [ "$(kit_mod_enabled_version "$name")" != "$KIT_MOD_VERSION" ]; then
      echo "  This kit holds version $KIT_MOD_VERSION of it: placed files change through the kit upgrade, not through enable."
    fi
    _kit_mod_missing_hint "$name" "$plan"
    return 0
  fi
  kit_mod_have_sha || kit_refuse 1 module-no-sha-tool \
    "Error: no sha256 tool (shasum or sha256sum) is on this machine, and enable records one per file so that disable can tell an edited file from the module's." \
    "Next: install one (shasum ships with perl and macOS; sha256sum with coreutils), then re-run."
  if kit_mod_is_pending "$name"; then resuming=1; echo "module: an earlier enable of $name did not finish; finishing it."; fi
  _kit_mod_req_run "$plan.reqs" "$KIT_MOD_TMP/req-results"
  blockers="$(_kit_mod_req_blockers "$KIT_MOD_TMP/req-results")"
  if [ -n "$blockers" ]; then
    if [ "$resuming" = 1 ]; then next_text="get each one above, then run ./scripts/module.sh enable $name again to finish it, or ./scripts/module.sh disable $name to take it back."
    else next_text="get each one above (the text after the colon says how), then run ./scripts/module.sh enable $name again."; fi
    kit_refuse 1 module-requires-missing \
      "Error: module $name needs what this machine does not have:" \
      "$blockers" \
      "  NOTHING WAS CHANGED BY THE KIT (process/contracts/module-lifecycle.md § 2 says what a check may do)." \
      "Next: $next_text"
  fi
  if [ -z "$KMS_PREFIX" ]; then
    while IFS="$(printf '\t')" read -r kind tgt rend extra; do
      if grep -qE '<PREFIX>|<trunk>|<project name>' "$rend"; then unfilled="${unfilled}  $tgt
"; fi
    done < "$plan"
    [ -z "$unfilled" ] || kit_refuse 1 module-before-kit-init \
      "Error: this project has not been through scripts/kit-init.sh, and these files of module $name carry its <PREFIX>, <trunk> or <project name> blanks, which kit-init fills in:" \
      "$unfilled" \
      "  They would be placed with the blanks open, and kit-init's later stamp would read as an edit of yours. NOTHING WAS CHANGED." \
      "Next: run ./scripts/kit-init.sh first (process/SEED.md), then ./scripts/module.sh enable $name."
  fi
  blockers="$(_kit_mod_reader_blockers "$plan.needs")"
  [ -z "$blockers" ] || kit_refuse 1 module-reader-missing \
    "Error: module $name adds to extension points whose readers this project's copy of the kit does not have, so its checks would be placed and never run:" \
    "$blockers" \
    "  NOTHING WAS CHANGED." \
    "Next: merge each file named above from the kit release (a kit upgrade lists them as merge items), then run ./scripts/module.sh enable $name again."
  conflicts="$(_kit_mod_conflicts "$plan" "$name")"
  if [ -n "$conflicts" ]; then
    if [ "$resuming" = 1 ]; then
      next_text="run ./scripts/module.sh disable $name to take back the unfinished enable (it keeps and names what you changed), or put each path named above back as it was, then run ./scripts/module.sh enable $name again."
    else
      next_text="for a path left by an earlier disable, restore the module's copy over it (./scripts/module.sh status $name shows what it kept) or delete it; for any other path named above, move or merge it yourself (it is not the module's); for a spelling or a role the line itself says to change, fix modules/$name/module.manifest; then run ./scripts/module.sh enable $name again."
    fi
    kit_refuse 1 module-enable-conflict \
      "Error: module $name cannot be placed; these paths are not its to take:" \
      "$conflicts" \
      "  NOTHING WAS CHANGED." \
      "Next: $next_text"
  fi
  # The record goes down first, as `pending`, and grows by one row BEFORE each path is written, naming it
  # with the sha256 it will hold. A kill therefore leaves a record of every path the run reached (at most
  # one of them not yet written) and of none it did not, which is what makes a rerun safe to trust it.
  : > "$placed_f"
  # A rerun starts from the rows the interrupted run recorded, so a kill during it loses none.
  if [ "$resuming" = 1 ]; then kit_mod_pending_rows "$name" > "$rows"; else : > "$rows"; fi
  _kit_mod_state_put "$name" "$KIT_MOD_VERSION" "$rows" pending
  while IFS="$(printf '\t')" read -r kind tgt rend extra; do
    dst="$KIT_MOD_ROOT/$tgt"
    if [ "$kind" = file ]; then sha="$(_kit_mod_sha "$rend")"; else sha="$(_kit_mod_text_sha "$rend")"; fi
    has=0
    if awk -v k="$kind" -v p="$tgt" -v s="$extra" '$1 == k && $3 == p && (k == "file" || $4 == s) { f = 1 } END { exit !f }' "$rows"; then has=1
    else
      _kit_mod_rows_put "$rows" "$kind" "$sha" "$tgt" "$extra"
      _kit_mod_state_put "$name" "$KIT_MOD_VERSION" "$rows" pending
    fi
    _kit_mod_clean_strays "$tgt"
    if [ "$kind" = file ]; then
      if [ -f "$dst" ] && cmp -s "$rend" "$dst"; then :
      else
        if ! _kit_mod_place_file "$rend" "$dst" "$extra"; then
          _kit_mod_clean_strays "$tgt"
          _kit_mod_unplace "$placed_f"
          KIT_MOD_STATE_NOTE="Could not write $tgt either; what this run had placed was taken back."
          [ "$resuming" = 1 ] || _kit_mod_state_put "$name" "" /dev/null
          kit_refuse 1 module-write-failed \
            "Error: could not write $tgt; what this run had placed was taken back." \
            "Next: fix the write failure (permissions, free space), then run ./scripts/module.sh enable $name again." \
            "  NOTHING WAS CHANGED."
        fi
        printf 'file %s\n' "$tgt" >> "$placed_f"
      fi
      placed=$((placed + 1))
    else
      bid="$(_kit_mod_bid "$name" "$extra")"
      if kit_mb_has "$dst" "$bid" && [ "$(_kit_mod_block_sha "$dst" "$bid")" = "$sha" ]; then :
      else
        if ! out="$( _kit_mod_put_block "$dst" "$bid" "$extra" "$rend" 2>&1 )"; then
          _kit_mod_unplace "$placed_f"
          KIT_MOD_STATE_NOTE="Could not put the block into $tgt either; what this run had placed was taken back."
          [ "$resuming" = 1 ] || _kit_mod_state_put "$name" "" /dev/null
          kit_refuse 1 module-write-failed \
            "Error: could not put module $name's block into $tgt; what this run had placed was taken back." \
            "$(printf '%s\n' "$out" | sed 's/^/  /')" \
            "Next: fix what is named above, then run ./scripts/module.sh enable $name again." \
            "  NOTHING WAS CHANGED."
        fi
        printf 'block %s %s\n' "$tgt" "$bid" >> "$placed_f"
      fi
      blocks=$((blocks + 1))
    fi
    # A path whose row an earlier run wrote holds the sha the plan gives it now.
    if [ "$has" = 1 ]; then
      _kit_mod_rows_put "$rows" "$kind" "$sha" "$tgt" "$extra"
      _kit_mod_state_put "$name" "$KIT_MOD_VERSION" "$rows" pending
    fi
    KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${tgt}
"
  done < "$plan"
  _kit_mod_state_put "$name" "$KIT_MOD_VERSION" "$rows" module
  KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${KIT_MOD_STATE_REL}
"
  echo "module: enabled $name $KIT_MOD_VERSION — $KIT_MOD_PURPOSE"
  echo "  placed $placed file(s), $blocks block(s); recorded in $KIT_MOD_STATE_REL"
  awk -F' ' '{ print "    " $3 }' "$rows" | sort -u
  _kit_mod_req_lines "$KIT_MOD_TMP/req-results" warn
  if [ -n "$KIT_MOD_SETUP" ]; then
    echo "  setup — the steps no script can do (modules/$name/SETUP.md):"
    sed -e '/^<!-- KIT-CLASS:.*-->$/d' -e 's/^/    /' "$(_kit_mod_src)/$KIT_MOD_SETUP"
  fi
  if [ -n "$KIT_MOD_SETUP_SH" ]; then
    echo "  setup script: sh $KIT_MOD_SETUP_SH   (nothing in the kit runs it; run it yourself, or have an agent run it on your yes)"
  fi
  return 0
}

# ── disable ───────────────────────────────────────────────────────────────────

# _kit_mod_touch_if_changed <path> — name the path in KIT_MOD_TOUCHED when git shows an uncommitted change in it: a path an
# earlier run removed still has to be staged by the run that finishes the disable.
_kit_mod_touch_if_changed() {
  [ -z "$(cd "$KIT_MOD_ROOT" && git status --porcelain --untracked-files=no -- ":(literal)$1" 2>/dev/null)" ] || KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${1}
"
}
_kit_mod_prune() {  # <relative path of a removed file> — remove the directories it leaves empty
  local d
  d="$(dirname "$1")"
  while [ "$d" != . ] && [ "$d" != / ]; do
    rmdir "$KIT_MOD_ROOT/$d" 2>/dev/null || break
    d="$(dirname "$d")"
  done
  return 0
}

# _kit_mod_role_tags <role layer file> — the tags a role layer declares, one per line.
_kit_mod_role_tags() {
  awk '{ sub(/\r$/, ""); sub(/#.*/, ""); if (NF && $1 ~ /^[A-Za-z][A-Za-z0-9_-]*$/) print $1 }' "$1" 2>/dev/null || true
}

# _kit_mod_history_uses_role <tag> — status 0 when a commit subject on this branch or on the remote trunk
# opens with `[<tag>] `. check-board's [e] judges every trunk commit against the role set as it is NOW, so a
# role that history uses cannot leave the set without the board reporting drift.
_kit_mod_history_uses_role() {
  local refs="HEAD" subjects
  git -C "$KIT_MOD_ROOT" rev-parse --verify --quiet "refs/remotes/origin/HEAD" >/dev/null 2>&1 && refs="$refs refs/remotes/origin/HEAD"   # card-read-exempt: the trunk's ref, not a card's branch
  # shellcheck disable=SC2086
  subjects="$(git -C "$KIT_MOD_ROOT" log --format=%s $refs 2>/dev/null || true)"
  grep -qF -- "[$1] " <<< "$subjects"
}

# _kit_mod_disable_blockers <rows-file> <name> — why a disable cannot run to the end, one line each, or
# nothing: a host that marker-block would refuse to rewrite. Asked before the first removal, so the refusal
# is the whole story and nothing has been removed.
_kit_mod_disable_blockers() {
  local kind sha tgt slot dst bid
  while read -r kind sha tgt slot; do
    [ "$kind" = block ] || continue
    dst="$KIT_MOD_ROOT/$tgt"; bid="$(_kit_mod_bid "$2" "$slot")"
    [ -f "$dst" ] || continue
    if [ -L "$dst" ]; then echo "  $tgt is a symbolic link"; continue; fi
    kit_mb_has "$dst" "$bid" || continue
    _kit_mod_sha_in "$(_kit_mod_block_sha "$dst" "$bid")" "$sha" || continue
    if [ -s "$dst" ] && [ -n "$(tail -c1 "$dst" | tr -d '\n')" ]; then echo "  $tgt does not end with a newline"; fi
  done < "$1"
  return 0
}

# kit_mod_disable <name> — take back what enable wrote, from an enabled module or an interrupted enable.
# Sets KIT_MOD_TOUCHED (paths removed or changed), KIT_MOD_KEPT (paths kept because the project edited them or
# because history uses the role) and KIT_MOD_ROLES_KEPT (the tags). What is kept stays recorded, under a
# `kept` line, so status can say whose it was. Idempotent.
kit_mod_disable() {
  local name="$1" rows="$KIT_MOD_TMP/rows" keptf="$KIT_MOD_TMP/kept-rows" failf="$KIT_MOD_TMP/failed-rows" donef="$KIT_MOD_TMP/done-rows" ver kind sha tgt slot dst bid removed=0 gone=0 was=module blockers tag t
  local failed="" mbout bsha
  KIT_MOD_TOUCHED=""; KIT_MOD_KEPT=""; KIT_MOD_ROLES_KEPT=""; KIT_MOD_STATE_NOTE=""
  _kit_mod_clean_strays "$KIT_MOD_STATE_REL"   # before the name is checked, as enable does: a run killed between the record's copy and its move leaves the copy, with no row naming it
  _kit_mod_need_name "$name"
  if ! kit_mod_is_enabled "$name" && ! kit_mod_is_pending "$name"; then
    echo "module: $name is not enabled; nothing to do."
    return 0
  fi
  kit_mod_have_sha || kit_refuse 1 module-no-sha-tool \
    "Error: no sha256 tool (shasum or sha256sum) is on this machine, so disable cannot tell the module's files from your edits, and it will not guess." \
    "Next: install one, then re-run ./scripts/module.sh disable $name."
  if kit_mod_is_pending "$name" && ! kit_mod_is_enabled "$name"; then was=pending; ver="$(awk -v n="$name" '$1 == "pending" && $2 == n { print $3; exit }' "$(_kit_mod_state)")"
  else ver="$(kit_mod_enabled_version "$name")"; fi
  kit_mod_rows_merged "$name" > "$rows"; : > "$keptf"; : > "$failf"; : > "$donef"
  blockers="$(_kit_mod_disable_blockers "$rows" "$name")"
  [ -z "$blockers" ] || kit_refuse 1 module-disable-blocked \
    "Error: module $name cannot be disabled yet; a block it placed sits in a file that cannot be rewritten as it is:" \
    "$blockers" \
    "  NOTHING WAS CHANGED." \
    "Next: fix each file named above (end it with a newline), then run ./scripts/module.sh disable $name again."
  while read -r kind sha tgt slot; do
    [ -n "$kind" ] || continue
    dst="$KIT_MOD_ROOT/$tgt"
    _kit_mod_clean_strays "$tgt"
    if [ "$kind" = file ]; then
      if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then gone=$((gone + 1)); printf 'file %s %s\n' "${sha%%|*}" "$tgt" >> "$donef"; _kit_mod_touch_if_changed "$tgt"; _kit_mod_prune "$tgt"; continue; fi
      if _kit_mod_sha_in "$(_kit_mod_sha "$dst")" "$sha"; then
        sha="$(_kit_mod_sha "$dst")"
        # A role layer that history uses stays: [e] would flag every commit under the role without it.
        if [ "$tgt" = "process/roles.d/$name" ]; then
          tag=""
          while IFS= read -r t; do
            if [ -n "$t" ] && _kit_mod_history_uses_role "$t"; then tag="${tag:+$tag }$t"; fi
          done <<ROLE_TAGS_EOF
$(_kit_mod_role_tags "$dst")
ROLE_TAGS_EOF
          if [ -n "$tag" ]; then
            KIT_MOD_ROLES_KEPT="$tag"
            KIT_MOD_KEPT="${KIT_MOD_KEPT}${tgt} (role layer in use by history)
"
            printf 'file %s %s\n' "$sha" "$tgt" >> "$keptf"
            continue
          fi
        fi
        # A removal that fails is not counted, and its row stays on the record: the file still acts.
        if rm -f "${dst:?}" && [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
          _kit_mod_prune "$tgt"
          removed=$((removed + 1)); KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${tgt}
"
          printf 'file %s %s\n' "$sha" "$tgt" >> "$donef"
        else
          failed="${failed}${tgt} (could not be removed)
"
          printf 'file %s %s\n' "$sha" "$tgt" >> "$failf"
        fi
      else
        KIT_MOD_KEPT="${KIT_MOD_KEPT}${tgt}
"
        printf 'file %s %s\n' "${sha%%|*}" "$tgt" >> "$keptf"
      fi
    else
      bid="$(_kit_mod_bid "$name" "$slot")"
      if [ ! -f "$dst" ] || ! kit_mb_has "$dst" "$bid"; then gone=$((gone + 1)); printf 'block %s %s %s\n' "${sha%%|*}" "$tgt" "$slot" >> "$donef"; _kit_mod_touch_if_changed "$tgt"; continue; fi
      if _kit_mod_sha_in "$(_kit_mod_block_sha "$dst" "$bid")" "$sha"; then
        bsha="$(_kit_mod_block_sha "$dst" "$bid")"
        # In a subshell: its refusal speaks for the one file, and says NOTHING WAS CHANGED, which is not true
        # of the run once other files have been removed.
        if mbout="$( kit_mb_remove "$dst" "$bid" 2>&1 )"; then
          removed=$((removed + 1)); KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${tgt}
"
          printf 'block %s %s %s\n' "$bsha" "$tgt" "$slot" >> "$donef"
        else
          failed="${failed}${tgt} (block $name, slot $slot: $(printf '%s' "$mbout" | sed -n '1p' | cut -c1-200))
"
          printf 'block %s %s %s\n' "$(_kit_mod_block_sha "$dst" "$bid")" "$tgt" "$slot" >> "$failf"
        fi
      else
        KIT_MOD_KEPT="${KIT_MOD_KEPT}${tgt} (block $name, slot $slot)
"
        printf 'block %s %s %s\n' "${sha%%|*}" "$tgt" "$slot" >> "$keptf"
      fi
    fi
  done < "$rows"
  if [ -n "$failed" ]; then
    KIT_MOD_STATE_NOTE="$removed file(s) and block(s) of $name were already removed, and these could not be: $(printf '%s' "$failed" | tr '\n' ';' | sed 's/;$//; s/;/; /g'). The record is unchanged; once they can be removed and the record written, running disable again retries them."
    # Every row stays recorded in the state it was in (enabled, or an enable that had not finished), the removed
    # ones too: a row is dropped only when the whole disable has finished, so an upgrade in between reads a removed
    # file as removed here, not as new in the module, and a re-run retries what failed.
    cat "$keptf" "$donef" >> "$failf"
    _kit_mod_state_put "$name" "$ver" "$failf" "$( [ "$was" = pending ] && echo pending || echo module )"
    KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${KIT_MOD_STATE_REL}
"
    kit_refuse 1 module-disable-incomplete \
      "Error: module $name was only partly disabled: $removed file(s) and block(s) were removed, and these could not be:" \
      "$(printf '%s' "$failed" | sed 's/^/    /')" \
      "  They still act, and $KIT_MOD_STATE_REL still records $name with all its rows." \
      "Next: make each path above removable — a file goes with the write permission of the directory that holds it, so check the directory's mode as well as the file's, and clear any immutable flag — then run ./scripts/module.sh disable $name again; what was removed stays removed."
  fi
  KIT_MOD_STATE_NOTE="$removed file(s) and block(s) of $name were already removed; the record is unchanged, so running disable again finishes it."
  if [ -s "$keptf" ]; then _kit_mod_state_put "$name" "$ver" "$keptf" kept; else _kit_mod_state_put "$name" "" /dev/null; fi
  KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${KIT_MOD_STATE_REL}
"
  echo "module: disabled $name$([ "$was" = pending ] && echo " (an enable that had not finished, taken back)")"
  echo "  removed $removed file(s) and block(s) byte-equal to what enable wrote; $gone already gone; $([ -s "$keptf" ] && echo "the kept ones stay recorded under 'kept $name' in" || echo "record dropped from") $KIT_MOD_STATE_REL"
  if [ -n "$KIT_MOD_KEPT" ]; then
    echo "  KEPT — each still acts (a kept role layer, arm or block stays in force) until you delete it; one you changed is yours now, and a role layer is kept while history uses its role:"
    printf '%s' "$KIT_MOD_KEPT" | sed 's/^/    /'
  fi
  if [ -n "$KIT_MOD_ROLES_KEPT" ]; then
    echo "  The role layer stays because commits on this branch or the trunk already carry [${KIT_MOD_ROLES_KEPT// /], [}]: check-board's [e] judges every trunk commit against today's role set, so removing it would report them as lacking a [Role] prefix."
    echo "  To retire the role on purpose: move its line into process/ROLES and delete process/roles.d/$name (the role stays), or delete the file and accept the [e] findings on those commits."
  fi
  return 0
}

# ── list and status ───────────────────────────────────────────────────────────

# kit_mod_available — `<name> <version> <purpose>` for every module the source kit holds.
kit_mod_available() {
  local f n v p
  for f in "$(_kit_mod_src)"/modules/*/module.manifest; do
    [ -f "$f" ] || continue
    n="$(basename "$(dirname "$f")")"
    v="$(sed -n 's/^version:[[:space:]]*//p' "$f" | head -1)"
    p="$(sed -n 's/^purpose:[[:space:]]*//p' "$f" | head -1)"
    printf '%s %s %s\n' "$n" "${v:-?}" "${p:-<no purpose>}"
  done
}

# _kit_mod_file_state <path> <sha> — intact | edited | missing, by the recorded sha; unjudged for a file that is
# there when the machine has no sha256 tool to judge it by.
_kit_mod_file_state() {
  if [ ! -e "$KIT_MOD_ROOT/$1" ]; then echo missing
  elif ! kit_mod_have_sha; then echo unjudged
  elif _kit_mod_sha_in "$(_kit_mod_sha "$KIT_MOD_ROOT/$1")" "$2"; then echo intact
  else echo edited; fi
}
_kit_mod_block_state() {  # <path> <block id> <sha>
  if [ ! -f "$KIT_MOD_ROOT/$1" ] || ! kit_mb_has "$KIT_MOD_ROOT/$1" "$2"; then echo missing
  elif ! kit_mod_have_sha; then echo unjudged
  elif _kit_mod_sha_in "$(_kit_mod_block_sha "$KIT_MOD_ROOT/$1" "$2")" "$3"; then echo intact
  else echo edited; fi
}

# _kit_mod_missing_hint <name> <plan-file> — when a recorded thing the plan still places is missing, a line naming both
# readings: the project removed it, or a disable stopped part-way. A row the plan no longer places is not counted: the
# upgrade's own item tells the project to delete it.
_kit_mod_missing_hint() {
  local name="$1" kind sha tgt slot n=0 m=0 st rf="$KIT_MOD_TMP/hint-rows"
  kit_mod_rows_merged "$name" > "$rf"
  while read -r kind sha tgt slot; do
    [ -n "$kind" ] || continue
    m=$((m + 1))
    awk -F'\t' -v k="$kind" -v p="$tgt" -v s="$slot" '$1 == k && $2 == p && (k == "file" || $4 == s) { f = 1 } END { exit !f }' "$2" || continue
    if [ "$kind" = file ]; then st="$(_kit_mod_file_state "$tgt" "$sha")"; else st="$(_kit_mod_block_state "$tgt" "$(_kit_mod_bid "$name" "$slot")" "$sha")"; fi
    [ "$st" != missing ] || n=$((n + 1))
  done < "$rf"
  rm -f "$rf"
  [ "$n" -eq 0 ] || echo "  $n of $m recorded things are missing: removed here (nothing to do if on purpose; git restores one), or left by a disable that stopped part-way (./scripts/module.sh disable $name finishes it)."
  return 0
}

# _kit_mod_status_rows <name> <rows-file> — one line per recorded row, with its state.
_kit_mod_status_rows() {
  local name="$1" kind sha tgt slot st
  kit_mod_have_sha || echo "  No sha256 tool (shasum or sha256sum) is on this machine, so status cannot judge a present file as intact or edited; install one and run it again."
  while read -r kind sha tgt slot; do
    [ -n "$kind" ] || continue
    if [ "$kind" = file ]; then st="$(_kit_mod_file_state "$tgt" "$sha")"; else st="$(_kit_mod_block_state "$tgt" "$(_kit_mod_bid "$name" "$slot")" "$sha")"; fi
    printf '  %-8s %s%s\n' "$st" "$tgt" "$([ "$kind" = block ] && echo " (block, slot $slot)")"
  done < "$2"
}

# kit_mod_stray_note — status changes no byte, so the record's side file that a killed run left is named, not removed.
kit_mod_stray_note() {
  if [ -e "${KIT_MOD_ROOT:?}/$KIT_MOD_STATE_REL.kit-mod-new" ]; then
    echo "note: $KIT_MOD_STATE_REL.kit-mod-new is the leftover of a killed run. Delete the file; ./scripts/module.sh enable <name> also removes it, but places that module if it is not enabled. Do not disable a working module for this."
  fi
  return 0
}

# kit_mod_status <name> — one module's record and the state of each thing it placed.
kit_mod_status() {
  local name="$1" kv
  _kit_mod_need_name "$name"
  if kit_mod_is_pending "$name" && ! kit_mod_is_enabled "$name"; then
    echo "module: $name is NOT enabled: an enable of it did not finish. Each recorded thing and its state:"
    kit_mod_pending_rows "$name" > "$KIT_MOD_TMP/status-rows"
    _kit_mod_status_rows "$name" "$KIT_MOD_TMP/status-rows"
    echo "  Next: ./scripts/module.sh enable $name finishes it; ./scripts/module.sh disable $name takes it back."
    return 0
  fi
  if ! kit_mod_is_enabled "$name"; then
    kv="$(kit_mod_kept_version "$name")"
    if [ -n "$kv" ]; then
      echo "module: $name is not enabled. It was disabled at $kv with these files kept (one you edited is yours now; a role layer stays while history uses its role), all still acting:"
      kit_mod_kept_rows "$name" > "$KIT_MOD_TMP/status-rows"
      _kit_mod_status_rows "$name" "$KIT_MOD_TMP/status-rows"
    else
      echo "module: $name is not enabled."
    fi
    [ -f "$(_kit_mod_src)/modules/$name/module.manifest" ] || echo "  (and this kit holds no module of that name)"
    return 0
  fi
  echo "module: $name $(kit_mod_enabled_version "$name") — enabled"
  if kit_mod_is_pending "$name"; then
    echo "  An upgrade of it did not finish: run the kit upgrade again (kit-upgrade.sh --into <this project>); it finishes what it started."
  fi
  kit_mod_rows_merged "$name" > "$KIT_MOD_TMP/status-rows"
  _kit_mod_status_rows "$name" "$KIT_MOD_TMP/status-rows"
  if [ -f "$(_kit_mod_src)/modules/$name/module.manifest" ]; then
    # a subshell: a manifest that does not read refuses and exits, and a report goes on with the next module
    if ( kit_mod_plan "$name" "$KIT_MOD_TMP/status-plan-$name" ) >/dev/null 2>"$KIT_MOD_TMP/status-err-$name"; then
      _kit_mod_missing_hint "$name" "$KIT_MOD_TMP/status-plan-$name"
      _kit_mod_req_run "$KIT_MOD_TMP/status-plan-$name.reqs" "$KIT_MOD_TMP/status-req-$name"
      _kit_mod_req_lines "$KIT_MOD_TMP/status-req-$name" status
    else
      echo "  requirements: not checked; the manifest does not read — $(sed -n '1p' "$KIT_MOD_TMP/status-err-$name")"
    fi
  else
    echo "  requirements: not checked; modules/$name is not in this project, so its manifest cannot be read."
  fi
  return 0
}

# ── upgrade: what the new kit changes for an enabled module ───────────────────
#
# kit-upgrade.sh sets KIT_MOD_ROOT to the project, KIT_MOD_SRC to the NEW kit and KIT_MOD_FAIL_RETURNS (so a failed
# write of the record comes back as a status, for the caller to word, instead of a refusal made after files were
# written), then for each enabled module:
#   kit_mod_upgrade_scan <name>                 compare what the new kit would place with the tree and the record (status 1: no scratch directory)
#   kit_mod_upgrade_apply <name>                record, then write, what the scan said may be written
#   kit_mod_upgrade_stage_record <name> <dir>   leave the module's final record in <dir>, a work order
#   kit_mod_upgrade_finish_record <name> <dir>  carry the work order out and remove it (run again after a kill)
#   kit_mod_upgrade_own_work <path>             whether a file with uncommitted changes holds only blocks a killed run wrote
# The scan writes nothing in the project. It leaves its findings in $KMU_DIR (= $KIT_MOD_TMP/up-<name>):
#   act    <action> TAB <kind> TAB <target> TAB <slot|-> TAB <rendered copy|-> TAB <x|-> TAB <why>
#          write    the file or block is as enable wrote it (or is new in the module) and can be placed
#          merge    the project's copy cannot be replaced: the new copy is staged for a person to merge
#          removed  recorded, present, and not placed by the new version: listed, never deleted
#   ahead  every row the upgrade is about to write, at the sha256 it will hold
#   rows   the module's rows once the upgrade is done (a merge item's row moves to the new copy then, so the next
#          upgrade raises an item only if the module changes the file again)
#   meta   old=<recorded version> new=<version in the new kit> notes=<release-notes file>
# and sets KMU_GONE (the new kit holds no such module), KMU_OLD_VERSION, KMU_VERSION and KMU_NOTES for the module just
# scanned; apply and finish read meta, so scanning another module in between changes nothing.
# A row is judged as process/contracts/module-lifecycle.md § 2 says, by three shas: REC (the record's), CUR (the
# tree's) and NEW (the new kit's copy as it would be placed here). A path the record does not name is never taken.
# THE ORDER MAKES A KILL SAFE. Before any file is written the record gains a `pending` section naming each path about
# to be written at the sha256 it will hold; the module's own rows are not touched, so a path may hold the sha256 of
# either (status and disable read both). The module's rows and version move once, after the checklist is on disk,
# from the work order staged beside it. A run killed anywhere is finished by running the upgrade again: a file already
# written reads CUR = NEW, the pending section is kept whole until then, and the work order is carried out whether or
# not the checklist existed.
KMU_GONE=""; KMU_DIR=""; KMU_OLD_VERSION=""; KMU_VERSION=""; KMU_NOTES=""; KMU_LOST=""
kit_mod_upgrade_scan() {
  local name="$1" d="$KIT_MOD_TMP/up-$1" kind tgt rend extra dst rec arec cur new bid why canwrite nr slot oldtxt aheadtxt tab twin renamed=""
  tab="$(printf '\t')"
  KMU_GONE=""; KMU_DIR="$d"; KMU_VERSION=""; KMU_NOTES=""
  rm -rf "$d"; mkdir -p "$d" || return 1   # return-class: relay
  : > "$d/act"; : > "$d/rows"
  KMU_OLD_VERSION="$(kit_mod_enabled_version "$name")"
  _kit_mod_rows_of "$name" module > "$d/old"; oldtxt="$(cat "$d/old")"
  # rows an earlier, killed run recorded ahead stay in the section until the upgrade is done
  aheadtxt="$(kit_mod_pending_rows "$name")"; printf '%s\n' "$aheadtxt" | awk 'NF' > "$d/ahead"
  if [ ! -f "$(_kit_mod_src)/modules/$name/module.manifest" ]; then KMU_GONE=1; return 0; fi
  kit_mod_plan "$name" "$d/plan"
  KMU_VERSION="$KIT_MOD_VERSION"; KMU_NOTES="$KIT_MOD_NOTES"
  printf 'old=%s\nnew=%s\nnotes=%s\n' "$KMU_OLD_VERSION" "$KMU_VERSION" "$KMU_NOTES" > "$d/meta"
  while IFS="$tab" read -r kind tgt rend extra; do
    dst="$KIT_MOD_ROOT/$tgt"; nr=""
    why="$(_kit_mod_ancestor_problem "$tgt")"
    if [ "$kind" = file ]; then
      slot="-"; rec="$(_kit_mod_rec_sha "$oldtxt" file "$tgt")"; new="$(_kit_mod_sha "$rend")"
      if [ -L "$dst" ] || [ -d "$dst" ]; then cur="@not-a-file"; [ -n "$why" ] || why="$tgt is a directory or a symbolic link"
      elif [ -f "$dst" ]; then cur="$(_kit_mod_sha "$dst")"; else cur=""; fi
      # A target spelt in another case than the record's, on a filesystem that reads the two as one file, is the
      # module's own file under a new spelling, not a new file and not a removed one.
      if [ -z "$rec" ]; then
        twin="$(_kit_mod_case_twin "$oldtxt" "$tgt")"
        if [ -n "$twin" ]; then rec="${twin%% *}"; renamed="$renamed${twin#* }
"; fi
      fi
    else
      slot="$extra"; bid="$(_kit_mod_bid "$name" "$slot")"
      rec="$(_kit_mod_rec_sha "$oldtxt" block "$tgt" "$slot")"; new="$(_kit_mod_text_sha "$rend")"
      if [ -f "$dst" ] && kit_mb_has "$dst" "$bid"; then cur="$(_kit_mod_block_sha "$dst" "$bid")"; else cur=""; fi
      [ -n "$why" ] || why="$(_kit_mod_block_blocker "$dst" "$bid" "$slot")"
    fi
    canwrite=1; [ -z "$why" ] || canwrite=0
    # A path an earlier, killed run recorded ahead of writing it is the module's own if the tree holds what that run
    # would have written, or (for one the record never named) what this run writes; one it never reached is written
    # like any other.
    arec="$(_kit_mod_rec_sha "$aheadtxt" "$kind" "$tgt" "$slot")"
    if [ -n "$arec" ] && [ -n "$cur" ] && _kit_mod_rec_has "$aheadtxt" "$kind" "$tgt" "$slot" "$cur"; then rec="$cur"
    elif [ -z "$rec" ] && [ -n "$arec" ] && [ "$cur" = "$new" ]; then rec="$arec"; fi
    if [ -n "$cur" ] && [ "$cur" = "$new" ]; then
      [ -z "$rec" ] || nr="$new"                                      # already the new copy; a copy the project had of its own stays its own
    elif [ -z "$cur" ]; then
      if [ -z "$rec" ]; then
        if [ "$canwrite" = 1 ]; then _kit_mod_up_act "$d/act" write "$kind" "$tgt" "$slot" "$rend" "$extra" ""; nr="$new"   # new in the module
          _kit_mod_up_row "$d/ahead" "$kind" "$new" "$tgt" "$slot"
        else _kit_mod_up_act "$d/act" merge "$kind" "$tgt" "$slot" "$rend" "$extra" "the module places it here and it cannot be placed: $why"; fi
      elif [ "$rec" != "$new" ]; then
        _kit_mod_up_act "$d/act" merge "$kind" "$tgt" "$slot" "$rend" "$extra" "this project removed it, and the module changed it"; nr="$new"
      else nr="$rec"                                                  # removed here, unchanged upstream: stays removed
      fi
    elif [ -n "$rec" ] && [ "$cur" = "$rec" ]; then
      if [ "$canwrite" = 0 ]; then
        _kit_mod_up_act "$d/act" merge "$kind" "$tgt" "$slot" "$rend" "$extra" "the module changed it and it cannot be replaced: $why"; nr="$rec"
      elif _kit_mod_up_role_loss "$name" "$tgt" "$dst" "$rend"; then
        _kit_mod_up_act "$d/act" merge "$kind" "$tgt" "$slot" "$rend" "$extra" "the new version no longer adds the role $KMU_LOST, which commits on this branch or the trunk carry; the layer is kept as it is, because check-board's [e] would report those commits without it, and the way to keep the role is a line for it in process/ROLES"
        nr="$rec"
      else
        _kit_mod_up_act "$d/act" write "$kind" "$tgt" "$slot" "$rend" "$extra" ""; nr="$new"   # as enable wrote it
        _kit_mod_up_row "$d/ahead" "$kind" "$new" "$tgt" "$slot"
      fi
    elif [ -n "$rec" ] && [ "$rec" = "$new" ]; then
      nr="$rec"                                                       # the module did not change it; the project's edit stays
    else
      _kit_mod_up_act "$d/act" merge "$kind" "$tgt" "$slot" "$rend" "$extra" "this project changed it, and so did the module"
      [ -z "$rec" ] || nr="$new"
    fi
    _kit_mod_up_row "$d/rows" "$kind" "$nr" "$tgt" "$slot"
  done < "$d/plan"
  # Recorded, and no longer placed by the new version: the row stays so disable still takes the file, and the
  # file is listed (on the upgrade that changes the module's version), never deleted.
  while read -r kind rec tgt slot; do
    [ -n "$kind" ] || continue
    if awk -F'\t' -v k="$kind" -v p="$tgt" -v s="$slot" '$1 == k && $2 == p && (k == "file" || $4 == s) { f = 1 } END { exit !f }' "$d/plan"; then continue; fi
    case "
$renamed" in *"
$tgt
"*) continue ;; esac
    _kit_mod_up_row "$d/rows" "$kind" "$rec" "$tgt" "$slot"
    [ "$KMU_OLD_VERSION" != "$KMU_VERSION" ] || continue
    if [ "$kind" = file ] && { [ -e "$KIT_MOD_ROOT/$tgt" ] || [ -L "$KIT_MOD_ROOT/$tgt" ]; }; then
      why="the new version does not place it; its record is kept, so disable still takes it: delete it, or keep it as this project's own"
      if [ "$tgt" = "process/roles.d/$name" ] && [ -n "$(_kit_mod_layer_in_use "$KIT_MOD_ROOT/$tgt")" ]; then
        why="the new version drops this role layer, and commits on this branch or the trunk carry the role $(_kit_mod_layer_in_use "$KIT_MOD_ROOT/$tgt"): it stays in force and disable keeps it too; to retire the role on purpose, move its line into process/ROLES, then delete this file"
      fi
      _kit_mod_up_act "$d/act" removed file "$tgt" - - - "$why"
    elif [ "$kind" = block ] && [ -f "$KIT_MOD_ROOT/$tgt" ] && kit_mb_has "$KIT_MOD_ROOT/$tgt" "$(_kit_mod_bid "$name" "$slot")"; then
      _kit_mod_up_act "$d/act" removed block "$tgt" "$slot" - - "the new version does not place it; its record is kept, so disable still takes it: delete it, or keep it as this project's own"
    fi
  done < "$d/old"
  return 0
}
# _kit_mod_up_meta <name> <old|new|notes> — a value the scan of that module left.
_kit_mod_up_meta() { sed -n "s/^$2=//p" "$KIT_MOD_TMP/up-$1/meta" | sed -n '1p'; }
# _kit_mod_rec_has <rows-text> <kind> <path> <slot> <sha> — status 0 when some row names that sha for the path.
_kit_mod_rec_has() {
  printf '%s\n' "$1" | awk -v k="$2" -v p="$3" -v s="${4:-}" -v h="$5" '$1 == k && $3 == p && (k == "file" || $4 == s) && $2 == h { f = 1 } END { exit !f }'
}
# _kit_mod_case_twin <rows-text> <path> — "<sha> <old path>" of a recorded file row whose path differs from <path> only in
# case and names the same file on disk (`-ef`), or nothing.
_kit_mod_case_twin() {
  local k sha p lc="$(_kit_mod_lc "$2")"
  while read -r k sha p _; do
    [ "$k" = file ] && [ "$p" != "$2" ] && [ "$(_kit_mod_lc "$p")" = "$lc" ] || continue
    if [ "$KIT_MOD_ROOT/$p" -ef "$KIT_MOD_ROOT/$2" ]; then printf '%s %s' "$sha" "$p"; return 0; fi
  done <<TWIN_EOF
$1
TWIN_EOF
  return 0
}
# _kit_mod_layer_in_use <role layer file> — the tags the layer declares that a commit on this branch or the trunk carries,
# comma-separated, or nothing.
_kit_mod_layer_in_use() {
  local t out=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if _kit_mod_history_uses_role "$t"; then out="${out:+$out, }$t"; fi
  done <<LAYER_EOF
$(_kit_mod_role_tags "$1")
LAYER_EOF
  printf '%s' "$out"
}
# _kit_mod_up_act <act file> <action> <kind> <target> <slot|-> <rendered copy|-> <x|-> <why> — one finding; the
# mode column is a file's executable flag, and a block has none.
_kit_mod_up_act() {
  local mode="$7"; [ "$3" = file ] || mode="-"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$2" "$3" "$4" "$5" "$6" "$mode" "$8" >> "$1"
}
# _kit_mod_up_row <rows-file> <kind> <sha> <target> <slot> — one row of the record, when there is a sha.
_kit_mod_up_row() {
  [ -n "$3" ] || return 0
  if [ "$2" = file ]; then printf 'file %s %s\n' "$3" "$4" >> "$1"; else printf 'block %s %s %s\n' "$3" "$4" "$5" >> "$1"; fi
}
# _kit_mod_up_role_loss <name> <target> <current file> <new copy> — status 0, and KMU_LOST naming the tags, when the
# target is the module's role layer, the new copy drops a role the layer has, and history already uses that role.
_kit_mod_up_role_loss() {
  local t gone=""
  KMU_LOST=""
  [ "$2" = "process/roles.d/$1" ] || return 1   # return-class: predicate
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if grep -qxF -- "$t" <<< "$(_kit_mod_role_tags "$4")"; then continue; fi
    if _kit_mod_history_uses_role "$t"; then gone="${gone:+$gone, }$t"; fi
  done <<UP_TAGS_EOF
$(_kit_mod_role_tags "$3")
UP_TAGS_EOF
  KMU_LOST="$gone"
  [ -n "$gone" ] || return 1   # return-class: predicate
}

# kit_mod_upgrade_own_work <path> — status 0 when the file at <path> differs from the committed one only in blocks that
# an enabled module's `pending` section names and whose bytes are the ones it names: the unfinished work of an upgrade
# that was killed, which running the upgrade again finishes, and not an edit of the project's. Anything outside such a
# block, or a block holding other bytes, is the project's; so is a file this cannot judge.
kit_mod_upgrade_own_work() {
  local path="$1" w="$KIT_MOD_TMP/own-w" h="$KIT_MOD_TMP/own-h" n kind sha p slot bid ids=""
  [ -f "$KIT_MOD_ROOT/$path" ] && [ ! -L "$KIT_MOD_ROOT/$path" ] || return 1   # return-class: predicate
  cp "$KIT_MOD_ROOT/$path" "$w" || return 1   # return-class: predicate
  if git -C "$KIT_MOD_ROOT" cat-file -e "HEAD:$path" 2>/dev/null; then git -C "$KIT_MOD_ROOT" show "HEAD:$path" > "$h" 2>/dev/null || return 1   # return-class: predicate
  else rm -f "$h"; fi
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    while read -r kind sha p slot; do
      [ "$kind" = block ] && [ "$p" = "$path" ] || continue
      bid="$(_kit_mod_bid "$n" "$slot")"
      [ -f "$w" ] && kit_mb_has "$w" "$bid" && [ "$(_kit_mod_block_sha "$w" "$bid")" = "$sha" ] || continue
      ( kit_mb_remove "$w" "$bid" ) >/dev/null 2>&1 || return 1   # return-class: predicate
      if [ -f "$h" ] && kit_mb_has "$h" "$bid"; then ( kit_mb_remove "$h" "$bid" ) >/dev/null 2>&1 || return 1; fi   # return-class: predicate
      ids="$ids $bid"
    done <<OWN_ROWS_EOF
$(kit_mod_pending_rows "$n")
OWN_ROWS_EOF
  done <<OWN_NAMES_EOF
$(kit_mod_enabled_names)
OWN_NAMES_EOF
  [ -n "$ids" ] || return 1   # return-class: predicate
  [ -f "$w" ] || : > "$w"; [ -f "$h" ] || : > "$h"
  cmp -s "$w" "$h" && return 0   # return-class: predicate
  # hashed as `git add` would store it, so anything git's own clean path counts as no change passes: core.autocrlf, text/eol attributes, a clean filter
  w="$(git -C "$KIT_MOD_ROOT" hash-object --path="$path" "$w" 2>/dev/null)" || return 1   # return-class: predicate
  [ -n "$w" ] && [ "$w" = "$(git -C "$KIT_MOD_ROOT" hash-object --no-filters "$h" 2>/dev/null)" ]
}

# kit_mod_upgrade_apply <name> — record the paths about to be written (the `pending` section), then write each file and
# block the scan listed as `write`. Status 1 when a write fails; the caller says what was written and how to finish.
kit_mod_upgrade_apply() {
  local name="$1" d="$KIT_MOD_TMP/up-$1" action kind tgt slot rend mode why tab
  tab="$(printf '\t')"
  _kit_mod_clean_strays "$KIT_MOD_STATE_REL"
  while IFS="$tab" read -r kind tgt rend slot; do _kit_mod_clean_strays "$tgt"; done < "$d/plan"
  if grep -q '^write' "$d/act"; then
    _kit_mod_state_ahead "$name" "$(_kit_mod_up_meta "$name" new)" "$d/ahead" || return 1   # return-class: relay
  fi
  while IFS="$tab" read -r action kind tgt slot rend mode why; do
    [ "$action" = write ] || continue
    if [ "$kind" = file ]; then
      _kit_mod_place_file "$rend" "$KIT_MOD_ROOT/$tgt" "$mode" || return 1   # return-class: internal
    else
      ( _kit_mod_put_block "$KIT_MOD_ROOT/$tgt" "$(_kit_mod_bid "$name" "$slot")" "$slot" "$rend" ) >/dev/null 2>&1 || return 1   # return-class: internal
    fi
  done < "$d/act"
  return 0
}
# kit_mod_upgrade_stage_record <name> <dir> — leave the module's final record (its version in the new kit and its rows) in
# <dir> as a work order, before the checklist is written.
kit_mod_upgrade_stage_record() {
  local d="$KIT_MOD_TMP/up-$1"
  mkdir -p "$2" && cp "$d/rows" "$2/$1.rows" && printf '%s %s\n' "$(_kit_mod_up_meta "$1" old)" "$(_kit_mod_up_meta "$1" new)" > "$2/$1.version" \
    || return 1   # return-class: internal
}
# kit_mod_upgrade_finish_record <name> <dir> — carry out the work order in <dir> for an enabled module and remove it:
# rewrite its record at the new version with the staged rows, which drops the `pending` section. A work order for a
# module that is no longer enabled is removed, not carried out. Status 1 when the record cannot be written.
kit_mod_upgrade_finish_record() {
  local name="$1" dir="$2" have="$KIT_MOD_TMP/finish-$1" ver
  [ -f "$dir/$name.rows" ] && [ -f "$dir/$name.version" ] || return 0
  _kit_mod_clean_strays "$KIT_MOD_STATE_REL"
  if kit_mod_is_enabled "$name"; then
    ver="$(cut -d' ' -f2 "$dir/$name.version")"
    _kit_mod_rows_of "$name" module | LC_ALL=C sort > "$have"
    LC_ALL=C sort "$dir/$name.rows" > "$have.new"
    if ! { [ "$(kit_mod_enabled_version "$name")" = "$ver" ] && cmp -s "$have.new" "$have" && ! kit_mod_is_pending "$name"; }; then
      _kit_mod_state_put "$name" "$ver" "$dir/$name.rows" module || return 1   # return-class: relay
    fi
  fi
  rm -f "$dir/$name.rows" "$dir/$name.version"
  return 0
}
# kit_mod_upgrade_readers <name> — the readers this project's copy of the kit lacks for the points the new
# version of the module uses, one line each (the lines enable's reader check prints), or nothing. Ask it once the
# upgrade has written its files: a reader the upgrade brings is then in place.
kit_mod_upgrade_readers() {
  _kit_mod_reader_blockers "$KIT_MOD_TMP/up-$1/plan.needs"
}
