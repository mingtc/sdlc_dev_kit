#!/usr/bin/env bash
#
# KIT-CLASS: KIT — consumer onboarding. Reads its seams from
# update_vendored.sh (--print-seams) rather than keeping a second copy.
# See process/EXTRACTION.md.
#
# setup-consumer.sh — one-time onboarding for a NEW consumer of this project.
#
# Run it from (or point it at) a consumer repo root. It:
#   1. copies the canonical update_vendored.sh into the consumer's scripts/,
#   2. copies the advisory git-hook template into the consumer's scripts/,
#   3. copies the router skill pack into the consumer's .claude/skills/ (if this
#      project ships one — see skills/README.md; a project with no pack skips
#      this step and nothing else changes),
#   4. runs the refresh script, which builds + vendors the latest tagged
#      artifact into the consumer's ./vendor/,
#   5. prints what remains for the human or agent: the pin line, the credential
#      or configuration names, and the recommended advisory-nag wiring.
#
# THIS PROJECT NEVER TRACKS ITS CONSUMERS — onboarding is self-service, and the
# whole update loop is pull-based. Nothing here phones home, and nothing
# installed here updates itself.
#
# Usage:
#   /path/to/<project>/consumers/setup-consumer.sh            # consumer = CWD
#   /path/to/<project>/consumers/setup-consumer.sh /repo/root # explicit root

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
UPDATE_SRC="$SCRIPT_DIR/update_vendored.sh"
HOOK_SRC="$SCRIPT_DIR/hooks/post-merge"
SKILLS_INSTALLER="$SCRIPT_DIR/install-skills.sh"
[ -f "$UPDATE_SRC" ] || die "cannot find update_vendored.sh next to this script ($UPDATE_SRC)."

# Learn the seams from the update script itself (--print-seams): they are
# configured in one place. The pin line is for humans and manifests, not parsing.
eval "$(bash "$UPDATE_SRC" --print-seams | sed 's/^/SEAM_/')"
VENDORED_NAME="${SEAM_VENDORED_NAME:?--print-seams gave no VENDORED_NAME}"
ARTIFACT_GLOB="${SEAM_ARTIFACT_GLOB:?--print-seams gave no ARTIFACT_GLOB}"
VENDOR_DIR="${SEAM_VENDOR_DIR:-./vendor}"

case "$VENDORED_NAME$ARTIFACT_GLOB${SEAM_UPSTREAM_REPO_URL:-}" in
    *"<"*) die "$UPDATE_SRC still has unfilled <placeholder> seams. Fill its SEAMS block before onboarding anyone." ;;
esac

CONSUMER="${1:-$(pwd)}"
CONSUMER="$(cd "$CONSUMER" && pwd)" || die "consumer path does not exist: ${1:-$(pwd)}"
[ -d "$CONSUMER/.git" ] || log "Note: $CONSUMER does not look like a git repo root — continuing anyway."

log "Onboarding consumer: $CONSUMER"

# 1. Copy the canonical refresh script into the consumer's scripts/.
mkdir -p "$CONSUMER/scripts"
cp "$UPDATE_SRC" "$CONSUMER/scripts/update_vendored.sh"
chmod +x "$CONSUMER/scripts/update_vendored.sh"
log "Copied scripts/update_vendored.sh into the consumer."

# 2. Copy the advisory git-hook template so the nag can be wired with no path
#    edits (see the printed one-liner below). It is NOT installed automatically —
#    wiring the hook stays the consumer's explicit choice.
if [ -f "$HOOK_SRC" ]; then
    # STAMPED, not copied verbatim: the nag PRINTS <vendored-name>. A sed here,
    # not a runtime lookup, keeps the hook a few lines that cannot fail.
    sed "s/<vendored-name>/${VENDORED_NAME}/g" "$HOOK_SRC" \
        > "$CONSUMER/scripts/${VENDORED_NAME}-post-merge.hook"
    chmod +x "$CONSUMER/scripts/${VENDORED_NAME}-post-merge.hook"
    log "Copied scripts/${VENDORED_NAME}-post-merge.hook (advisory nag template) into the consumer."
else
    log "Note: hook template not found next to this script ($HOOK_SRC) — skipping; wire the nag manually per consumers/README.md."
