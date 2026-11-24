#!/usr/bin/env bash
# KIT-CLASS: KIT — list, verify, unpack and remove the packs a project holds. See process/EXTRACTION.md.
# Contract: process/contracts/pack.md.
#
# A pack is a file of the kit's own files, shipped packed instead of loose (process/MODULES.md § Packs).
# Nothing reads inside one until it is unpacked. Unpacking writes its members at the paths they have in
# the kit; removing takes them back out. Neither commits: unpacked files are the project's, to review and
# commit like any other.
#
# Usage:
#   ./scripts/pack.sh list
#   ./scripts/pack.sh verify [<name>]
#   ./scripts/pack.sh unpack <name>
#   ./scripts/pack.sh unpack --all
#   ./scripts/pack.sh remove <name>
#
# list      each pack: its name, how many members, and whether it is packed, unpacked or partly unpacked.
# verify    each pack, or one, is whole and every member is allowed (symlinks, `.git`, paths outside the
#           format's alphabet are refused). Reads nothing into the project.
# unpack    write the members the project lacks, each whole or not at all, and record the paths it wrote in
#           <pack>.wrote beside the pack. A member already on disk is left exactly as it is and counted,
#           never overwritten. Everything is checked, for every pack named, before the first byte is
#           written; a symlink or a directory where a member must go refuses and writes nothing.
# remove    delete each member this project unpacked (it is in the record) that is still byte-equal to the
#           pack's copy, then the directories that emptied, then the record. A member the project edited,
#           replaced by a link, placed under a link, or already had before the unpack is kept. Run on a
#           pack with no record, it does nothing and says so.
# -h, --help  this text.
#
# Exit 0: done (for verify, every pack named is whole). Exit 1: a refusal; the message names the file
# and the next step. Exit 2: a usage error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"
# shellcheck source=lib/exit-trap.sh
. "$SCRIPT_DIR/lib/exit-trap.sh"
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# A usage request always succeeds, in any position, before any argument is interpreted.
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

CMD=""; ARG=""; NARG=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all) ARG="--all"; NARG=$(( NARG + 1 )); shift ;;
    -*) kit_refuse 2 unknown-option "Error: unknown option: $1" "Next: run $(basename "$0") --help, then re-run with one of the commands it lists." ;;
    *)  if [ -z "$CMD" ]; then CMD="$1"
        else ARG="$1"; NARG=$(( NARG + 1 )); fi
        shift ;;
  esac
done
[ -n "$CMD" ] || kit_refuse 2 pack-no-command "Error: no command given." "Next: run $(basename "$0") --help; it lists the commands."
case "$CMD" in
  list|verify|unpack|remove) ;;
  *) kit_refuse 2 unknown-command "Error: unknown command: $CMD" "Next: run $(basename "$0") --help; it lists the commands." ;;
esac
[ "$NARG" -le 1 ] || kit_refuse 1 unexpected-argument "Error: $CMD takes at most one argument." "Next: re-run as: $(basename "$0") list | verify [<name>] | unpack <name>|--all | remove <name>."
case "$CMD" in
  unpack|remove) [ -n "$ARG" ] || kit_refuse 2 pack-no-name "Error: $CMD needs a pack name." "Next: $(basename "$0") list names the packs this project holds, then re-run: $(basename "$0") $CMD <name>." ;;
  list) [ -z "$ARG" ] || kit_refuse 1 unexpected-argument "Error: unexpected argument: $ARG" "Next: list takes none; re-run: $(basename "$0") list." ;;
esac
[ "$CMD" != remove ] || [ "$ARG" != "--all" ] || kit_refuse 1 pack-remove-all "Error: remove takes one pack's name, not --all." "Next: name the pack: $(basename "$0") remove <name>; $(basename "$0") list names them."

