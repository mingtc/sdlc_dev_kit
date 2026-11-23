#!/usr/bin/env bash
# KIT-CLASS: KIT — writes process/KIT-MANIFEST in a clone of the kit, from the commit that was cloned. See process/EXTRACTION.md.
# A release zip carries process/KIT-MANIFEST and a clone of the kit does not. kit-upgrade.sh (as the
# source of an upgrade), kit-init.sh's uncommitted-kit check, check-board.sh arm [v] and the self-test
# all read it, and it records which files the kit shipped. This writes it with the same function the
# release build uses (scripts/lib/kit-manifest.sh), so a clone and a zip record the same rows.
#
# It reads the COMMITTED tree (HEAD), never the working tree, and refuses while a tracked file differs
# from that commit: a manifest written over a local edit would record the edit as shipped, and a later
# upgrade would take the file for the kit's own and overwrite it.
#
# Usage: ./scripts/kit-manifest.sh
#
# Run it once, at the root of an unmodified clone, before you copy the clone's files or run kit-init.sh
# in it. It writes process/KIT-MANIFEST and does not commit it: adopt the clone in place and kit-init.sh
# needs it committed (the command is printed). It refuses where the
# manifest already exists (a release zip and an adopted project carry the one they came from), outside
# a git clone, and with any option. Exit status: 0 written; 1 a refusal; 2 a usage error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"
# shellcheck source=lib/kit-manifest.sh
. "$SCRIPT_DIR/lib/kit-manifest.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# A usage request always succeeds, in any position, before any argument is interpreted.
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done
case "${1:-}" in
  "") ;;
  -*) kit_refuse 2 unknown-option "Error: unknown option: $1" "Next: run $(basename "$0") --help; it takes no options." ;;
  *)  kit_refuse 1 unexpected-argument "Error: unexpected argument: $1" "Next: run $(basename "$0") with no arguments, from the clone's root." ;;
esac

OUT="$ROOT/$KIT_MANIFEST_REL"
if [ -e "$OUT" ]; then
  kit_refuse 1 manifest-present \
    "Error: $KIT_MANIFEST_REL already exists, so there is nothing to write." \
    "       A release zip and an adopted project carry the manifest of the release they came from; writing it again would record every local edit as shipped." \
    "Next: nothing to do. To write it afresh in a clone that is not yet adopted, delete it first: rm $KIT_MANIFEST_REL"
fi

top="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" || top=""
is_clone=1
{ [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$ROOT" ] && git -C "$ROOT" cat-file -e "HEAD:process/KIT-VERSION" 2>/dev/null; } || is_clone=0
if [ "$is_clone" -eq 0 ]; then
  kit_refuse 1 not-a-kit-clone \
    "Error: $ROOT is not the root of a git clone of the kit with a commit that holds process/KIT-VERSION." \
    "Next: clone the kit's repository and run ./scripts/kit-manifest.sh at its root; from an unzipped release it is not needed, the zip already carries process/KIT-MANIFEST."
fi

dirty="$(git -C "$ROOT" -c core.quotepath=false diff --name-only HEAD -- 2>/dev/null)"
if [ -n "$dirty" ]; then
  ndirty="$(printf '%s\n' "$dirty" | wc -l | tr -d ' ')"
  kit_refuse 1 tracked-files-differ \
    "Error: $ndirty tracked file(s) differ from the commit this clone is at, so a manifest written now would record the edits as shipped:" \
    "$(printf '%s\n' "$dirty" | sed -n '1,10p' | sed 's/^/         /')" \
    "Next: put them back (git checkout -- <path>), or stash them, then run ./scripts/kit-manifest.sh again; an edited kit is adopted with kit-init.sh after this, not before."
fi

tmp="$(mktemp -d 2>/dev/null)" || tmp=""
[ -n "$tmp" ] && [ -d "$tmp" ] || kit_refuse 1 no-scratch-dir \
  "Error: could not make a scratch directory to read the committed tree into." \
  "Next: make TMPDIR writable (or free space there), then run ./scripts/kit-manifest.sh again."
trap 'rm -rf "$tmp"' EXIT

# THE COMMITTED TREE, BLOB BY BLOB: git's raw bytes, with none of a checkout's line-ending conversion.
nfiles=0
while IFS= read -r -d '' ent; do
  meta="${ent%%$'\t'*}"; path="${ent#*$'\t'}"
  case "${meta%% *}" in 100644|100755) ;; *) continue ;; esac
  mkdir -p "$tmp/$(dirname "$path")" && git -C "$ROOT" cat-file blob "${meta##* }" > "$tmp/$path" \
    || kit_refuse 1 read-commit-failed \
         "Error: could not read $path from the commit." \
         "Next: run git -C $ROOT fsck, fix what it names or clone again, then run ./scripts/kit-manifest.sh again."
  nfiles=$((nfiles + 1))
done < <(git -C "$ROOT" ls-tree -r -z HEAD)
[ "$nfiles" -gt 0 ] || kit_refuse 1 empty-commit \
  "Error: the commit this clone is at holds no files." \
  "Next: check out the kit's release commit (git checkout <tag>), then run ./scripts/kit-manifest.sh again."

err="$(kit_manifest_write "$tmp" 2>&1)" || kit_refuse 1 manifest-write-failed \
  "Error: the manifest could not be written from the commit:" \
  "$err" \
  "Next: fix what the message names, commit it, and run ./scripts/kit-manifest.sh again; if the clone is not an intact kit, clone again."
cp "$tmp/$KIT_MANIFEST_REL" "$OUT" || kit_refuse 1 manifest-copy-failed \
  "Error: could not write $OUT." \
  "Next: check that process/ is writable in the clone, then run ./scripts/kit-manifest.sh again."

echo "kit-manifest: wrote $KIT_MANIFEST_REL — $(grep -vc '^#' "$OUT" | tr -d ' ') file(s), read from commit $(git -C "$ROOT" rev-parse --short HEAD)."
echo "Next: it goes with the files you copy from this clone; to adopt this clone in place, commit it first (kit-init.sh needs every kit file committed): git add -f $KIT_MANIFEST_REL && MSG_OK=1 git commit -m 'Add the kit manifest'"
