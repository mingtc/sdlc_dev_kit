#!/usr/bin/env bash
#
# KIT-CLASS: KIT — the consumer-updater template. Every project value is a named
# seam in the SEAMS block below; the logic under it travels unedited.
# See process/EXTRACTION.md.
#
# update_vendored.sh — refresh the vendored artifact of ONE upstream project in
# THIS consumer repo. Canonical template shipped by the upstream project; each
# consumer keeps its own copy at scripts/update_vendored.sh.
#
# ─────────────────────────────────────────────────────────────────────────────
# IS THIS FILE FOR YOU?
# Only a project that SHIPS something into other repositories needs it. If your
# project has no downstream consumers, delete consumers/ — an unused template
# that looks configured is worse than an absent one. The doctrine behind every
# rule below is process/doctrine/distribution.md; read that first if you are
# deciding *whether* to distribute this way.
# ─────────────────────────────────────────────────────────────────────────────
#
# DISTRIBUTION MODEL (the one this script implements): consumers VENDOR a built
# artifact into ./vendor/ and PIN it through their own dependency mechanism.
# THIS script builds/refreshes that artifact, so it DOES clone the upstream
# repo — it needs the upstream git remote (see UPSTREAM_REPO_URL below).
# What needs NO reachable remote is a downstream clone of the CONSUMER: it
# reproduces its environment from the already-vendored local artifact. Refresh
# is pull-based and DELIBERATE: this script touches the network ONLY when you
# run it. Nothing here runs on `git pull`.
#
# Usage (run from the consumer repo root):
#   scripts/update_vendored.sh              # build + vendor the LATEST release tag
#   scripts/update_vendored.sh v1.2.0       # build + vendor a specific tag
#   scripts/update_vendored.sh --check      # report-only: is a newer tag available?
#   scripts/update_vendored.sh --print-seams  # this file's configured seams (for tooling)
#
# TWO PATHS, and you never have to choose. It first tries the DISTRIBUTION-BRANCH
# FAST PATH — a shallow clone of the upstream's consumer-only branch, which
# carries the current release's artifact and release documents and nothing else,
# so there is no build and no history to fetch. If that branch is absent (an
# older repo state) or stale (its artifact is not the version you asked for), it
# FALLS BACK to the build-from-tag path: clone, check out the tag, build. A log
# line always says which path ran; ./vendor/ is identical either way, so nothing
# downstream can tell.
#
# THE TAG REMAINS AUTHORITATIVE for every version. The distribution branch
# carries only the CURRENT release (the upstream replaces it on each cut — one
# commit, force-pushed), so asking for any older tag builds from that tag. Set
# VENDORED_NO_DIST=1 to skip the fast path entirely.
#
# WHAT LANDS IN ./vendor/ (all of it refreshed on every run, all of it sourced
# from the checked-out tag, so it always describes the artifact sitting next to
# it):
#   • the artifact you pin (exactly ONE — see vendored_version() on why more is
#     a refusal rather than a guess)
#   • one dropped copy per entry in RELEASE_DOCS — the release documents your
#     project ships (typically: the usage guide, the engineering changelog, and
#     the consumer-facing release notes)
# A tag that predates one of those documents simply skips that drop with a
# logged note; the run still succeeds.
#
# `--check` is REPORT-ONLY: it never writes to ./vendor/ (or anywhere else) and
# never updates. Its STDOUT is EXACTLY ONE VERDICT LINE — `UP TO DATE`,
# `UPDATE AVAILABLE` or `AHEAD` — because consumers GREP it (the advisory git
# hook and the CI templates in consumers/ci/ both do). Everything else this
# script prints, including the what-changed report, is narration on STDERR.
# When a newer tag exists it also prints WHAT CHANGED — the release notes'
# section headers for the versions in between — which needs that tag's notes
# file and therefore a throwaway shallow clone, deleted before it returns. Set
# VENDORED_CHECK_NOTES=0 to skip that and keep the check to one lightweight
# `git ls-remote` (what the advisory post-merge nag hook does, so a `git pull`
# stays fast).
#
set -euo pipefail

# ═════════════════════════════════════════════════════════════════════════════
# SEAMS — the only lines a project edits. Fill every <angle-bracket>.
# ═════════════════════════════════════════════════════════════════════════════

# The name of the thing being vendored. Used for the artifact glob, the dropped
# document names, and every message.
VENDORED_NAME="${VENDORED_NAME:-<vendored-name>}"