READER="$SCRIPT_DIR/lib/kitpack.sh"
[ -f "$READER" ] || kit_refuse 1 pack-no-reader "Error: scripts/lib/kitpack.sh is missing." "Next: restore it from the kit you took this project from: git checkout -- scripts/lib/kitpack.sh."
# The directory and the extension are the reader's to name, once.
read -r PACK_DIR PACK_EXT <<< "$( . "$READER" >/dev/null 2>&1; printf '%s %s' "$KIT_PACK_DIR" "$KIT_PACK_EXT" )"
[ -n "$PACK_DIR" ] && [ -n "$PACK_EXT" ] || kit_refuse 1 pack-no-reader "Error: scripts/lib/kitpack.sh does not name the pack directory." "Next: restore it from the kit you took this project from: git checkout -- scripts/lib/kitpack.sh."

PK_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kit-pack.XXXXXX")" || kit_refuse 1 pack-no-scratch \
  "Error: could not make a scratch directory." "Next: check the temp directory (TMPDIR), then re-run."
kit_on_exit 'rm -rf "$PK_TMP"'

NEXT_DAMAGED="Next: restore the pack from the kit's zip, or with git checkout -- <the pack file named above>; a pack is never edited by hand."
NEXT_WAY="Next: move or delete what the line above names (a symlink, or a directory where a file belongs), then re-run the same command."

# pack_file <name> — the pack's path, refusing a name that is not one this project holds.
pack_file() {
  case "$1" in
    ''|-*|*[!abcdefghijklmnopqrstuvwxyz0-9-]*) kit_refuse 1 pack-name-invalid "Error: '$1' is not a pack name (lowercase letters, digits and '-')." "Next: $(basename "$0") list names the packs this project holds." ;;
  esac
  PK_FILE="$ROOT/$PACK_DIR/$1.$PACK_EXT"
  [ -f "$PK_FILE" ] || kit_refuse 1 pack-not-found "Error: no pack named '$1' ($PACK_DIR/$1.$PACK_EXT is not here)." "Next: $(basename "$0") list names the packs this project holds."
}

# pack_names — every pack's name, one a line, in order.
pack_names() {
  local f
  for f in "$ROOT/$PACK_DIR"/*."$PACK_EXT"; do
    [ -f "$f" ] || continue
    f="${f##*/}"; f="${f%."$PACK_EXT"}"
    case "$f" in ''|-*|*[!abcdefghijklmnopqrstuvwxyz0-9-]*) continue ;; esac
    printf '%s\n' "$f"
  done
}

# reader <verb args…> — run the reader; its stdout lands in $PK_OUT, its stderr in $PK_ERR; its status is returned.
reader() {
  PK_OUT="$(sh "$READER" "$@" 2>"$PK_TMP/err" </dev/null)"; local rc=$?
  PK_ERR="$(cat "$PK_TMP/err")"
  return "$rc"   # return-class: relay
}

# reader_refusal <name> <status> — turn a reader failure into the refusal that names the next step.
REFUSAL_TAIL="nothing was written for it."
reader_refusal() {
  case "$2" in
    1) case "$PK_ERR" in
         *"symlink or a file is in the way"*|*"already exists"*|*"is a symlink"*|*"is not a directory"*|*"exists and is not"*)
           kit_refuse 1 pack-path-in-the-way "Error: $1 was not unpacked; $REFUSAL_TAIL" "$PK_ERR" "$NEXT_WAY" ;;
         *) kit_refuse 1 pack-damaged "Error: $1 is not usable." "$PK_ERR" "$NEXT_DAMAGED" ;;
       esac ;;
    *) kit_refuse 1 pack-tool-failed "Error: a tool the reader needs failed while reading $1." "$PK_ERR" "Next: check that git works and TMPDIR is writable, then re-run the same command." ;;
  esac
}

# member_paths <name> — the pack's member paths into $PK_TMP/members, or the refusal.
member_paths() {
  local rc=0
  pack_file "$1"
  reader ls "$PK_FILE" || rc=$?
  [ "$rc" -eq 0 ] || reader_refusal "$1" "$rc"
  printf '%s\n' "$PK_OUT" | sed 's/^[0-9]* //' > "$PK_TMP/members"
}

