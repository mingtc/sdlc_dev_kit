#!/usr/bin/env bash
# KIT-CLASS: KIT — insert, replace and remove one named block in a shared file, idempotently.
# See process/EXTRACTION.md.
#
# WHY THIS EXISTS: an add-on's rows in a table every project shares (PROJECT.md's gate table, the
# corpus manifest) cannot be a file of their own, so they are a BLOCK between two marker lines. This
# library is the one thing that touches a block: insert it, replace it, remove it, and in every case
# leave every other byte of the file alone.
#
#   <!-- KIT-MODULE:<id> BEGIN -->
#   <the block's lines, verbatim from the content file>
#   <!-- KIT-MODULE:<id> END -->
#
# WHERE A BLOCK GOES: before the file's SLOT line, a comment that starts `<!-- KIT-MODULES:<slot>`
# (the rest of the line is free text). The block is followed by ONE blank line and removal takes that
# blank line with it, so insert-then-remove gives back the original bytes and a re-insert of the same
# content changes nothing. A BLOCK IS ITS OWN TABLE (header row, separator, rows), never rows spliced
# into a table above it: a comment line inside a table ends the table in a renderer.
#
#   kit_mb_has <file> <id>                           status 0 if the block is present
#   kit_mb_insert <file> <id> <slot> <content-file>  add the block before the slot; replace its
#                                                    content if it is already there
#   kit_mb_remove <file> <id>                        remove the block; a no-op when absent
#
# THE `gitignore` SLOT has no slot line: an id that ends in `:gitignore` goes at the END of the file
# (created when absent), written in `#` comments, which a .gitignore reads as comments (`<!--` there
# would be a pattern). A file the insert created holds the block alone, with no blank line after it;
# removing that block deletes the file, and removing a block from a file that existed (even an empty
# one) leaves it:
#
#   # KIT-MODULE:<id> BEGIN
#   # KIT-MODULE:<id> END
#
# After insert or remove, KIT_MB_CHANGED is `1` when the file's bytes changed and `0` when it was
# already as asked. An id is a name (lowercase letters, digits and `-`, opening with a letter), or
# `<name>:<slot>` when one name holds a block in each of several slots of a file. A refusal goes
# through kit_refuse (lib/refuse.sh), writes nothing, and EXITS: called inside $( … ) it exits only
# that subshell. The file must end with a newline. A CRLF file is read with the `\r` ignored when a
# marker or a slot is matched, and the lines written take the ending of the line they sit beside. A
# slot name ends at the end of its line, at a space or at `-->`, so `gates` never matches
# `gates-extra`. The content file may hold no `KIT-MODULE` marker or slot line. Bash 3.2 and a POSIX
# awk; no GNU extension.

# shellcheck source=refuse.sh
. "$(dirname "${BASH_SOURCE[0]}")/refuse.sh" || return 1   # return-class: internal

KIT_MB_CHANGED=0

# _kit_mb_hash <id> — status 0 for the id of a gitignore block (see above).
_kit_mb_hash() { case "$1" in *:gitignore) return 0 ;; esac; return 1; }   # return-class: predicate

kit_mb_begin_line() { if _kit_mb_hash "$1"; then printf '# KIT-MODULE:%s BEGIN' "$1"; else printf '<!-- KIT-MODULE:%s BEGIN -->' "$1"; fi; }
kit_mb_end_line()   { if _kit_mb_hash "$1"; then printf '# KIT-MODULE:%s END' "$1"; else printf '<!-- KIT-MODULE:%s END -->' "$1"; fi; }

# _kit_mb_valid <name-or-slot> — status 0 if it is a legal name/slot.
_kit_mb_valid() {
  case "$1" in
    ''|[!a-z]*|*[!a-z0-9-]*) return 1 ;;   # return-class: predicate
  esac
  return 0
}

# _kit_mb_valid_id <id> — a block's id is a name, or `<name>:<slot>` when one name places a
# block in each of several slots of one file (the markers carry the id, so two blocks never share one).
_kit_mb_valid_id() {
  case "$1" in
    *:*) _kit_mb_valid "${1%%:*}" && _kit_mb_valid "${1#*:}" ;;
    *)   _kit_mb_valid "$1" ;;
  esac
}

# _kit_mb_state <file> <name> — print `none`, `one` (exactly one well-ordered BEGIN…END pair) or
# `bad` (anything else: a lone marker, a duplicate, an END before its BEGIN).
_kit_mb_state() {
  KMB_B="$(kit_mb_begin_line "$2")" KMB_E="$(kit_mb_end_line "$2")" awk '
    BEGIN { b = ENVIRON["KMB_B"]; e = ENVIRON["KMB_E"] }
    { l = $0; sub(/\r$/, "", l) }
    l == b { nb++ }
    l == e { ne++; if (!nb) oe = 1 }
    END {
      if (nb == 0 && ne == 0) print "none"
      else if (nb == 1 && ne == 1 && !oe) print "one"
      else print "bad"
    }' "$1"
}

