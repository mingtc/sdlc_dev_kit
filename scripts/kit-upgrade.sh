#!/usr/bin/env bash
# KIT-CLASS: KIT — the kit upgrade, run from the NEW kit against an adopted tree. See process/EXTRACTION.md.
# Take a newer kit into a project that runs an older one, without overwriting what the project
# changed. Contract: process/contracts/kit-upgrade.md.
#
# Run the NEW release's copy, from outside the tree it upgrades:
#   unzip -q project-kit-v<X.Y.Z>.zip -d <scratch>
#   <scratch>/scripts/kit-upgrade.sh --into <your project>
#   ...work through process/UPGRADE-CHECKLIST.md, marking each item "- [x]"...
#   <your project>/scripts/kit-upgrade.sh --finish --into <your project>
#
# The kit this script sits in is the NEW kit. The project's process/KIT-MANIFEST records every kit
# file as its release shipped it, so for each file the new kit ships:
#   the kit did not change it           kept as the project has it, edited or not
#   the project already has the new one nothing
#   the project's copy is as shipped    replaced by the new one
#   new upstream, absent here           added
#   anything else                       NEVER overwritten: the new one is staged under
#                                       .kit-upgrade/files/ and the checklist says merge it
# A STAGED COPY NEVER CARRIES A LIVE NAME: each `.claude` path component is written `_claude`, and
# every staged file ends in `.kit-new`. Under its own name a staged skill, agent doc, or
# AGENTS.md would be loaded by a harness, and a staged .gitignore or .gitattributes would govern
# the staging tree. Each checklist item names its staged copy exactly.
# A file the new kit no longer ships is listed, never deleted. With no sha256 tool (shasum or
# sha256sum), or no process/KIT-MANIFEST in the project, every file the kit changed that differs
# here is a merge item, and the run says why.
#
# The checklist gets one item per Action required entry in each process/KIT-RELEASE-NOTES.md
# section newer than the project's process/KIT-VERSION (an X.Y.Z+<tree> version is read as that
# file's § How versions work defines it), plus one per merge or removal. The first run never
# stamps process/KIT-VERSION. --finish refuses while any item is "- [ ]", or while the marked
# checklist is uncommitted; then it writes the new process/KIT-VERSION and process/KIT-MANIFEST,
# and removes the checklist and .kit-upgrade/.
#
# It never commits: the upgrade is ordinary work, committed through the project's own board.
# Every refusal leaves a progress record (refusal=<rule-id>) in the project's record directory.
# Exit 2: an unknown option or a missing option value. Exit 1: any other refusal, including a
# surplus positional argument — it looks like a usage error but is not one.
#
# Options:
#   --into <dir>   the project to upgrade: the top level of a git work tree. Required.
#   --finish       stamp the upgrade once every checklist item is marked.
#   -h, --help     this text.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"
# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh
# A usage request always succeeds, in any position, before any argument is interpreted
# (issue-creation.md § 3).
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done
# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

# Greppable defaults: check-board.sh reads UPGRADE_CHECKLIST from this line.
UPGRADE_CHECKLIST='process/UPGRADE-CHECKLIST.md'
STAGE_DIR='.kit-upgrade'

INTO=""; FINISH=false
while [ $# -gt 0 ]; do
  case "$1" in
    --into)   need_val "$@"; INTO="$2"; shift 2 ;;
    --finish) FINISH=true; shift ;;
    -*) kit_refuse 2 unknown-option "Error: unknown option: $1" "  Run $(basename "$0") --help for its options." ;;
    *)  kit_refuse 1 unexpected-argument "Error: unexpected argument: $1" "  The project is named with --into <dir>." ;;
  esac
done

[ -n "$INTO" ] || kit_refuse 2 upgrade-no-target \
  "Error: no --into <dir>: name the project to upgrade." \
  "  Run the NEW kit's copy against it: <scratch>/scripts/kit-upgrade.sh --into <your project>"

