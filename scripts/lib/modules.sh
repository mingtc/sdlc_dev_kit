#!/usr/bin/env bash
# KIT-CLASS: KIT — the modules library: read a module's manifest, plan what enabling places, record it in process/MODULES. See process/EXTRACTION.md.
#
# WHAT A MODULE IS: an optional overlay stored under modules/<name>/ in the kit, disarmed (a harness
# reads nothing there), with a module.manifest. Enabling copies the overlay into place and registers
# it with the extension points process/MODULES.md lists; disabling takes back exactly what enabling
# wrote. process/MODULES (the record) is the one statement of what is enabled and of the sha256 of every
# file and block enable placed, so disable can tell a file the module wrote from one the project then
# edited. The contract is process/contracts/module-lifecycle.md; the program is scripts/module.sh.
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
#   pending <name> <version>        an enable that was started and has not finished
#   kept    <name> <version>        what a disable left because the project had edited it
#   file  <sha256> <path>           rows belong to the nearest header line above them
#   block <sha256> <path> <slot>
# `#` lines are comments. A path holds no space. ENABLE WRITES THE RECORD AHEAD OF THE FILES, as
# `pending`, so an enable that is killed part-way leaves the proof of which paths are the module's:
# running enable again finishes it, and disable takes it back.
#
# PLACEHOLDERS a module's files may carry, replaced as they are placed once kit-init has stamped the
# project: <PREFIX> the issue prefix, <trunk> the trunk, <project name>. Before the stamp they stay.

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
  } > "$tmp" || kit_refuse 1 module-write-failed "Error: could not write $KIT_MOD_STATE_REL." "Next: check the permissions of process/ and the temp directory, then re-run."
  if ! awk '$1 == "module" || $1 == "kept" || $1 == "pending" { f = 1 } END { exit !f }' "$tmp"; then
    rm -f "$f"
  else
    mkdir -p "$(dirname "$f")" && cp "$tmp" "$f.kit-mod-new" && mv "$f.kit-mod-new" "$f" \
      || kit_refuse 1 module-write-failed "Error: could not write $KIT_MOD_STATE_REL." "Next: check the permissions of process/, then re-run."
  fi
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
# the rendered copies living under $KIT_MOD_TMP, and <needs-file> beside it (one line per extension point
# the module uses, for the reader check). Sets KIT_MOD_VERSION and KIT_MOD_PURPOSE. Refuses a manifest that is wrong.
kit_mod_plan() {
  local name="$1" plan="$2" dir man line key val src tgt slot extra n=0 gen mode seen tpl fmode folders
  _kit_mod_need_name "$name"
  dir="$(_kit_mod_src)/modules/$name"; man="$dir/module.manifest"
  [ -f "$man" ] || kit_refuse 1 module-unknown \
    "Error: this kit has no module '$name' (no modules/$name/module.manifest)." \
    "Next: ./scripts/module.sh list names the modules this kit ships."
  _kit_mod_stamp
  : > "$plan"
  KIT_MOD_VERSION=""; KIT_MOD_PURPOSE=""
  # The rendered copies live in a directory of this module's own, so two plans never share a name.
  local wd="$KIT_MOD_TMP/render-of-$name" mname="" roles_f kinds_f needs
  rm -rf "$wd"; mkdir -p "$wd" || _kit_mod_bad "$name" "could not make a scratch directory under $KIT_MOD_TMP."
  roles_f="$wd/gen-roles"; kinds_f="$wd/gen-kinds"; needs="$plan.needs"
  : > "$roles_f"; : > "$kinds_f"; : > "$needs"
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

# ── enable ────────────────────────────────────────────────────────────────────

# kit_mod_enable <name> — place the module, register it, record it. Idempotent: an enabled module is
# a no-op with a message; an interrupted enable is finished. Sets KIT_MOD_TOUCHED (the paths written, one
# per line, plus the record).
kit_mod_enable() {
  local name="$1" plan="$KIT_MOD_TMP/plan" rows="$KIT_MOD_TMP/rows" placed_f="$KIT_MOD_TMP/placed" conflicts blockers kind tgt rend extra dst placed=0 blocks=0 bid out resuming=0 sha has next_text unfilled=""
  KIT_MOD_TOUCHED=""
  kit_mod_plan "$name" "$plan"
  if kit_mod_is_enabled "$name"; then
    echo "module: $name is already enabled (version $(kit_mod_enabled_version "$name")); nothing to do."
    if [ "$(kit_mod_enabled_version "$name")" != "$KIT_MOD_VERSION" ]; then
      echo "  This kit holds version $KIT_MOD_VERSION of it: placed files change through the kit upgrade, not through enable."
    fi
    return 0
  fi
  kit_mod_have_sha || kit_refuse 1 module-no-sha-tool \
    "Error: no sha256 tool (shasum or sha256sum) is on this machine, and enable records one per file so that disable can tell an edited file from the module's." \
    "Next: install one (shasum ships with perl and macOS; sha256sum with coreutils), then re-run."
  if kit_mod_is_pending "$name"; then resuming=1; echo "module: an earlier enable of $name did not finish; finishing it."; fi
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
      next_text="for a path left by an earlier disable, restore the module's copy over it (./scripts/module.sh status $name shows what it kept) or delete it; for any other path named above, move or merge it yourself (it is not the module's); then run ./scripts/module.sh enable $name again."
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
        # Written beside the target and moved in, so a kill never leaves a half-written file at the path.
        if ! { mkdir -p "$(dirname "$dst")" && cp "$rend" "$dst.kit-mod-new" && { [ "$extra" != x ] || chmod +x "$dst.kit-mod-new"; } && mv "$dst.kit-mod-new" "$dst"; }; then
          _kit_mod_clean_strays "$tgt"
          _kit_mod_unplace "$placed_f"
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
  return 0
}

# ── disable ───────────────────────────────────────────────────────────────────

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
    [ "$(_kit_mod_block_sha "$dst" "$bid")" = "$sha" ] || continue
    if [ -s "$dst" ] && [ -n "$(tail -c1 "$dst" | tr -d '\n')" ]; then echo "  $tgt does not end with a newline"; fi
  done < "$1"
  return 0
}