# ─────────────────────────────────────────────────────────────────────────────
# THE ONE PLACE THE UPSTREAM REPO LOCATION LIVES.
# Keep it that way. This seam exists because a forge migration is otherwise a
# hunt through every consumer's copy of this file: the donor project migrated
# forges once during this script's life and, because the URL lived on exactly
# one line, each consumer's migration was a one-line edit (plus one re-vendor).
# Any URL git can clone works — including a LOCAL bare repository
# (`/srv/git/<project>.git` or `file:///…`), which is the no-forge case
# process/GIT-HOSTING.md describes. It is overridable from the environment
# (default unchanged) so a self-test can point tag selection at a local
# throwaway repo without touching the network.
UPSTREAM_REPO_URL="${VENDORED_REPO_URL:-<upstream-repo-url>}"
# ─────────────────────────────────────────────────────────────────────────────

# WHICH FILES IN ./vendor/ ARE THE ARTIFACT. A glob, matched inside ./vendor/
# and inside a build output directory. It must match ONLY artifacts — never the
# dropped release documents — and must not need word-splitting (no spaces).
#
#   ┌ a worked example from the donor project (anonymized) ──────────────────┐
#   │ The donor shipped one installable single-file package per release,      │
#   │ named `<name>-<version>-<platform-tags>.<ext>`, so its glob was         │
#   │ `${VENDORED_NAME}-*.<ext>` and its dropped documents were named         │
#   │ `${VENDORED_NAME}-GUIDE.md` etc. — deliberately a different shape, so   │
#   │ the artifact glob could never sweep up a document.                      │
#   └────────────────────────────────────────────────────────────────────────┘
ARTIFACT_GLOB="${ARTIFACT_GLOB:-${VENDORED_NAME}-*.<artifact-ext>}"

# RELEASE TAG CONVENTION. Only tags matching RELEASE_TAG_RE are ever considered
# "a release"; TAG_PREFIX is stripped to get a version.
TAG_PREFIX="${TAG_PREFIX:-v}"
RELEASE_TAG_RE="^${TAG_PREFIX}[0-9]"

# THE RELEASE DOCUMENTS THIS PROJECT SHIPS, as `<path-in-upstream-repo>|<LABEL>`.
# Each is dropped beside the artifact as `${VENDORED_NAME}-<LABEL>.md`, so the
# consumer can read it without opening the artifact or the network. Add or
# remove rows freely — nothing else in this script knows the list.
RELEASE_DOCS=(
    "<path/to/GUIDE.md>|GUIDE"
    "CHANGELOG.md|CHANGELOG"
    "RELEASE_NOTES.md|RELEASE_NOTES"
)

# The two documents `--check`'s what-changed delta reads, repo-relative. Set
# either to "" to degrade that report to a logged note (the verdict line is
# unaffected — it never depends on a document).
NOTES_DOC_PATH="${NOTES_DOC_PATH:-RELEASE_NOTES.md}"
CHANGELOG_DOC_PATH="${CHANGELOG_DOC_PATH:-CHANGELOG.md}"

# Where the vendored artifact lives inside the consumer.
VENDOR_DIR="${VENDOR_DIR:-./vendor}"

# The consumer-only distribution branch (the fast path). Set VENDORED_NO_DIST=1
# to skip it; set VENDORED_DIST_BRANCH to rename it.
VENDORED_NO_DIST="${VENDORED_NO_DIST:-0}"
DIST_BRANCH="${VENDORED_DIST_BRANCH:-dist}"

# Print the what-changed delta in --check mode (1) or skip it (0). Off is for
# automated nags that run on every `git pull`: it keeps the check to a single
# `git ls-remote` with no clone.
VENDORED_CHECK_NOTES="${VENDORED_CHECK_NOTES:-1}"

# ═════════════════════════════════════════════════════════════════════════════
# SEAM FUNCTIONS — three, and they are the only language-aware code here.
# ═════════════════════════════════════════════════════════════════════════════