# ── THE TARGET: the top level of a git work tree. ─────────────────────────────
TGT="$(cd "$INTO" 2>/dev/null && pwd -P)" || TGT=""
TOP=""
[ -n "$TGT" ] && TOP="$(cd "$TGT" && git rev-parse --show-toplevel 2>/dev/null)" && TOP="$(cd "$TOP" && pwd -P)"
if [ -z "$TGT" ] || [ -z "$TOP" ] || [ "$TOP" != "$TGT" ]; then
  kit_refuse 1 upgrade-target-not-a-repo \
    "Error: --into $INTO is not the top level of a git work tree${TOP:+ (its top level is $TOP)}." \
    "  Name the project's root: the upgrade writes paths relative to it."
fi
# Records land with the project's own, wherever this was run from.
if [ -z "${KIT_PROGRESS_DIR:-}" ] && command -v kit_progress_dir >/dev/null 2>&1; then
  KIT_PROGRESS_DIR="$(cd "$TGT" && kit_progress_dir)"; export KIT_PROGRESS_DIR
fi

CL="$TGT/$UPGRADE_CHECKLIST"
ST="$TGT/$STAGE_DIR"

# ver_ok <v> — X.Y.Z, or X.Y.Z+<tree> (process/KIT-RELEASE-NOTES.md § How versions work).
ver_ok() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9a-f]+)?$ ]]; }
ver_base() { printf '%s' "${1%%+*}"; }
ver_is_build() { case "$1" in *+*) return 0 ;; *) return 1 ;; esac; }
# ver_cmp <a> <b> — of two bare X.Y.Z: prints -1, 0 or 1.
ver_cmp() {
  awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) { if (x[i] + 0 < y[i] + 0) { print -1; exit } if (x[i] + 0 > y[i] + 0) { print 1; exit } }
    print 0 }'
}
read_version() {  # <file> — its one line, or nothing
  [ -f "$1" ] && sed -n '1{s/[[:space:]]*$//;p;}' "$1"
}

# ── --finish ──────────────────────────────────────────────────────────────────
if [ "$FINISH" = true ]; then
  [ -f "$CL" ] || kit_refuse 1 upgrade-nothing-to-finish \
    "Error: no upgrade is in progress in $TGT: $UPGRADE_CHECKLIST is absent." \
    "  Start one with the NEW kit's copy: <scratch>/scripts/kit-upgrade.sh --into $TGT"
  { [ -f "$ST/KIT-VERSION" ] && [ -f "$ST/KIT-MANIFEST" ]; } || kit_refuse 1 upgrade-staging-missing \
    "Error: $UPGRADE_CHECKLIST exists but $STAGE_DIR/ does not hold the new KIT-VERSION and KIT-MANIFEST." \
    "  Delete $UPGRADE_CHECKLIST and $STAGE_DIR/, then run the NEW kit's copy again: its first run is safe to repeat."
  open_n="$(grep -c '^- \[ \]' "$CL" || true)"
  if [ "${open_n:-0}" -gt 0 ]; then
    kit_refuse 1 upgrade-checklist-unmarked \
      "Error: $open_n checklist item(s) in $UPGRADE_CHECKLIST are unmarked; process/KIT-VERSION is stamped only when none is." \
      "$(grep '^- \[ \]' "$CL" | sed 's/^/  /')" \
      "  Do each one and mark it \"- [x]\", then run --finish again."
  fi
  # The marks are the upgrade's record: removing an uncommitted checklist would leave history
  # without them.
  [ -z "$(cd "$TGT" && git status --porcelain -- "$UPGRADE_CHECKLIST" 2>/dev/null)" ] || kit_refuse 1 upgrade-checklist-uncommitted \
    "Error: $UPGRADE_CHECKLIST has uncommitted changes; --finish removes it." \
    "  Commit it as marked first, so the record of what was done survives, then run --finish again."
  dirty="$(cd "$TGT" && git status --porcelain -- process/KIT-VERSION process/KIT-MANIFEST 2>/dev/null)"
  [ -z "$dirty" ] || kit_refuse 1 upgrade-target-dirty \
    "Error: $TGT has uncommitted changes under paths --finish writes:" "$(printf '%s\n' "$dirty" | sed 's/^/  /')" \
    "  Commit or stash them first."
  new_v="$(read_version "$ST/KIT-VERSION")"
  cp "$ST/KIT-VERSION" "$TGT/process/KIT-VERSION" && cp "$ST/KIT-MANIFEST" "$TGT/process/KIT-MANIFEST" \
    || kit_refuse 1 upgrade-write-failed "Error: could not write process/KIT-VERSION or process/KIT-MANIFEST in $TGT."
  rm -rf "$ST" && rm -f "$CL"
  echo "kit-upgrade: $TGT now records kit $new_v (process/KIT-VERSION, process/KIT-MANIFEST)."
  echo "  $UPGRADE_CHECKLIST and $STAGE_DIR/ are removed. Nothing is committed: commit this through your own board."
  exit 0