# _kit_mb_commit <file> <new-copy> — replace <file> with <new-copy> only when it differs, keeping the
# file's mode: the bytes go to a copy of the file made beside it (cp -p), and that copy is moved over
# it, so a write that fails (a full disk) has not touched <file>. A refused write removes <new-copy>
# too. Sets KIT_MB_CHANGED.
_kit_mb_commit() {
  local side
  if cmp -s "$1" "$2"; then
    KIT_MB_CHANGED=0
  else
    side="$(mktemp "$1.kit-mb.XXXXXX")" && cp -p "$1" "$side" && cat "$2" > "$side" && mv "$side" "$1" \
      || { rm -f "${side:-}" "$2"; kit_refuse 1 marker-block-unwritable "Error: marker-block: could not write $1." "Next: check the file's permissions and the free space beside it, then re-run; the file was not changed." "      NOTHING WAS CHANGED."; }
    KIT_MB_CHANGED=1
  fi
  return 0
}

# _kit_mb_need_id <name> — refuse an id that cannot be one.
_kit_mb_need_id() {
  _kit_mb_valid_id "$1" \
    || kit_refuse 1 marker-block-bad-name "Error: marker-block: '$1' is not a block id (lowercase letters, digits and '-', opening with a letter; optionally followed by ':<slot>')." "Next: use the add-on's own lowercase name." "      NOTHING WAS CHANGED."
}

# _kit_mb_precheck <file> <name> — the refusals every operation shares; each exits through kit_refuse.
_kit_mb_precheck() {
  _kit_mb_need_id "$2"
  if [ ! -f "$1" ] || [ ! -r "$1" ]; then
    kit_refuse 1 marker-block-file-unreadable "Error: marker-block: $1 is not a readable file." "Next: restore it from version control or the release, then re-run." "      NOTHING WAS CHANGED."
  fi
  if [ -s "$1" ] && [ -n "$(tail -c1 "$1" | tr -d '\n')" ]; then
    kit_refuse 1 marker-block-no-final-newline "Error: marker-block: $1 does not end with a newline, and the library would add one to its last line." "Next: end the file with a newline, then re-run." "      NOTHING WAS CHANGED."
  fi
  return 0
}

kit_mb_has() {
  [ -f "$1" ] && [ "$(_kit_mb_state "$1" "$2")" = one ]
}

kit_mb_insert() {
  local file="$1" name="$2" slot="$3" content="$4" state tmp rc=0 created=0 marker='<!-- KIT-MODULE'
  KIT_MB_CHANGED=0
  if _kit_mb_hash "$name"; then
    # the gitignore slot: no slot line, the file may be absent (created below, after every refusal that can still come)
    marker='KIT-MODULE'; slot="gitignore"
    _kit_mb_need_id "$name"
    if [ -e "$file" ]; then _kit_mb_precheck "$file" "$name"; else created=1; fi
  else
    _kit_mb_precheck "$file" "$name"
  fi
  _kit_mb_valid "$slot" \
    || kit_refuse 1 marker-block-bad-slot "Error: marker-block: '$slot' is not a slot name (lowercase letters, digits and '-')." "Next: use the slot the file declares, on its '<!-- KIT-MODULES:<slot>' line." "      NOTHING WAS CHANGED."
  if [ ! -f "$content" ] || [ ! -r "$content" ]; then
    kit_refuse 1 marker-block-content-unreadable "Error: marker-block: the content file $content is not readable." "Next: restore the add-on's files, then re-run." "      NOTHING WAS CHANGED."
  fi
  if grep -qF "$marker" "$content"; then
    kit_refuse 1 marker-block-content-markers "Error: marker-block: the content file $content carries a '$marker' marker or slot line of its own, which would leave $file with a marker it cannot pair." "Next: remove that line from the content (the library writes the markers), then re-run." "      NOTHING WAS CHANGED."
  fi
  if [ "$created" = 1 ]; then : > "$file" || kit_refuse 1 marker-block-unwritable "Error: marker-block: could not create $file." "Next: check the directory's permissions, then re-run." "      NOTHING WAS CHANGED."; fi
  state="$(_kit_mb_state "$file" "$name")"
  if [ "$state" = bad ]; then
    kit_refuse 1 marker-block-markers-malformed "Error: marker-block: $file has a lone, repeated or misordered marker for block '$name'." "Next: open $file, leave exactly one '$(kit_mb_begin_line "$name")' line above one '$(kit_mb_end_line "$name")' line (or delete both), then re-run." "      NOTHING WAS CHANGED."
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/kit-mb.XXXXXX")" || { [ "$created" = 1 ] && rm -f "$file"; kit_refuse 1 marker-block-no-scratch "Error: marker-block: could not create a scratch file." "Next: check the temp directory, then re-run."; }
  if [ "$state" = one ]; then
    KMB_B="$(kit_mb_begin_line "$name")" KMB_E="$(kit_mb_end_line "$name")" KMB_C="$content" awk '
      function emit(  l) { print b cr; while ((getline l < cf) > 0) { sub(/\r$/, "", l); print l cr } close(cf); print e cr }
      BEGIN { b = ENVIRON["KMB_B"]; e = ENVIRON["KMB_E"]; cf = ENVIRON["KMB_C"] }
      { l = $0; sub(/\r$/, "", l) }
      !skip && l == b { cr = ($0 ~ /\r$/) ? "\r" : ""; emit(); skip = 1; next }
      skip { if (l == e) skip = 0; next }
      { print }' "$file" > "$tmp" || rc=1
  elif _kit_mb_hash "$name"; then
    KMB_NB="$([ "$created" = 1 ] && echo 1)" KMB_B="$(kit_mb_begin_line "$name")" KMB_E="$(kit_mb_end_line "$name")" KMB_C="$content" awk '
      function emit(  l) { print b cr; while ((getline l < cf) > 0) { sub(/\r$/, "", l); print l cr } close(cf); print e cr; if (!nb) print cr }
      BEGIN { b = ENVIRON["KMB_B"]; e = ENVIRON["KMB_E"]; cf = ENVIRON["KMB_C"]; nb = ENVIRON["KMB_NB"] }
      { print; cr = ($0 ~ /\r$/) ? "\r" : "" }
      END { emit() }' "$file" > "$tmp" || rc=1
  else
    KMB_B="$(kit_mb_begin_line "$name")" KMB_E="$(kit_mb_end_line "$name")" KMB_C="$content" \
      KMB_S="<!-- KIT-MODULES:$slot" awk '
      function emit(  l) { print b cr; while ((getline l < cf) > 0) { sub(/\r$/, "", l); print l cr } close(cf); print e cr; print cr }
      BEGIN { b = ENVIRON["KMB_B"]; e = ENVIRON["KMB_E"]; cf = ENVIRON["KMB_C"]; sp = ENVIRON["KMB_S"] }
      !done && index($0, sp) == 1 {
        rest = substr($0, length(sp) + 1); sub(/\r$/, "", rest)
        if (rest == "" || substr(rest, 1, 1) == " " || substr(rest, 1, 3) == "-->") { cr = ($0 ~ /\r$/) ? "\r" : ""; emit(); done = 1 }
      }
      { print }
      END { exit done ? 0 : 3 }' "$file" > "$tmp" || rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    rm -f "$tmp"
    [ "$created" = 1 ] && rm -f "$file"
    if [ "$rc" -eq 3 ]; then
      kit_refuse 1 marker-block-no-slot "Error: marker-block: $file has no '<!-- KIT-MODULES:$slot' slot line to put module '$name' before." "Next: this file's shipped shape declares the slot; restore that line from the release, or check the slot name, then re-run." "      NOTHING WAS CHANGED."
    fi
    kit_refuse 1 marker-block-rewrite-failed "Error: marker-block: the rewrite of $file failed." "Next: check the file and the temp directory, then re-run." "      NOTHING WAS CHANGED."
  fi
  _kit_mb_commit "$file" "$tmp"
  rm -f "$tmp"
  return 0
}