log()  { printf '%s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# 1. BUILD. Produce exactly one artifact into $1 from the checked-out source in
#    $2. Everything it prints MUST go to stderr — this script's STDOUT is
#    reserved for the pin line (setup-consumer.sh captures it verbatim) and for
#    --check's single verdict line, and most build tools are chatty on stdout.
#    Build in an ISOLATED environment: never install build tooling into the
#    consumer's own environment.
build_artifact() {   # <output dir> <source dir>
    local outdir="$1" src="$2"
    # ┌ a worked example from the donor project (anonymized) ────────────────┐
    # │ The donor shipped one installable package per release, and its build │
    # │ was four lines with this SHAPE — the shape is what travels, not the  │
    # │ tool:                                                               │
    # │                                                                     │
    # │   BUILD_ENV="$WORK/buildenv"                    # scratch, in $WORK  │
    # │   <create an isolated build environment there>            >&2        │
    # │   <install the build tooling INTO that environment>       >&2        │
    # │   ( cd "$src" && <build, writing into "$outdir"> )        >&2        │
    # │                                                                     │
    # │ Four properties, each load-bearing: the environment is a SCRATCH one │
    # │ under $WORK (never the consumer's own — a refresh must not mutate    │
    # │ the environment it is refreshing); the build runs inside the         │
    # │ CHECKED-OUT TAG; output lands in $outdir; and every line of chatter  │
    # │ is redirected to stderr, because this script's stdout is the pin     │
    # │ line and nothing else. A project that compiles substitutes one       │
    # │ `make`-style invocation; one that ships an archive, one archiving    │
    # │ command.                                                            │
    # └─────────────────────────────────────────────────────────────────────┘
    die "build_artifact() is unfilled — put your project's build command here
    (source: $src, must produce exactly one artifact into: $outdir)."
}

# 2. VERSION FROM AN ARTIFACT FILENAME. Empty when it cannot be read.
#    The default reads the first digits-and-dots run after `<name>-`, which
#    covers `<name>-1.2.3-<anything>.<ext>` and `<name>-1.2.3.<ext>`. A project
#    whose versions are not digits-and-dots replaces THIS FUNCTION ONLY — and
#    then also replaces ver_gt() below, which compares with `sort -V`.
artifact_version() {   # <path or filename>
    local base="${1##*/}" v
    base="${base#${VENDORED_NAME}-}"
    v="$(printf '%s' "$base" | sed -n 's/^\([0-9][0-9.]*\).*$/\1/p')"
    printf '%s\n' "${v%.}"
}

# 3. THE PIN LINE + THE INSTALL HINT. The pin line is this script's ONLY stdout
#    in build mode; it is what the consumer records in its dependency manifest.
pin_line() {   # <vendored artifact path, consumer-relative>
    # ┌ a worked example from the donor project (anonymized) ────────────────┐
    # │ The donor's consumers pinned a LOCAL-FILE requirement in a plain     │
    # │ requirements manifest — one line, `<name> @ file:<path>` — so a      │
    # │ fresh clone rebuilt its environment from the vendored file with no   │
    # │ upstream remote in the loop. Substitute your own mechanism: a lock-  │
    # │ file entry, a vendored-path dependency, a checked-in submodule ref.  │
    # └─────────────────────────────────────────────────────────────────────┘
    printf '%s\n' "<your dependency pinning mechanism>: ${VENDORED_NAME} <- $1"
}

install_hint() {   # <vendored artifact path> <first-install|refresh>
    # THE DISTINCTION IS DELIBERATE, and it is a learning, not a style choice:
    # a REFRESH may skip dependency re-resolution (the environment already has
    # the transitive dependencies; only the artifact moved), while a
    # FIRST INSTALL must NOT — skipping resolution there leaves the
    # dependencies uninstalled and the failure surfaces much later, somewhere
    # unrelated. Two hints, two flags, on purpose.
    case "$2" in
        first-install) log "    <install command for $1 — RESOLVE dependencies>" ;;
        *)             log "    <install command for $1 — artifact only, skip dependency re-resolution>" ;;
    esac
}

# ═════════════════════════════════════════════════════════════════════════════
# Below this line: the logic. It travels unedited.
# ═════════════════════════════════════════════════════════════════════════════