# on_the_way_clean <path> — a symlink or a non-directory among the directories above <path> inside the project.
on_the_way_clean() {
  local rel="$1" cur="$ROOT"
  while :; do
    case "$rel" in */*) ;; *) break ;; esac
    cur="$cur/${rel%%/*}"; rel="${rel#*/}"
    [ ! -L "$cur" ] || return 1   # return-class: predicate
    [ ! -e "$cur" ] || [ -d "$cur" ] || return 1   # return-class: predicate
  done
  return 0
}

case "$CMD" in
  list)
    names="$(pack_names)"
    if [ -z "$names" ]; then echo "packs: none ($PACK_DIR/ holds no $PACK_EXT file)."
    else
      echo "packs this project holds ($PACK_DIR/):"
      bad=""
      while read -r n; do
        rc=0; pack_file "$n"
        reader ls "$PK_FILE" || rc=$?
        if [ "$rc" -ne 0 ]; then printf '  %-16s NOT USABLE: %s\n' "$n" "$(printf '%s' "$PK_ERR" | head -1)"; bad="$bad $n"; continue; fi
        total=0; here=0
        while read -r _m p; do
          [ -n "${p:-}" ] || continue
          total=$(( total + 1 ))
          if [ -e "$ROOT/$p" ] || [ -L "$ROOT/$p" ]; then here=$(( here + 1 )); fi
        done <<< "$PK_OUT"
        if [ "$here" -eq 0 ]; then st="packed"; elif [ "$here" -eq "$total" ]; then st="unpacked"; else st="partly unpacked ($here of $total present)"; fi
        printf '  %-16s %s members  %s\n' "$n" "$total" "$st"
      done <<< "$names"
      [ -z "$bad" ] || kit_refuse 1 pack-damaged "Error: not usable:$bad" "$NEXT_DAMAGED"
      echo "Unpack one with: $(basename "$0") unpack <name>   (or --all). Take one back out with: $(basename "$0") remove <name>."
    fi ;;
  verify)
    if [ -n "$ARG" ]; then names="$ARG"; pack_file "$ARG"; else names="$(pack_names)"; fi
    if [ -z "$names" ]; then echo "packs: none ($PACK_DIR/ holds no $PACK_EXT file)."
    else
      bad=""
      while read -r n; do
        rc=0; pack_file "$n"
        reader verify "$PK_FILE" || rc=$?
        if [ "$rc" -eq 0 ]; then printf '%s: %s\n' "$n" "$PK_OUT"
        else printf '%s: NOT WHOLE: %s\n' "$n" "$(printf '%s' "$PK_ERR" | head -1)"; bad="$bad $n"; fi
      done <<< "$names"
      [ -z "$bad" ] || kit_refuse 1 pack-damaged "Error: not whole:$bad" "$NEXT_DAMAGED"
    fi ;;
  unpack)
    if [ "$ARG" = "--all" ]; then names="$(pack_names)"; else pack_file "$ARG"; names="$ARG"; fi
    if [ -z "$names" ]; then echo "packs: none ($PACK_DIR/ holds no $PACK_EXT file), so nothing to unpack."
    else
      REFUSAL_TAIL="nothing was written, for it or any other pack."
      while read -r n; do
        rc=0; pack_file "$n"
        reader unpack --missing --check "$PK_FILE" "$ROOT" || rc=$?
        [ "$rc" -eq 0 ] || reader_refusal "$n" "$rc"
      done <<< "$names"
      wrote_packs=""
      while read -r n; do
        rc=0; pack_file "$n"
        REFUSAL_TAIL="nothing was written for it.${wrote_packs:+ Already written before it:$wrote_packs.}"
        reader unpack --missing "$PK_FILE" "$ROOT" || rc=$?
        [ "$rc" -eq 0 ] || reader_refusal "$n" "$rc"
        w=0; k=0; : > "$PK_TMP/wrote"
        while read -r verb p; do
          case "$verb" in wrote) w=$(( w + 1 )); printf '%s\n' "$p" >> "$PK_TMP/wrote" ;; kept) k=$(( k + 1 )) ;; esac
        done <<< "$PK_OUT"
        wrote_packs="$wrote_packs $n"
        if [ "$w" -gt 0 ]; then
          rec="$ROOT/$PACK_DIR/$n.wrote"
          { [ ! -f "$rec" ] || cat "$rec"; cat "$PK_TMP/wrote"; } | LC_ALL=C sort -u > "$PK_TMP/record" \
            && cp "$PK_TMP/record" "$rec.part" && mv "$rec.part" "$rec" \
            || kit_refuse 1 pack-record-failed "Error: $n was unpacked but its record of what was written could not be saved ($PACK_DIR/$n.wrote)." "Next: check that $PACK_DIR/ is writable, then take the files back out by hand; $(basename "$0") remove $n cannot, without the record."
        fi
        if [ "$k" -eq 0 ]; then printf '%s: wrote %s member(s).\n' "$n" "$w"
        else printf '%s: wrote %s member(s); %s already on disk, left as they are.\n' "$n" "$w" "$k"; fi
      done <<< "$names"
      echo "Nothing is committed. Next: review what was written, then commit it like any file."
    fi ;;
  remove)
    member_paths "$ARG"
    rec="$ROOT/$PACK_DIR/$ARG.wrote"
    if [ ! -f "$rec" ]; then echo "$ARG: no record of files this project unpacked from it, so nothing to remove."; exit 0; fi
    mkdir "$PK_TMP/copy" || kit_refuse 1 pack-no-scratch "Error: could not make a scratch directory." "Next: check the temp directory (TMPDIR), then re-run."
    rc=0; reader unpack "$PK_FILE" "$PK_TMP/copy" || rc=$?
    [ "$rc" -eq 0 ] || reader_refusal "$ARG" "$rc"
    removed=0; absent=0; kept=""; nkept=0
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if ! grep -qxF -- "$p" "$PK_TMP/members"; then kept="$kept
  $p (the record names it and the pack does not hold it)"; nkept=$(( nkept + 1 )); continue; fi
      if ! on_the_way_clean "$p"; then kept="$kept
  $p (a symlink or a file is on the way to it)"; nkept=$(( nkept + 1 )); continue; fi
      if [ -L "$ROOT/$p" ]; then kept="$kept
  $p (a symlink)"; nkept=$(( nkept + 1 )); continue; fi
      if [ ! -e "$ROOT/$p" ]; then absent=$(( absent + 1 )); continue; fi
      if [ -f "$ROOT/$p" ] && cmp -s "$ROOT/$p" "$PK_TMP/copy/$p"; then
        rm -f "$ROOT/$p" || kit_refuse 1 pack-remove-failed "Error: could not remove $p." "Next: check that the file and its directory are writable, then re-run: $(basename "$0") remove $ARG."
        removed=$(( removed + 1 ))
        d="${p%/*}"
        while [ "$d" != "$p" ] && [ -n "$d" ] && rmdir "$ROOT/$d" 2>/dev/null; do
          p="$d"; case "$d" in */*) d="${d%/*}" ;; *) break ;; esac
        done
      else kept="$kept
  $p (edited since it was unpacked)"; nkept=$(( nkept + 1 )); fi
    done < "$rec"
    rm -f "$rec" || kit_refuse 1 pack-remove-failed "Error: could not remove the record $PACK_DIR/$ARG.wrote." "Next: delete it by hand, then re-run: $(basename "$0") remove $ARG."
    if [ "$removed" -eq 0 ] && [ "$nkept" -eq 0 ]; then echo "$ARG: no member is present, so nothing to remove."
    else
      printf '%s: removed %s member(s) byte-equal to the pack'"'"'s copy; kept %s.\n' "$ARG" "$removed" "$nkept"
      [ "$nkept" -eq 0 ] || printf 'KEPT (not what the pack holds; they are the project'"'"'s now):%s\n' "$kept"
      echo "Nothing is committed. Next: review, then commit the removal."
    fi ;;
esac
exit 0