fi

# ── THE SOURCE: the unpacked kit this script sits in. ─────────────────────────
SRC="$(cd "$SCRIPT_DIR/.." && pwd -P)"
NEW_MAN="$SRC/process/KIT-MANIFEST"
if [ ! -f "$NEW_MAN" ] || [ ! -f "$SRC/process/KIT-VERSION" ]; then
  kit_refuse 1 upgrade-source-not-a-kit \
    "Error: $SRC is not an unpacked kit: it has no process/KIT-MANIFEST and process/KIT-VERSION." \
    "  Run the copy inside the unzipped release: unzip -q project-kit-v<X.Y.Z>.zip -d <scratch>"
fi
[ "$SRC" != "$TGT" ] || kit_refuse 1 upgrade-source-is-target \
  "Error: this is the project's own copy of kit-upgrade.sh, so it would upgrade $TGT to itself." \
  "  Run the NEW release's copy: unzip -q project-kit-v<X.Y.Z>.zip -d <scratch> && <scratch>/scripts/kit-upgrade.sh --into $TGT"

NEW_V="$(read_version "$SRC/process/KIT-VERSION")"
CUR_V="$(read_version "$TGT/process/KIT-VERSION")"
ver_ok "$NEW_V" || kit_refuse 1 upgrade-version-unreadable \
  "Error: the new kit's process/KIT-VERSION reads '$NEW_V', not X.Y.Z or X.Y.Z+<tree>."
ver_ok "$CUR_V" || kit_refuse 1 upgrade-version-unreadable \
  "Error: $TGT/process/KIT-VERSION reads '${CUR_V:-<absent>}', not X.Y.Z or X.Y.Z+<tree>." \
  "  Write the version this project runs there, as its release shipped it, and commit it first."

# ── AN UPGRADE ALREADY IN PROGRESS ────────────────────────────────────────────
if [ -f "$CL" ] || [ -e "$ST" ]; then
  prog_v="$(read_version "$ST/KIT-VERSION")"
  [ -n "$prog_v" ] || prog_v="$(sed -n 's/^target:[[:space:]]*//p' "$CL" 2>/dev/null | sed -n '1p')"
  if [ "$prog_v" != "$NEW_V" ]; then
    kit_refuse 1 upgrade-checklist-other-version \
      "Error: an upgrade to ${prog_v:-<unknown>} is in progress in $TGT ($UPGRADE_CHECKLIST, $STAGE_DIR/), and this kit is $NEW_V." \
      "  Finish it (--finish), or delete both and commit that, then run this again."
  fi
  echo "kit-upgrade: the upgrade to $NEW_V is already staged in $TGT; nothing was changed."
  open_n="$(grep -c '^- \[ \]' "$CL" 2>/dev/null)"
  echo "  ${open_n:-0} item(s) unmarked in $UPGRADE_CHECKLIST. When none is: $TGT/scripts/kit-upgrade.sh --finish --into $TGT"
  exit 0
fi

# ── WHICH NOTES SECTIONS ARE NEWER THAN THE TREE ──────────────────────────────
CUR_B="$(ver_base "$CUR_V")"; NEW_B="$(ver_base "$NEW_V")"
c="$(ver_cmp "$NEW_B" "$CUR_B")"
if [ "$c" = -1 ] || { [ "$c" = 0 ] && ver_is_build "$CUR_V" && ! ver_is_build "$NEW_V"; }; then
  kit_refuse 1 upgrade-target-older \
    "Error: this kit is $NEW_V, older than the $CUR_V that $TGT records. Nothing was changed."
fi