# ---- -h/--help: usage, before anything can refuse --------------------------
# This script shipped without a help handler, and `--help` therefore fell all
# the way through to TAG RESOLUTION — including a network clone — and died with
# "tag not found: --help" (measured by an adopter 2026-08-22, the day the
# consumer seam was first filled; the self-test case that asserts "--help exits
# 0" had been a declared SKIP at assembly, so nothing caught it). A help flag is
# the FIRST thing a new consumer types, and it must answer on a repo where the
# seams are still placeholders — so this arm sits above the seam preflight, above
# the `git` probe, and touches neither the seams nor the network.
#
# The text is DERIVED from this file's own header, never retyped: the header IS
# the documentation, and a second copy of it is the copy that goes stale. Same
# block as move-issue.sh / archive.sh / finish-pr.sh / subtask.sh — line 3 to the
# last comment line before the first non-comment line, computed rather than
# hard-coded, so adding a paragraph to the header cannot leave a stale range
# behind. `${BASH_SOURCE[0]:-$0}` because this file is a TEMPLATE that consumers
# copy into their own repository and invoke in ways this kit does not control;
# the bare form resolves to nothing in any shell that is not bash.
usage() {
    local src="${BASH_SOURCE[0]:-$0}" first end
    first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$src")"
    end=$(( ${first:-0} - 1 )); [ "$end" -lt 3 ] && end=3
    sed -n "3,${end}p" "$src" | sed 's|^# \{0,1\}||'
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

# ---- --print-seams: the seam block, machine-readable -----------------------
# So a sibling script (setup-consumer.sh) can learn the artifact glob and the
# vendor directory from THIS FILE instead of keeping a second copy of them —
# a second copy is the one that goes stale. It runs BEFORE the preflight below
# on purpose: printing "the seams are still placeholders" is the answer a
# half-configured template should give.
if [ "${1:-}" = "--print-seams" ]; then
    # Single-quoted values so a caller can `eval` the block safely; no seam
    # value may itself contain a single quote.
    printf "VENDORED_NAME='%s'\n"     "$VENDORED_NAME"
    printf "ARTIFACT_GLOB='%s'\n"     "$ARTIFACT_GLOB"
    printf "VENDOR_DIR='%s'\n"        "$VENDOR_DIR"
    printf "UPSTREAM_REPO_URL='%s'\n" "$UPSTREAM_REPO_URL"
    printf "DIST_BRANCH='%s'\n"       "$DIST_BRANCH"
    exit 0
fi

command -v git >/dev/null 2>&1 || die "git not found."

# Preflight: refuse to run half-configured. An unfilled seam otherwise fails
# somewhere far from its cause (a glob that matches nothing, a clone of a
# literal placeholder), and the message you get would not name the real problem.
for seam in "VENDORED_NAME=$VENDORED_NAME" "UPSTREAM_REPO_URL=$UPSTREAM_REPO_URL" \
            "ARTIFACT_GLOB=$ARTIFACT_GLOB"; do
    case "$seam" in
        *"<"*) die "unfilled seam in $(basename "$0"): ${seam%%=*} is still a placeholder ($seam). Fill the SEAMS block at the top of this file." ;;
    esac
done

# ---- helpers ---------------------------------------------------------------

# Version of the artifact currently vendored, or empty if none is.
# MORE THAN ONE ARTIFACT IS A REFUSAL, NEVER A GUESS. ./vendor/ is long-lived,
# so a stale artifact CAN sit beside the current one, and answering by sort
# order (`ls | head -1`) means a healthy checkout can report UPDATE AVAILABLE
# with a DOWNGRADE as its remedy — the exact incident this refusal comes from.
# Which artifact is current is a question only a human can answer.
# (Contrast the this-run-created directories elsewhere in this script — the
# build output dir, the distribution-branch clone — where `head -1` stays
# CORRECT: a directory this run just made cannot hold a stale artifact.)
vendored_version() {
    local arts count base
    arts=$(ls "$VENDOR_DIR"/$ARTIFACT_GLOB 2>/dev/null || true)
    count=$(printf '%s\n' "$arts" | grep -c '.' || true)
    if [ "$count" -eq 0 ]; then
        echo ""
        return
    fi
    if [ "$count" -gt 1 ]; then
        printf '%s\n' "$arts" | sed 's/^/    /' >&2
        die "$count ${VENDORED_NAME} artifacts in ${VENDOR_DIR}/ — refusing to guess which is current. Remove the stale one(s), keeping only the artifact this consumer's dependency manifest pins."
    fi
    base="${arts##*/}"
    artifact_version "$base"
}