# kit_mod_disable <name> — take back what enable wrote, from an enabled module or an interrupted enable.
# Sets KIT_MOD_TOUCHED (paths removed or changed), KIT_MOD_KEPT (paths kept because the project edited them or
# because history uses the role) and KIT_MOD_ROLES_KEPT (the tags). What is kept stays recorded, under a
# `kept` line, so status can say whose it was. Idempotent.
kit_mod_disable() {
  local name="$1" rows="$KIT_MOD_TMP/rows" keptf="$KIT_MOD_TMP/kept-rows" ver kind sha tgt slot dst bid removed=0 gone=0 was=module blockers tag t
  KIT_MOD_TOUCHED=""; KIT_MOD_KEPT=""; KIT_MOD_ROLES_KEPT=""
  _kit_mod_need_name "$name"
  if ! kit_mod_is_enabled "$name" && ! kit_mod_is_pending "$name"; then
    echo "module: $name is not enabled; nothing to do."
    return 0
  fi
  kit_mod_have_sha || kit_refuse 1 module-no-sha-tool \
    "Error: no sha256 tool (shasum or sha256sum) is on this machine, so disable cannot tell the module's files from your edits, and it will not guess." \
    "Next: install one, then re-run ./scripts/module.sh disable $name."
  if kit_mod_is_pending "$name"; then was=pending; ver="$(awk -v n="$name" '$1 == "pending" && $2 == n { print $3; exit }' "$(_kit_mod_state)")"
  else ver="$(kit_mod_enabled_version "$name")"; fi
  kit_mod_rows "$name" > "$rows"; : > "$keptf"
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
      if [ ! -e "$dst" ]; then gone=$((gone + 1)); continue; fi
      if [ "$(_kit_mod_sha "$dst")" = "$sha" ]; then
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
        rm -f "${dst:?}" && _kit_mod_prune "$tgt"
        removed=$((removed + 1)); KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${tgt}
"
      else
        KIT_MOD_KEPT="${KIT_MOD_KEPT}${tgt}
"
        printf 'file %s %s\n' "$sha" "$tgt" >> "$keptf"
      fi
    else
      bid="$(_kit_mod_bid "$name" "$slot")"
      if [ ! -f "$dst" ] || ! kit_mb_has "$dst" "$bid"; then gone=$((gone + 1)); continue; fi
      if [ "$(_kit_mod_block_sha "$dst" "$bid")" = "$sha" ]; then
        kit_mb_remove "$dst" "$bid"
        removed=$((removed + 1)); KIT_MOD_TOUCHED="${KIT_MOD_TOUCHED}${tgt}
"
      else
        KIT_MOD_KEPT="${KIT_MOD_KEPT}${tgt} (block $name, slot $slot)
"
        printf 'block %s %s %s\n' "$sha" "$tgt" "$slot" >> "$keptf"
      fi
    fi
  done < "$rows"
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

# _kit_mod_file_state <path> <sha> — intact | edited | missing, by the recorded sha.
_kit_mod_file_state() {
  if [ ! -e "$KIT_MOD_ROOT/$1" ]; then echo missing
  elif [ "$(_kit_mod_sha "$KIT_MOD_ROOT/$1")" = "$2" ]; then echo intact
  else echo edited; fi
}
_kit_mod_block_state() {  # <path> <block id> <sha>
  if [ ! -f "$KIT_MOD_ROOT/$1" ] || ! kit_mb_has "$KIT_MOD_ROOT/$1" "$2"; then echo missing
  elif [ "$(_kit_mod_block_sha "$KIT_MOD_ROOT/$1" "$2")" = "$3" ]; then echo intact
  else echo edited; fi
}

# _kit_mod_status_rows <name> <rows-file> — one line per recorded row, with its state.
_kit_mod_status_rows() {
  local name="$1" kind sha tgt slot st
  while read -r kind sha tgt slot; do
    [ -n "$kind" ] || continue
    if [ "$kind" = file ]; then st="$(_kit_mod_file_state "$tgt" "$sha")"; else st="$(_kit_mod_block_state "$tgt" "$(_kit_mod_bid "$name" "$slot")" "$sha")"; fi
    printf '  %-8s %s%s\n' "$st" "$tgt" "$([ "$kind" = block ] && echo " (block, slot $slot)")"
  done < "$2"
}

# kit_mod_status <name> — one module's record and the state of each thing it placed.
kit_mod_status() {
  local name="$1" kv
  _kit_mod_need_name "$name"
  if kit_mod_is_pending "$name"; then
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
  kit_mod_rows "$name" > "$KIT_MOD_TMP/status-rows"
  _kit_mod_status_rows "$name" "$KIT_MOD_TMP/status-rows"
  return 0
}