# ── THE FILE PASS: classify every path, write nothing yet. ────────────────────
SHA=""
if command -v shasum >/dev/null 2>&1; then SHA="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then SHA="sha256sum"; fi
sha_of() { $SHA "$1" 2>/dev/null | awk '{print $1}'; }
OLD_MAN="$TGT/process/KIT-MANIFEST"
DEGRADED=""   # why a differing file cannot be told apart from an edited one
[ -n "$SHA" ] || DEGRADED="no sha256 tool (shasum or sha256sum) is on this machine"
[ -f "$OLD_MAN" ] || DEGRADED="${DEGRADED:+$DEGRADED, and }this project has no process/KIT-MANIFEST"

# One row per path: <path> TAB <new hash> TAB <old hash, empty when the old manifest has no such
# path> — then removed rows as <path> TAB - TAB <old hash>. A hash the build could not compute is "?".
JOINED="$(awk -F'  ' '
  /^#/ || NF < 2 { next }
  FILENAME == ARGV[1] { old[$2] = ($1 ~ /^[0-9a-f]+$/) ? $1 : "?"; next }
  { newseen[$2] = 1; printf "%s\t%s\t%s\n", $2, ($1 ~ /^[0-9a-f]+$/) ? $1 : "?", old[$2] }
  END { for (p in old) if (!(p in newseen)) printf "%s\t-\t%s\n", p, old[p] }
' "$( [ -f "$OLD_MAN" ] && printf '%s' "$OLD_MAN" || printf '/dev/null' )" "$NEW_MAN")"

WRITE=(); ADDED=(); REPLACED=(); MERGE=(); MERGE_WHY=(); REMOVED=()
n_current=0; n_kept=0
while IFS="$(printf '\t')" read -r p nh oh; do
  [ -n "$p" ] || continue
  case "$p" in /*|../*|*/../*|*/..) kit_refuse 1 upgrade-source-not-a-kit "Error: the new kit's manifest names an unsafe path: $p" ;; esac
  [ "$p" = process/KIT-VERSION ] && continue   # stamped by --finish, never by this pass
  dst="$TGT/$p"
  if [ "$nh" = - ]; then                        # the new kit no longer ships it
    [ -e "$dst" ] && REMOVED+=("$p")
    continue
  fi
  src="$SRC/$p"
  [ -f "$src" ] || kit_refuse 1 upgrade-source-not-a-kit "Error: the new kit's manifest names $p, which the kit does not hold."
  known_old=""; [ -n "$oh" ] && [ "$oh" != "?" ] && known_old=1
  if [ -n "$known_old" ] && [ "$oh" = "$nh" ]; then
    n_kept=$((n_kept + 1)); continue            # the kit did not change it: whatever is here stays
  fi
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    n_current=$((n_current + 1)); continue
  fi
  if [ ! -e "$dst" ]; then
    if [ -f "$OLD_MAN" ] && [ -z "$oh" ]; then   # new upstream
      d="${p%/*}"
      if [ "$d" != "$p" ] && [ ! -d "$TGT/$d" ] \
         && awk -F'  ' -v d="$d/" '!/^#/ && index($2, d) == 1 { f = 1 } END { exit !f }' "$OLD_MAN"; then
        MERGE+=("$p"); MERGE_WHY+=("new upstream, in $d/, which this project removed"); continue
      fi
      ADDED+=("$p"); WRITE+=("$p"); continue
    fi
    MERGE+=("$p")
    if [ -f "$OLD_MAN" ]; then MERGE_WHY+=("this project removed it, and the kit changed it")
    else MERGE_WHY+=("absent here, and with no manifest there is no telling whether it is new or was removed"); fi
    continue
  fi
  if [ -n "$SHA" ] && [ -n "$known_old" ] && [ "$(sha_of "$dst")" = "$oh" ]; then
    REPLACED+=("$p"); WRITE+=("$p"); continue
  fi
  MERGE+=("$p")
  if [ -n "$SHA" ] && [ -n "$known_old" ]; then MERGE_WHY+=("this project changed it, and so did the kit")
  else MERGE_WHY+=("the kit changed it and it differs here; nothing tells whether this project changed it"); fi
done <<JOINED_EOF
$JOINED
JOINED_EOF

