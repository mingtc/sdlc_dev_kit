#!/usr/bin/env bash
#
# KIT-CLASS: KIT — pack installer. Enumerates; never carries a list of skills.
# See process/EXTRACTION.md.
#
# install-skills.sh — copy this project's ROUTER SKILL PACK into a consumer repo.
#
# A router skill fires on a TASK SHAPE ("edit one of these as a file", "why was
# I refused?") and answers with an ADDRESS — the name of a section in the
# vendored documents, or the console command to run — instead of an
# explanation. The pattern, and the two guards that keep it honest, are in
# skills/README.md. Read that before authoring or editing a router.
#
# The pack is COPIED rather than shipped inside the artifact, because an agent
# harness discovers skills as FILES IN THE WORKING REPO; a copy buried inside an
# installed package is inert.
#
# It ENUMERATES the pack directory. There is deliberately NO list of skill names
# here: a list is one more copy of the truth, and it goes stale the first time
# somebody adds a router and forgets to update it.
#
# Usage:
#   /path/to/<project>/consumers/install-skills.sh            # consumer = CWD
#   /path/to/<project>/consumers/install-skills.sh /repo/root # explicit root
#
# Idempotent: re-running refreshes the copies in place.

set -euo pipefail

# Usage and unknown-option arms sit above every preflight and cd
# (process/contracts/issue-creation.md § 3): --help always succeeds; an unknown option exits 2.
case "${1:-}" in
  -h|--help)
    # Start and end derived: the KIT-CLASS marker's last line cites EXTRACTION.md.
    _h_start="$(awk 'NR<=12 && /EXTRACTION\.md/{print NR+1; exit}' "${BASH_SOURCE[0]:-$0}")"
    [ -n "$_h_start" ] || _h_start="$(awk 'NR<=12 && /KIT-CLASS:/{print NR+1; exit}' "${BASH_SOURCE[0]:-$0}")"
    [ -n "$_h_start" ] || _h_start=3
    _h_end="$(awk -v s="$_h_start" 'NR>=s && !/^#/{print NR-1; exit}' "${BASH_SOURCE[0]:-$0}")"
    sed -n "${_h_start},${_h_end:-26}p" "${BASH_SOURCE[0]:-$0}" | sed 's|^# \{0,1\}||'
    exit 0 ;;
  -*) echo "Error: unknown option: $1" >&2; exit 2 ;;
esac

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACK_SRC="$SCRIPT_DIR/skills"
[ -d "$PACK_SRC" ] || die "cannot find the skill pack next to this script ($PACK_SRC)."

CONSUMER="${1:-$(pwd)}"
CONSUMER="$(cd "$CONSUMER" && pwd)" || die "consumer path does not exist: ${1:-$(pwd)}"

DEST="$CONSUMER/.claude/skills"

copied=0
skipped=0
# Enumerate — never enumerate into a hard-coded list.
#
# Two things in skills/ are NOT part of the pack and are skipped by SHAPE, not
# by name-list: the pack's own README.md (documentation for the author, not a
# router) and any `EXAMPLE-*` directory (the skeleton this kit ships so you can
# see the shape). Delete the skeleton once you have authored a real router, or
# leave it — either way it never reaches a consumer.
while IFS= read -r source; do
    relative="${source#"$PACK_SRC"/}"
    case "$relative" in
        README.md|EXAMPLE-*/*|*/EXAMPLE-*/*)
            skipped=$((skipped + 1))
            continue
            ;;
    esac
    mkdir -p "$DEST/$(dirname "$relative")"
    cp "$source" "$DEST/$relative"
    copied=$((copied + 1))
done < <(find "$PACK_SRC" -type f | sort)

if [ "$copied" -eq 0 ]; then
    log "No router skills to install: $PACK_SRC holds only its README and the"
    log "EXAMPLE-* skeleton ($skipped file(s) skipped). That is the state of a"
    log "project that has not authored a pack yet — author one (see"
    log "$PACK_SRC/README.md) or drop this step from onboarding."
    exit 1
fi

log "Copied $copied skill-pack file(s) into $DEST ($skipped skipped: README + EXAMPLE-*)"
log "Each file POINTS at a section address or a console command; none of them"
log "restates one. Re-run this script after every refresh of the vendored"
log "artifact, so the pointers and the artifact move together."