# Newest RELEASE tag on the remote (semver-sorted), without cloning. Empty if
# none. The trailing `|| true` keeps a failed ls-remote (unreachable host, no
# tags) from tripping `set -euo pipefail` in the caller's command substitution —
# an empty result is the intended "no tag" signal, handled by the caller.
# The RELEASE_TAG_RE filter is applied AFTER the sed, so a stray non-release tag
# (a process baseline tag, an experiment) can never sort to the top and be
# reported as "latest"; `--sort=-v:refname` ordering among release tags is kept.
remote_latest_tag() {
    git ls-remote --tags --refs --sort=-v:refname "$UPSTREAM_REPO_URL" 2>/dev/null \
        | sed -n 's#.*refs/tags/##p' | grep -E "$RELEASE_TAG_RE" | head -1 || true
}

tag_to_version() { echo "${1#$TAG_PREFIX}"; }

# ---- the what-changed delta (--check) --------------------------------------
# "A newer version exists" is only actionable with "and here is what changed",
# so --check reports the release-notes SECTION HEADERS for the versions between
# what you have vendored and the latest tag — plus, per header, the subsection
# titles that actually say something. Headers, never bodies: the point is a
# delta you can scan, and the full text lands in ./vendor/ the moment you
# update.
#
# The heading convention assumed here is the common changelog shape —
# `## [X.Y.Z] — <date>` for a release, `### <Title>` for its subsections. If
# your release documents are shaped differently, notes_headers() and
# notes_subsections() are the two functions to adapt.
#
# Is $1 a STRICTLY newer version than $2? `sort -V` so 1.9.0 < 1.10.0.
ver_gt() {
    [ "$1" != "$2" ] || return 1
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

# "VERSION|<the verbatim header line>" for every `## [X.Y.Z]` section of a
# release document. A missing file yields nothing and still succeeds.
notes_headers() {   # <release document>
    [ -f "$1" ] || return 0
    sed -n 's/^\(## \[\([0-9][0-9.]*\)\].*\)$/\2|\1/p' "$1"
}

# The `### Title` subsections of ONE version's section that actually say
# something. A subsection with nothing to report is conventionally written
# `None.`, and printing those would bury the ones that matter under a handful of
# fixed titles per release.
notes_subsections() {   # <release document> <version>
    awk -v ver="$2" '
        BEGIN { marker = "## [" ver "]" }
        substr($0, 1, length(marker)) == marker { inside = 1; next }
        /^## \[/ { if (inside) exit; next }
        inside && /^### / {
            if (title != "" && filled) print title
            title = substr($0, 5); filled = 0; next
        }
        inside {
            line = $0
            gsub(/^[ \t]+|[ \t]+$/, "", line)
            if (line != "" && line != "None." && title != "") filled = 1
        }
        END { if (inside && title != "" && filled) print title }
    ' "$1"
}

# Report what changed between the vendored version and the latest tag.
# STRICTLY REPORT-ONLY, and that is the whole contract of this function: the
# notes for the intervening versions exist nowhere in the consumer's tree yet,
# so they are read out of a THROWAWAY shallow clone that is deleted before this
# returns. Nothing under the consumer repo is written, ./vendor/ is not touched,
# and EVERY failure path (no temp dir, clone refused, a tag carrying no notes,
# an empty span) prints a note and returns SUCCESS — a report must never break
# the answer it decorates. Output goes to stderr with the rest of the
# narration, so --check's stdout stays exactly the one verdict line.
print_notes_delta() {   # <vendored version> <latest version> <latest tag>
    local from="$1" to="$2" tag="$3"
    local work clone notes changelog span v header

    if [ -z "$NOTES_DOC_PATH" ]; then
        log "NOTE: no release-notes document is configured (NOTES_DOC_PATH) — skipping the what-changed report."
        return 0
    fi

    work="$(mktemp -d)" || {
        log "NOTE: could not create a temp dir — skipping the what-changed report."
        return 0
    }
    clone="$work/notes"
    if ! git clone --quiet --depth 1 --branch "$tag" "$UPSTREAM_REPO_URL" "$clone" \
            >/dev/null 2>&1; then
        rm -rf "$work"
        log "NOTE: could not read ${tag}'s release notes — skipping the what-changed report."
        return 0
    fi
    notes="$clone/$NOTES_DOC_PATH"
    changelog=""
    [ -n "$CHANGELOG_DOC_PATH" ] && changelog="$clone/$CHANGELOG_DOC_PATH"

    if [ ! -f "$notes" ]; then
        rm -rf "$work"
        log "NOTE: $tag carries no ${NOTES_DOC_PATH}, so there is no what-changed report for" \
            "this span — read the changelog for those releases."
        return 0
    fi

    # Every version documented in EITHER document, narrowed to (from, to]. The
    # changelog is in the union on purpose: a version it documents and the notes
    # do not is an un-noted release, and saying so beats leaving a silent gap.
    span="$(
        { notes_headers "$notes"; [ -n "$changelog" ] && notes_headers "$changelog"; } \
            | cut -d'|' -f1 | sort -u \
            | while IFS= read -r v; do
                  if ver_gt "$v" "$from" && ! ver_gt "$v" "$to"; then printf '%s\n' "$v"; fi
              done | sort -rV
    )"

    if [ -z "$span" ]; then
        rm -rf "$work"
        log "NOTE: no release-notes sections are documented between ${from} and ${to}."
        return 0
    fi

    log ""
    log "What changed between ${from} and ${to}:"
    while IFS= read -r v; do
        [ -n "$v" ] || continue
        header="$(notes_headers "$notes" | grep "^${v}|" | head -1 | cut -d'|' -f2- || true)"
        if [ -z "$header" ]; then
            log "  NOTE: ${v} has no release-notes section — see" \
                "${VENDORED_NAME}-CHANGELOG.md for that release."
            continue
        fi
        log "  $header"
        notes_subsections "$notes" "$v" | while IFS= read -r sub; do
            [ -n "$sub" ] && log "    - $sub"
        done
    done <<SPAN