# ── THE ACTION REQUIRED ITEMS ─────────────────────────────────────────────────
# Every section newer than the tree up to the new kit; Unreleased only when the new kit is a build.
# From a build (X.Y.Z+<tree>), the release after X.Y.Z may already be held — and so may Unreleased,
# when both are builds after one release.
ITEMS="$(awk '
  /^## / { sec = ""; if ($0 ~ /^## \[/) { sec = $0; sub(/^## \[/, "", sec); sub(/\].*$/, "", sec) }
           inact = 0; n = 0; next }
  /^###+ Action required/ { inact = (sec != ""); next }
  /^##/ { inact = 0; next }
  inact && /^- / { n++; t = substr($0, 3)
    if (substr(t, 1, 2) == "**") { t = substr(t, 3); i = index(t, "**"); if (i) t = substr(t, 1, i - 1); else t = t "..." }
    if (length(t) > 110) t = substr(t, 1, 107) "..."
    printf "%s\t%d\t%s\n", sec, n, t }
' "$SRC/process/KIT-RELEASE-NOTES.md" 2>/dev/null)"

NEXT_REL=""   # the smallest released section above the tree's base
while IFS="$(printf '\t')" read -r sec _ _; do
  [ -n "$sec" ] && [ "$sec" != Unreleased ] || continue
  [ "$(ver_cmp "$sec" "$CUR_B")" = 1 ] || continue
  if [ -z "$NEXT_REL" ] || [ "$(ver_cmp "$sec" "$NEXT_REL")" = -1 ]; then NEXT_REL="$sec"; fi
done <<ITEMS_EOF
$ITEMS
ITEMS_EOF

ACTION=()
if [ "$CUR_V" != "$NEW_V" ]; then
  while IFS="$(printf '\t')" read -r sec n t; do
    [ -n "$sec" ] || continue
    held=""
    if [ "$sec" = Unreleased ]; then
      ver_is_build "$NEW_V" || continue
      ver_is_build "$CUR_V" && [ "$CUR_B" = "$NEW_B" ] && held=1
    else
      [ "$(ver_cmp "$sec" "$CUR_B")" = 1 ] && [ "$(ver_cmp "$sec" "$NEW_B")" != 1 ] || continue
      ver_is_build "$CUR_V" && [ "$sec" = "$NEXT_REL" ] && held=1
    fi
    line="Action required, [$sec] item $n: $t — process/KIT-RELEASE-NOTES.md § [$sec]"
    [ -z "$held" ] || line="$line (this tree is a build after $CUR_B, so it may already hold this: diff before applying)"
    ACTION+=("$line")
  done <<ITEMS_EOF
$ITEMS
ITEMS_EOF
fi