fi

# 3. Copy the ROUTER SKILL PACK, if this project ships one. Delegated to
#    install-skills.sh, which ENUMERATES the pack directory — no list of skill
#    names lives in either script, so a router added later installs itself.
#    A project with no pack (or an unauthored one) is a normal state: the
#    installer says so and returns nonzero, and onboarding continues.
SKILLS_INSTALLED=no
if [ -f "$SKILLS_INSTALLER" ]; then
    if bash "$SKILLS_INSTALLER" "$CONSUMER"; then
        SKILLS_INSTALLED=yes
    else
        log "Note: no router skill pack was installed (see the message above) — continuing."
    fi
else
    log "Note: skill-pack installer not found next to this script ($SKILLS_INSTALLER) — skipping."
fi

# 4. Run the refresh script from the consumer root to vendor the latest tagged
#    artifact. Its STDOUT is exactly the pin line.
log "Building + vendoring the latest ${VENDORED_NAME} release…"
PIN_LINE="$(cd "$CONSUMER" && bash scripts/update_vendored.sh)"

# The one-artifact invariant, checked here rather than assumed: the refresh
# script removes older artifacts before copying the new one, so anything else
# means something outside this flow put a file in ./vendor/.
ARTIFACTS=$(cd "$CONSUMER" && ls $VENDOR_DIR/$ARTIFACT_GLOB 2>/dev/null || true)
ARTIFACT_COUNT=$(printf '%s\n' "$ARTIFACTS" | grep -c '.' || true)
[ "$ARTIFACT_COUNT" -eq 1 ] || die "expected exactly 1 vendored artifact in $CONSUMER/$VENDOR_DIR, found $ARTIFACT_COUNT:
$ARTIFACTS"
ARTIFACT_PATH="$ARTIFACTS"

# 5. Tell the human/agent what remains.
cat >&2 <<EOF

────────────────────────────────────────────────────────────────────────────
${VENDORED_NAME} is vendored. Router skill pack installed: ${SKILLS_INSTALLED}
(when yes: into .claude/skills/ in this repo — small files that fire on a task
 shape and point at the vendored documents' own section addresses. They carry
 no copy of those documents, so keep them thin; re-run install-skills.sh after
 every refresh.)

Three things remain for you:

1) PIN the artifact in this consumer's dependency manifest, so a fresh clone
   reproduces its environment from the LOCAL artifact with no upstream remote
   in the loop:

     ${PIN_LINE}

   Then install it into the consumer's environment. This is a FIRST INSTALL, so
   it must RESOLVE the transitive dependencies — do not use the artifact-only
   refresh command that update_vendored.sh prints when it finishes (that one
   deliberately skips resolution, which is right for a refresh and wrong here):

     <first-install command for ${ARTIFACT_PATH} — resolve dependencies>

2) Provide whatever CONFIGURATION or CREDENTIALS this project needs, in the
   consumer's own untracked config (never committed):

     <ENV_VAR_NAME>=...        # <what it is, and which surface needs it>
     <ENV_VAR_NAME_2>=...

   The authoritative, per-operation list is the one the vendored documents
   carry — read ${VENDOR_DIR}/${VENDORED_NAME}-GUIDE.md rather than this note,
   which names only the minimum.

3) (Recommended) Wire the ADVISORY update nag. It only TELLS you when a newer
   release exists; it NEVER auto-updates, never touches ${VENDOR_DIR}/, and
   never fails your git workflow. From the consumer repo root:

     cp scripts/${VENDORED_NAME}-post-merge.hook .git/hooks/post-merge
     chmod +x .git/hooks/post-merge

   Then a future 'git pull' prints '[${VENDORED_NAME}] UPDATE AVAILABLE …' when
   there is one. For a pipeline reminder instead of (or as well as) the hook,
   see the opt-in templates in consumers/ci/.

Refresh later — always DELIBERATE, never automatic:
     scripts/update_vendored.sh [tag]     # build + vendor, then re-pin
     scripts/update_vendored.sh --check   # report-only: newer tag available?

Full zero-knowledge walkthrough: consumers/README.md
────────────────────────────────────────────────────────────────────────────
EOF

# Echo the pin line on stdout too, so callers can capture it.
echo "$PIN_LINE"