$span
SPAN
    log "  (full text: ${VENDOR_DIR}/${VENDORED_NAME}-RELEASE_NOTES.md, refreshed when you update)"
    log ""
    rm -rf "$work"
}

# ---- --check mode ----------------------------------------------------------
# ONE verdict line on stdout. Never writes. Never updates.

if [ "${1:-}" = "--check" ]; then
    log "Checking for a newer ${VENDORED_NAME} release (network)…"
    latest_tag=$(remote_latest_tag)
    [ -n "$latest_tag" ] || die "no release tags found at $UPSTREAM_REPO_URL"
    latest_ver=$(tag_to_version "$latest_tag")
    local_ver=$(vendored_version)

    if [ -z "$local_ver" ]; then
        log "vendored: (none)   latest: ${latest_ver} (${latest_tag})"
        echo "UPDATE AVAILABLE: no ${VENDORED_NAME} artifact vendored yet; latest is ${latest_ver}."
        exit 0
    fi

    log "vendored: ${local_ver}   latest: ${latest_ver} (${latest_tag})"
    if [ "$local_ver" = "$latest_ver" ]; then
        echo "UP TO DATE: vendored ${VENDORED_NAME} ${local_ver} matches the latest tag."
        exit 0
    fi
    # Is the latest strictly newer than what's vendored?
    newest=$(printf '%s\n%s\n' "$local_ver" "$latest_ver" | sort -V | tail -1)
    if [ "$newest" = "$latest_ver" ]; then
        echo "UPDATE AVAILABLE: vendored ${local_ver} < latest ${latest_ver}. Run this script (no --check) to update."
        # WHICH PATH an update would take, so the integrator knows whether it
        # costs a build. One lightweight ls-remote for the branch head — NO
        # clone, and like everything else in --check it writes nothing. It is
        # narration, so stderr: stdout stays the one verdict line a nag greps.
        if git ls-remote --heads "$UPSTREAM_REPO_URL" "$DIST_BRANCH" 2>/dev/null | grep -q .; then
            log "An update would use the ${DIST_BRANCH} fast path (shallow clone, no build) if it carries ${latest_ver}."
        else
            log "An update would build from tag ${latest_tag} (no ${DIST_BRANCH} branch on the remote)."
        fi
        # …and what actually changed, so the answer is actionable. Report-only,
        # and skipped entirely (no clone) when VENDORED_CHECK_NOTES=0.
        if [ "$VENDORED_CHECK_NOTES" != "0" ]; then
            print_notes_delta "$local_ver" "$latest_ver" "$latest_tag"
        fi
    else
        echo "AHEAD: vendored ${local_ver} is newer than the latest tag ${latest_ver} (pinned to an unreleased build?)."
    fi
    exit 0
fi

# ---- build + vendor mode ---------------------------------------------------