total=$(( ${#ACTION[@]} + ${#MERGE[@]} + ${#REMOVED[@]} ))
if [ "$CUR_V" = "$NEW_V" ] && [ "$total" -eq 0 ] && [ "${#WRITE[@]}" -eq 0 ]; then
  echo "kit-upgrade: $TGT already runs kit $NEW_V, and every file is current. Nothing to do."
  exit 0
fi

# ── NOTHING UNCOMMITTED WHERE IT WRITES ───────────────────────────────────────
dirty="$(cd "$TGT" && git status --porcelain --untracked-files=all -- ${WRITE[@]+"${WRITE[@]}"} "$UPGRADE_CHECKLIST" "$STAGE_DIR" 2>/dev/null)"
if [ -n "$dirty" ]; then
  kit_refuse 1 upgrade-target-dirty \
    "Error: $TGT has uncommitted changes under paths this upgrade would write:" \
    "$(printf '%s\n' "$dirty" | sed 's/^/  /')" \
    "  Commit or stash them first, so that undoing the upgrade can never discard work of yours."
fi

# ── WRITE ─────────────────────────────────────────────────────────────────────
# staged_rel <path> — where a merge item's new copy goes: disarmed, never under a live name.
staged_rel() {
  printf '%s/files/%s.kit-new' "$STAGE_DIR" "$(printf '%s' "$1" | sed 's#^\.claude/#_claude/#; s#/\.claude/#/_claude/#g')"
}
put() {  # <src> <dst> — copy, carrying the executable bit
  mkdir -p "$(dirname "$2")" && cp "$1" "$2" || return 1
  if [ -x "$1" ]; then chmod +x "$2"; else chmod a-x "$2"; fi
}
fail_write() {
  kit_refuse 1 upgrade-write-failed "Error: could not write $1." \
    "  The tree is part-written: 'git -C $TGT status' shows what changed, and 'git -C $TGT checkout -- .' plus removing $STAGE_DIR/ and $UPGRADE_CHECKLIST undoes it."
}
for p in ${WRITE[@]+"${WRITE[@]}"}; do put "$SRC/$p" "$TGT/$p" || fail_write "$p"; done
mkdir -p "$ST/files" || fail_write "$STAGE_DIR/"
for p in ${MERGE[@]+"${MERGE[@]}"}; do put "$SRC/$p" "$TGT/$(staged_rel "$p")" || fail_write "$(staged_rel "$p")"; done
cp "$SRC/process/KIT-VERSION" "$ST/KIT-VERSION" && cp "$NEW_MAN" "$ST/KIT-MANIFEST" || fail_write "$STAGE_DIR/KIT-VERSION"

{
  echo "<!-- Written by scripts/kit-upgrade.sh; it and check-board.sh read this file. One item per line. -->"
  echo "# Kit upgrade: $CUR_V → $NEW_V"
  echo
  echo "target: $NEW_V"
  echo
  echo "Mark each item \`- [x]\` when it is done. An Action required item you cannot apply as written is"
  echo "a kit finding (process/MANUAL.md § Kit feedback, M3): record it, then mark the item."
  echo "Until every item is marked, keep this file committed: it is the upgrade's record for whoever"
  echo "comes next. Then \`./scripts/kit-upgrade.sh --finish --into .\` stamps process/KIT-VERSION"
  echo "and removes this file and \`$STAGE_DIR/\`."
  if [ -n "$DEGRADED" ]; then
    echo
    echo "Every file the kit changed that differs here is a merge item, because $DEGRADED."
  fi
  if [ "${#ACTION[@]}" -gt 0 ]; then
    echo; echo "## Action required"; echo
    for l in "${ACTION[@]}"; do echo "- [ ] $l"; done
  fi
  if [ "$(( ${#MERGE[@]} + ${#REMOVED[@]} + ${#ADDED[@]} + ${#REPLACED[@]} ))" -gt 0 ]; then
    echo; echo "## Files"; echo
    i=0
    while [ "$i" -lt "${#MERGE[@]}" ]; do
      echo "- [ ] merge ${MERGE[$i]} — ${MERGE_WHY[$i]}; the new copy is $(staged_rel "${MERGE[$i]}")"
      i=$((i + 1))
    done
    for p in ${REMOVED[@]+"${REMOVED[@]}"}; do
      echo "- [ ] removed upstream: $p — the new kit no longer ships it; delete it, or keep it as this project's own"
    done
    if [ "$(( ${#ADDED[@]} + ${#REPLACED[@]} ))" -gt 0 ]; then
      echo "- [ ] stamp what arrived: the ${#ADDED[@]} added and ${#REPLACED[@]} replaced file(s) are unstamped — run the checks in process/KIT-RELEASE-NOTES.md § How to upgrade (\"A line the kit ADDS arrives unstamped\")"
    fi
  fi
} > "$CL" || fail_write "$UPGRADE_CHECKLIST"

echo "kit-upgrade: $TGT, kit $CUR_V → $NEW_V (staged; process/KIT-VERSION is unchanged)."
echo "  replaced ${#REPLACED[@]}, added ${#ADDED[@]}, already current $n_current, unchanged upstream (kept as you have them) $n_kept"
echo "  to merge ${#MERGE[@]} (new copies in $STAGE_DIR/files/), removed upstream ${#REMOVED[@]}, Action required ${#ACTION[@]}"
[ -z "$DEGRADED" ] || echo "  every file the kit changed that differs here is a merge item, because $DEGRADED."
echo
echo "Nothing is committed. Next:"
echo "  1. Review: git -C $TGT status; git -C $TGT diff"
echo "  2. Commit it — $UPGRADE_CHECKLIST and $STAGE_DIR/ included — through your own board and gates."
echo "  3. Work through $UPGRADE_CHECKLIST, marking each item \"- [x]\"."
echo "  4. $TGT/scripts/kit-upgrade.sh --finish --into $TGT, then commit that too."
exit 0