kit_mb_remove() {
  local file="$1" name="$2" state tmp rc=0 alone=0
  KIT_MB_CHANGED=0
  _kit_mb_precheck "$file" "$name"
  state="$(_kit_mb_state "$file" "$name")"
  [ "$state" = none ] && return 0
  if _kit_mb_hash "$name"; then
    [ "$(KMB_B="$(kit_mb_begin_line "$name")" KMB_E="$(kit_mb_end_line "$name")" awk '
      { l = $0; sub(/\r$/, "", l) }
      NR == 1 { first = l }
      { last = l }
      END { print (first == ENVIRON["KMB_B"] && last == ENVIRON["KMB_E"]) ? 1 : 0 }' "$file")" = 1 ] && alone=1
  fi
  if [ "$state" = bad ]; then
    kit_refuse 1 marker-block-markers-malformed "Error: marker-block: $file has a lone, repeated or misordered marker for block '$name'." "Next: open $file, leave exactly one '$(kit_mb_begin_line "$name")' line above one '$(kit_mb_end_line "$name")' line (or delete both), then re-run." "      NOTHING WAS CHANGED."
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/kit-mb.XXXXXX")" || kit_refuse 1 marker-block-no-scratch "Error: marker-block: could not create a scratch file." "Next: check the temp directory, then re-run."
  KMB_B="$(kit_mb_begin_line "$name")" KMB_E="$(kit_mb_end_line "$name")" awk '
    BEGIN { b = ENVIRON["KMB_B"]; e = ENVIRON["KMB_E"] }
    { l = $0; sub(/\r$/, "", l) }
    !skip && l == b { skip = 1; next }
    skip { if (l == e) { skip = 0; eatblank = 1 } next }
    eatblank { eatblank = 0; if (l == "") next }
    { print }' "$file" > "$tmp" || rc=1
  if [ "$rc" -ne 0 ]; then
    rm -f "$tmp"
    kit_refuse 1 marker-block-rewrite-failed "Error: marker-block: the rewrite of $file failed." "Next: check the file and the temp directory, then re-run." "      NOTHING WAS CHANGED."
  fi
  _kit_mb_commit "$file" "$tmp"
  rm -f "$tmp"
  if [ "$alone" = 1 ] && [ ! -s "$file" ]; then rm -f "$file"; fi
  return 0
}