TAG="${1:-}"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Drop one release document beside the artifact, from the checked-out source.
# A source tree that predates a document just skips its drop with its own
# logged note — an older tag genuinely carries no such file, so that skip is a
# normal case, not an error.
drop_release_docs() {   # <source dir> <"tag"|"dist">
    local src="$1" mode="$2" entry path label from to
    for entry in "${RELEASE_DOCS[@]}"; do
        path="${entry%%|*}"
        label="${entry##*|}"
        to="$VENDOR_DIR/${VENDORED_NAME}-${label}.md"
        if [ "$mode" = "dist" ]; then
            # On the distribution branch the documents already carry their
            # consumer-facing names; there is no source layout to know.
            from="$src/${VENDORED_NAME}-${label}.md"
        else
            from="$src/$path"
        fi
        if [ -f "$from" ]; then
            cp "$from" "$to"
            log "Refreshed ${label}: $to"
        else
            log "NOTE: this release carries no ${from#$src/} — skipping the ${label} drop."
        fi
    done
}

# Vendor the artifacts sitting in <dir>: the artifact (exactly one is pinned)
# plus whichever release documents are present. Shared by both paths so the
# result cannot differ between them.
vendor_from_dir() {  # <dir> <"tag"|"dist"> -> echoes the artifact filename
    local src="$1" mode="$2" arts art name
    arts=$(ls "$src"/$ARTIFACT_GLOB 2>/dev/null || true)
    [ -n "$arts" ] || return 1
    # `head -1` is CORRECT here and only here: $src was created by THIS run
    # (a build output dir or a fresh shallow clone) and cannot hold a stale
    # artifact. The long-lived ./vendor/ gets the refusal instead — see
    # vendored_version().
    art=$(printf '%s\n' "$arts" | head -1)
    name="${art##*/}"
    mkdir -p "$VENDOR_DIR"
    # Remove older vendored artifacts so EXACTLY ONE is pinned.
    rm -f "$VENDOR_DIR"/$ARTIFACT_GLOB
    cp "$art" "$VENDOR_DIR/$name"
    drop_release_docs "$src" "$mode"
    echo "$name"
}

# ---- the distribution-branch FAST PATH (tried first, falls back silently) ---
# The upstream publishes a consumer-only branch at every release: ONE commit
# carrying just the artifact, the release documents and a short README. When it
# is there and current, a shallow clone of it gets us the same files this script
# would otherwise spend a full clone plus a build to produce — no build
# toolchain, no history, no source.
#
# It is a FAST PATH, never a requirement. The branch is absent on any repo state
# older than its introduction and can lag a tag if a publish failed, so every
# failure here falls through to the build-from-tag path below, which remains the
# AUTHORITATIVE way to reproduce any version. A log line always says which path
# ran, so an integrator is never guessing — but ./vendor/ ends up identical
# either way, which is why the fallback is invisible in the result.
try_dist_fast_path() {  # <requested tag or ""> <latest tag or "">
    local want_tag="$1" latest_tag="$2" clone dist_art dist_ver want_ver
    [ "$VENDORED_NO_DIST" = "1" ] && { log "Skipping the $DIST_BRANCH fast path (VENDORED_NO_DIST=1)."; return 1; }

    clone="$WORK/$DIST_BRANCH"
    if ! git clone --quiet --depth 1 --branch "$DIST_BRANCH" "$UPSTREAM_REPO_URL" "$clone" \
            >/dev/null 2>&1; then
        log "No $DIST_BRANCH branch on the remote — using the build-from-tag path."
        return 1
    fi
    dist_art=$(ls "$clone"/$ARTIFACT_GLOB 2>/dev/null | head -1 || true)
    [ -n "$dist_art" ] || { log "The $DIST_BRANCH branch carries no artifact — using the build-from-tag path."; return 1; }
    dist_ver="$(artifact_version "$dist_art")"

    # It has to be the version being ASKED for. An explicit tag must match
    # exactly; with no tag the request is "the latest", so a distribution branch
    # older than the newest tag is STALE and we build instead.
    want_ver="$(tag_to_version "${want_tag:-$latest_tag}")"
    if [ -n "$want_ver" ] && [ "$dist_ver" != "$want_ver" ]; then
        log "The $DIST_BRANCH branch carries ${dist_ver}, not ${want_ver} — using the build-from-tag path."
        return 1
    fi

    vendor_from_dir "$clone" dist || { log "Could not vendor from $DIST_BRANCH — using the build-from-tag path."; return 1; }
    return 0
}

# The fast path needs to know what "latest" is when no tag was named. One
# lightweight ls-remote, the same call --check uses; empty is handled.
DIST_LATEST_TAG=""
if [ -z "$TAG" ]; then DIST_LATEST_TAG="$(remote_latest_tag)"; fi

if FAST_ARTIFACT="$(try_dist_fast_path "$TAG" "$DIST_LATEST_TAG")" && [ -n "$FAST_ARTIFACT" ]; then
    log ""
    log "Vendored: $VENDOR_DIR/$FAST_ARTIFACT  (via the $DIST_BRANCH fast path — no build)"
    log "Pin this in the consumer's dependency manifest:"
    log ""
    pin_line "$VENDOR_DIR/$FAST_ARTIFACT"
    log ""
    log "Then reinstall into the consumer's environment (a REFRESH — artifact only):"
    install_hint "$VENDOR_DIR/$FAST_ARTIFACT" refresh
    exit 0
fi

# ---- the build-from-tag path (authoritative) -------------------------------

CLONE="$WORK/repo"
log "Cloning the ${VENDORED_NAME} upstream repo (network)…"
git clone --quiet "$UPSTREAM_REPO_URL" "$CLONE" || die "clone failed: $UPSTREAM_REPO_URL"

if [ -z "$TAG" ]; then
    # `|| true` binds to the whole pipeline (|| is looser than |), so a failed
    # `git tag` cannot trip `set -euo pipefail` before the `|| die` below
    # reports it. Same RELEASE_TAG_RE filter as remote_latest_tag(), so a stray
    # non-release tag is never auto-picked as the latest to build and vendor.
    TAG=$(git -C "$CLONE" tag --sort=-v:refname | grep -E "$RELEASE_TAG_RE" | head -1 || true)
    [ -n "$TAG" ] || die "no release tags in $UPSTREAM_REPO_URL — cannot pick a latest."
    log "Latest tag: $TAG"
fi
git -C "$CLONE" checkout --quiet "refs/tags/$TAG" 2>/dev/null \
    || git -C "$CLONE" checkout --quiet "$TAG" \
    || die "tag not found: $TAG"

# The release documents are dropped from the CHECKED-OUT TAG's own tree, BEFORE
# the build and independently of it: deterministic, the same bytes that tag's
# artifact carries, and a tag predating a document simply skips it. Without this
# drop a vendoring consumer's entire view of the upstream is the artifact, so
# "what changed under me since I last re-vendored?" has no in-band answer.
mkdir -p "$VENDOR_DIR"
drop_release_docs "$CLONE" tag

log "Building the artifact…"
build_artifact "$WORK/dist" "$CLONE"

# CAPTURE, THEN TEST, THEN SELECT. Written as one line —
# `ART=$(ls … | head -1)` — the no-match case fails the ASSIGNMENT under
# `set -euo pipefail`, so the `die` below becomes unreachable dead code and the
# failure it exists to explain dies bare. Capture with `|| true`, test, then
# select. `head -1` itself stays CORRECT here: the build output dir was created
# by this run and cannot hold a stale artifact (unlike the long-lived
# ./vendor/, whose multi-artifact case vendored_version() refuses).
ARTIFACTS=$(ls "$WORK"/dist/$ARTIFACT_GLOB 2>/dev/null || true)
[ -n "$ARTIFACTS" ] || die "the build produced no ${VENDORED_NAME} artifact matching $ARTIFACT_GLOB."
ARTIFACT=$(printf '%s\n' "$ARTIFACTS" | head -1)
ARTIFACT_NAME="${ARTIFACT##*/}"

# Remove older vendored artifacts so EXACTLY ONE is pinned.
rm -f "$VENDOR_DIR"/$ARTIFACT_GLOB
cp "$ARTIFACT" "$VENDOR_DIR/$ARTIFACT_NAME"

log ""
log "Vendored: $VENDOR_DIR/$ARTIFACT_NAME  (built from tag $TAG)"
log "Pin this in the consumer's dependency manifest:"
log ""
pin_line "$VENDOR_DIR/$ARTIFACT_NAME"
log ""
log "Then reinstall into the consumer's environment (a REFRESH — artifact only):"
install_hint "$VENDOR_DIR/$ARTIFACT_NAME" refresh
