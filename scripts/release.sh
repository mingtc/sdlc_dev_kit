#!/usr/bin/env bash
# KIT-CLASS: MIXED — kit SHAPE (preflight → bump seam → annotated tag → push → optional publish); PROJECT version files, build command and policy (the config block below, shipped EMPTY). See process/EXTRACTION.md.
# scripts/release.sh — cut a release: preflight gates → version bump → annotated tag → push.
#
# A release is cut DELIBERATELY, LOCALLY, and with pure git — forge-agnostic, no
# forge CLI, no CI auto-tagging. Each tag `vX.Y.Z` is what a consumer pins.
#
#   ./scripts/release.sh 1.1.0             # bump to 1.1.0, tag v1.1.0
#   ./scripts/release.sh v1.1.0            # a leading "v" is accepted (same result)
#   ./scripts/release.sh 1.1.0 --dry-run   # run every preflight gate, then STOP (mutate nothing)
#   ./scripts/release.sh 1.1.0 --publish-only            # re-publish the dist branch for an ALREADY-CUT tag
#   ./scripts/release.sh 1.1.0 --publish-only --dry-run  # report that republish, push NOTHING
#   ./scripts/release.sh 1.1.0 --no-fetch  # DECLARE an offline cut: the remote is NOT consulted
#
# WHAT IT DOES, in order (it ABORTS NONZERO on the first failure, BEFORE mutating
# anything — a red preflight leaves the repo byte-for-byte untouched):
#
#   PREFLIGHT (read-only)
#     0. the target parses as X.Y.Z semver                     (else refuse)
#     1. the tag vX.Y.Z does not already exist                 (idempotency guard)
#     2. on the trunk, CLEAN, and AT $REMOTE/<trunk>'s TIP     (gate a)
#     3. ./scripts/verify.sh is green                          (gate b)
#     4. every gate declared in PREFLIGHT_GATES passes         (gate c; project-declared)
#     5. ./scripts/check-board.sh reports a clean board        (gate d)
#     6. EVERY document in RELEASE_DOCS has a "## [X.Y.Z]" section  (gate e)
#        — one INDEPENDENT arm per document, each with its OWN refusal naming its
#          own file and what to write. A shared message leaves the author guessing
#          which file is missing a section; fail-fast, first-declared first.
#     7. no declared document's section HEADER DATE is older than the newest date
#        written inside that section                           (gate f)
#
#   THE SECTION DATE IS THE CUTTER'S — set it, here, at the cut. An un-cut section
#   carries a PLACEHOLDER date with no authority, and no issue landing into one may
#   edit it; the cutter writes the day the tag is actually taken. Gate f is what
#   enforces that: it refuses a header date earlier than something the section says
#   happened, naming both dates and the file. If it refuses, correct the HEADER —
#   never the measurement inside the body. (This gate exists because a real release
#   section sat, for a whole arc, dated a day BEFORE the work it contained: a header
#   promise is only as good as whoever re-reads it.)
#
#   MUTATE (only once every gate above is green)
#     8. bump the version in every file declared in VERSION_FILES
#     9. one role-prefixed release commit, then an ANNOTATED tag vX.Y.Z — and then,
#        as NORMAL output while the run is healthy, the LOCAL-ONLY state and the
#        exact commands that finish the job. A run killed between step 9 and step
#        10 otherwise leaves a transcript asserting a commit and a tag with nothing
#        saying neither was ever pushed (`doctrine/fix-execution.md` § A.7).
#    10. push the commit + the tag to the remote
#    11. optionally PUBLISH the distribution branch (RELEASE_PUBLISH=true) — only
#        after BOTH pushes above succeed, so a publish failure can never make a
#        completed release look failed. A failure there prints that the RELEASE
#        SUCCEEDED, never rolls back the tag, and names `--publish-only` as the retry.
#
# TEST SEAMS (used by scripts/test/run.sh's sandbox cases; leave unset in real use):
#   RELEASE_TEST_ALLOW_STUB=1  THE MARKER THE TWO GATE-STUBBING SEAMS BELOW REQUIRE.
#                        Set by scripts/test/run.sh and by nothing else. Without it,
#                        supplying either command below is REFUSED before any gate runs.
#   RELEASE_VERIFY_CMD   overrides gate b's command (default: scripts/verify.sh)
#                        — requires RELEASE_TEST_ALLOW_STUB=1
#   RELEASE_BOARD_CMD    overrides gate d's command (default: scripts/check-board.sh)
#                        — requires RELEASE_TEST_ALLOW_STUB=1
#   RELEASE_BUILD_CMD    overrides the publish build command (see BUILD_COMMAND)
#   RELEASE_DIST_BRANCH  overrides the distribution branch name
#   KWT_REMOTE           the SHARED publication remote for every kit operation,
#                        this one included      (default: origin; a remote NAME)
#   RELEASE_REMOTE       overrides KWT_REMOTE for the release push ONLY
#                        (default: whatever KWT_REMOTE is; may be a URL)
#   RELEASE_ROLE         commit role tag            (default: Architect)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ═════════════════════════════════════════════════════════════════════════════
# CONFIG BLOCK — everything a project declares lives between here and the END
# marker. Nothing below the marker needs editing to adopt this script.
# ═════════════════════════════════════════════════════════════════════════════

# ── THE VERSION-BUMP SEAM ────────────────────────────────────────────────────
# One record per file that carries the version: "<path>|<line-prefix>|<quote>".
#   <path>        repo-relative.
#   <line-prefix> the literal text that begins the line, up to the version itself.
#                 It is used inside a sed `s|^…|` expression, so a prefix
#                 containing `|` or regex metacharacters must be escaped by you.
#   <quote>       the character the version is wrapped in — `"`, `'`, or EMPTY for
#                 a bare value (a plain VERSION file).
#
# EVERY declared file is bumped, and EVERY bump is VERIFIED by reading the file
# back before anything is committed. A format drift in one file would otherwise
# ship a HALF-BUMPED release; on a failed read-back the script restores every file
# it touched and aborts with no commit.
#
# SHIPPED EMPTY. With no records the script REFUSES: a release that tags a commit
# whose declared version nobody moved is a silent lie, and this frame will not
# pretend otherwise. If your project genuinely carries its version only in the tag,
# say so explicitly with VERSION_IN_TAG_ONLY=true below.
VERSION_FILES=(
  # A WORKED EXAMPLE, from an anonymized donor project (a library whose build
  # config and package entry point each state the version):
  #   "<build-config-file>|version = |\""
  #   "<src>/<package>/<entrypoint>|__version__ = |\""
)
# Set true ONLY if the tag is genuinely the single source of version truth.
VERSION_IN_TAG_ONLY=false

# ── EXTRA PREFLIGHT GATES (gate c) ───────────────────────────────────────────
# One record per project-specific gate: "<name>|<command…>". They run after
# verify.sh and before the board check, in declared order, read-only, and each
# aborts the cut on a non-zero exit.
#
# A WORKED EXAMPLE, from an anonymized donor project: a LIVE read-canary against
# a disposable scratch document, because that project's whole product was a client
# for a remote API and a green offline suite could not prove the API still
# answered. It carried one honest caveat worth copying: the canary SKIPS LOUDLY
# when its credentials are unset, so the script printed a warning when it was
# about to run a canary that could not actually reach anything — a gate that can
# silently no-op must SAY when it is about to.
#
# THE EXAMPLE IS A WRAPPER SCRIPT, AND IT HAS TO BE. Gate (c) below runs your record
# with a DELIBERATE WORD-SPLIT and no `eval`, so a record is a command and its
# arguments — nothing else. An inline `sh -c 'test -n "$TOK" || …'` does not work
# here: the quoting is split apart into separate words before anything runs. Nor can
# a record contain `|`, which is the field separator. **A gate whose logic is more
# than "run this and read the status" is a script in your repository.**
#
# AND THE WRAPPER'S REAL JOB IS THE THIRD STATE. A gate has three outcomes, not two:
# passed, failed, and COULD NOT RUN. A bare command copied into a project without the
# canary's environment gives you the first or the second — a false green, or a hard
# failure that blocks a legitimate offline cut. The wrapper is where "the credential
# is unset, so this proved nothing" gets said out loud and exits 0.
PREFLIGHT_GATES=(
  #   "live read-canary|./scripts/canary-live.sh"
  #
  #   …where that script is, in full:
  #       if [ -z "${CANARY_TOKEN:-}" ]; then
  #         echo "SKIP: live read-canary — CANARY_TOKEN unset; the canary did not run."
  #         exit 0
  #       fi
  #       exec <your live check>
)

# ── THE RELEASE DOCUMENTS (gates e + f) ──────────────────────────────────────
# One record per document that must carry a "## [X.Y.Z]" section for this cut:
# "<path>|<what to write when it is missing>". The second field becomes part of
# that document's OWN refusal message, so make it an instruction, not a label.
#
# A WORKED EXAMPLE, from an anonymized donor project — two documents, on purpose:
#   "CHANGELOG.md|the internal engineering log: issue ids, refactor passes, test-count movements"
#   "RELEASE_NOTES.md|the consumer-facing, filtered notes (four fixed subsections; the relevance filter is stated in that file's own header)"
# Why two arms and not one: the consumer-facing file was added second, and without
# a gate arm of its own it existed and silently stopped being maintained by the
# second release.
RELEASE_DOCS=(
)

# ── THE DISTRIBUTION BRANCH (step 11) — OFF by default. ──────────────────────
# A consumer-only endpoint: the forge-agnostic equivalent of a releases page. It
# carries ONLY the current release's artifact, whatever documents you list, and a
# generated README, so getting the project is
#
#     git clone --branch <dist> --depth 1 <url>
#
# instead of cloning the dev repo and building it. No source, no tests, no process
# docs, no scripts — the allowlist is the point.
#
# HISTORY POLICY: REPLACE. The orphan is rebuilt from nothing and force-pushed, so
# the branch is always ONE commit. It is a distribution endpoint, not an archive —
# the archive is the annotated tags plus your changelog on the trunk. Binaries
# would grow the pack forever for a branch whose documented use is `--depth 1`
# (which buys the consumer no history anyway), and a force-push is invisible to
# that command. THE TRADEOFF, PLAINLY: anyone who made a FULL clone of the dist
# branch needs --force on their next pull. The documented consumer command is a
# fresh shallow clone.
RELEASE_PUBLISH=false
# The build command. It is handed an OUTPUT DIRECTORY as its LAST argument and is
# run with the TAG's tree as its working directory — never the working copy, so
# the distributed artifact is the one the tag reproduces. That is the entire basis
# for "the tag is authoritative".
BUILD_COMMAND="${RELEASE_BUILD_CMD:-}"
# A glob, relative to the output directory, selecting the artifact to publish.
DIST_ARTIFACT_GLOB=""
# Documents copied out of the TAG's own tree, so they describe the artifact beside
# them: "<path-in-tag>|<name-on-the-dist-branch>". A tag predating one simply
# ships without it.
DIST_DOCS=(
)
DIST_BRANCH="${RELEASE_DIST_BRANCH:-dist}"

# ═════════════════════════════════════════════════════════════════════════════
# END CONFIG BLOCK — the frame follows. Take it as-is.
# ═════════════════════════════════════════════════════════════════════════════

# THIS SCRIPT DOES NOT USE scripts/lib/usage.sh, ON PURPOSE — two reasons, both ruled.
# (1) A DIFFERENT WINDOW RULE: that library prints the header to its last COMMENT line;
#     this prints to the last USAGE EXAMPLE, because the header below carries operator
#     notes that are not help text. Measured: on the library's rule this --help goes
#     from 11 lines to 63, including a TEST SEAMS block. (2) This script sources
#     NOTHING from scripts/lib/ by design. A sweep that unifies "all the header
#     renderers" must skip this one; that is what this paragraph is for.
# --help renders the header's SYNOPSIS: the description plus every usage example.
# The window is DERIVED, not a literal: a hard-coded `2,9p` once showed none of the
# examples because they sat below it — and hard-coding a bigger number is the same
# defect, silently dropping the next example somebody adds. So: find the header
# block (everything above the first non-comment line), take the LAST usage example
# inside it, and end the window there.
#
# THE SOURCE PATH IS RESOLVED ABSOLUTELY. This script `cd`s to the repo root
# before anything else, so a relative `${BASH_SOURCE[0]}` (`./release.sh` when
# invoked from scripts/) no longer resolves and --help printed a grep error
# instead of the synopsis.
RELEASE_SRC="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
usage() {
  local src="$RELEASE_SRC" header_end window_end
  header_end=$(( $(grep -n -m1 -v '^#' "$src" | cut -d: -f1) - 1 ))
  window_end="$(sed -n "1,${header_end}p" "$src" \
    | grep -n '^#[[:space:]]\{1,\}\./scripts/release\.sh[[:space:]]' \
    | tail -1 | cut -d: -f1)"
  sed -n "3,${window_end:-9}p" "$src" | sed 's|^# \{0,1\}||'
}

# ── Arg parse ────────────────────────────────────────────────────────────────
RAW_VERSION=""; DRY_RUN=false; PUBLISH_ONLY=false; NO_FETCH=false
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --publish-only) PUBLISH_ONLY=true; shift ;;
    --no-fetch) NO_FETCH=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --apply) { echo "release.sh: there is no --apply — this script MUTATES by default, which is the"
               echo "            opposite of the archive sweeps. Use --dry-run to run every gate and STOP."
               echo "            NOTHING WAS WRITTEN."; } >&2
             exit 2 ;;
    -*) echo "release.sh: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    *) if [ -z "$RAW_VERSION" ]; then RAW_VERSION="$1"; shift
       else echo "release.sh: unexpected extra arg '$1'" >&2; exit 2; fi ;;
  esac
done

if [ -z "$RAW_VERSION" ]; then
  echo "release.sh: a target version is required (e.g. '1.1.0' or 'v1.1.0')." >&2
  usage >&2; exit 2
fi

# THE PUBLICATION REMOTE HAS ONE SHARED NAME AND ONE NARROW OVERRIDE. `KWT_REMOTE` is
# the name every other operation honours — the board mover, the archive sweep, the
# subtask mover, the PR landing, the drift report and the initializer, six of them — and
# it is documented as the fork recipe. `RELEASE_REMOTE` was read only here, so a fork
# that set KWT_REMOTE=upstream published its board there and its RELEASES to origin,
# silently. The chain fixes that WITHOUT retiring either name, so nobody's setting is
# quietly ignored: narrow beats shared, shared beats the git-universal default.
#
# ONLY THE OVERRIDE MAY BE A URL. This script resolves the dist remote through
# `git remote get-url … || echo "$REMOTE"`, so a URL works here. KWT_REMOTE is used as a
# remote NAME by the worktree machinery (refs/remotes/$KWT_REMOTE/HEAD), where a URL
# silently fails trunk resolution and falls through to the last-resort guess. So: put a
# URL in RELEASE_REMOTE if you must; never in KWT_REMOTE.
REMOTE="${RELEASE_REMOTE:-${KWT_REMOTE:-origin}}"
ROLE="${RELEASE_ROLE:-Architect}"

# ── Preflight -1 (gate 0): A TEST-ONLY RELAXATION NEEDS ITS TEST-ONLY MARKER. ─
# `self-test-harness.md` § 2: "a test-only relaxation of a production rule is
# reachable ONLY behind an explicit marker that no production caller sets."
#
# The two seams below override the two gates that decide whether this cut is allowed
# to happen at all — gate b (verify.sh green) and gate d (the board is truthful).
# Unmarked, `RELEASE_VERIFY_CMD=true ./scripts/release.sh 1.1.0` cuts a release with
# the verify gate silently skipped, which is not a weaker gate but NO gate.
#
# THE HOLE WAS LEARNED BY INCIDENT, ON THE SIBLING. `landing-gate.md` § 2 records a
# fabricated `echo PASS; exit 0` stub being pointed at through the equivalent seam to
# force a landing through a red suite — and finish-pr.sh grew this exact refusal in
# response. release.sh received the same stub seams, because the harness needs them,
# and never the marker: **the incident's fix was applied to one sibling and not the
# other.** That is the whole defect, and it is why this is the FIRST thing checked
# rather than a note beside the gates.
#
# Deliberately placed before Preflight 0, so an illegitimate invocation is refused
# before this script reads anything, resolves anything, or runs a gate.
if [ "${RELEASE_TEST_ALLOW_STUB:-}" != "1" ] \
   && { [ -n "${RELEASE_VERIFY_CMD:-}" ] || [ -n "${RELEASE_BOARD_CMD:-}" ]; }; then
  {
    echo "release.sh: refusing a caller-supplied gate command on the production release path."
    echo "       RELEASE_VERIFY_CMD / RELEASE_BOARD_CMD override the two gates that decide"
    echo "       whether this cut may happen — the verify gate and the board-truth gate — so"
    echo "       an unmarked override does not weaken a gate, it removes one."
    echo "       They are honored ONLY behind the test-only marker RELEASE_TEST_ALLOW_STUB=1,"
    echo "       which scripts/test/run.sh sets and no production caller ever sets."
    echo "       If a gate is genuinely wrong for this project, change what it RUNS"
    echo "       (verify.sh's GATES table, PREFLIGHT_GATES) rather than replacing the runner."
    echo "       NOTHING WAS WRITTEN."
  } >&2
  exit 1
fi

# ── Preflight 0: the target parses as X.Y.Z semver ───────────────────────────
NUM="${RAW_VERSION#v}"                     # strip an optional leading "v"
TAG="v$NUM"
if ! printf '%s' "$NUM" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "release.sh: '$RAW_VERSION' is not an X.Y.Z semver version — refusing." >&2
  exit 1
fi
NUM_RE="${NUM//./\\.}"                      # dot-escaped for grep -E

# ── Resolve the trunk. Same three-step chain as the kanban worktree, and the last
#    link is READ FROM that library rather than re-typed here.
DEFAULT_BRANCH="$(git symbolic-ref --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null | sed "s|^$REMOTE/||" || true)"
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="$(git config --get init.defaultBranch 2>/dev/null || true)"
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH="$(sed -n 's/^KWT_TRUNK_LAST_RESORT="\${KWT_TRUNK_LAST_RESORT:-\([^}]*\)}"/\1/p' \
                      "$SCRIPT_DIR/lib/kanban-worktree.sh" 2>/dev/null | head -1)"
  {
    echo "release.sh: the trunk is a GUESS ('$DEFAULT_BRANCH') — neither $REMOTE/HEAD nor"
    echo "            init.defaultBranch is set. Cutting a release against a guessed trunk is"
    echo "            not something this script will do quietly. Settle it first:"
    echo "              git remote set-head $REMOTE <your-trunk>"
  } >&2
fi
[ -n "$DEFAULT_BRANCH" ] || { echo "release.sh: could not resolve a trunk name at all — refusing." >&2; exit 1; }

# Push by URL rather than by remote NAME: the throwaway repo the publish step
# builds has no remotes of its own.
DIST_REMOTE_URL="$(git -C "$REPO_ROOT" remote get-url "$REMOTE" 2>/dev/null || echo "$REMOTE")"

# ── The publish step, as a function so both the normal path and --publish-only
#    call exactly the same code.
publish_dist() {
  local work tagtree distdir artifact rec src dst
  if [ "$RELEASE_PUBLISH" != "true" ]; then
    echo "release.sh: publishing is not enabled for this project (RELEASE_PUBLISH=false in the config block)." >&2
    return 1
  fi
  if [ -z "$BUILD_COMMAND" ] || [ -z "$DIST_ARTIFACT_GLOB" ]; then
    echo "release.sh: RELEASE_PUBLISH is true but BUILD_COMMAND / DIST_ARTIFACT_GLOB are not declared." >&2
    return 1
  fi
  work="$(mktemp -d)" || { echo "release.sh: could not create a temp dir for the publish step." >&2; return 1; }
  # shellcheck disable=SC2064
  trap "rm -rf '$work'; git -C '$REPO_ROOT' worktree prune >/dev/null 2>&1 || true" RETURN

  # Build AT THE TAG, never from the working tree. A detached worktree gets the
  # tag's tree without moving the operator's checkout.
  tagtree="$work/tag"
  git -C "$REPO_ROOT" worktree add --detach --quiet "$tagtree" "refs/tags/$TAG" \
    || { echo "release.sh: could not check out $TAG to build the distribution artifact." >&2; return 1; }

  # Braces are load-bearing: an unbraced `$TAG…` is read as a variable named
  # `TAG…`, which under `set -u` aborts the script — it did once, and it took
  # every release case down with it.
  echo "── publish: building at ${TAG}…"
  # shellcheck disable=SC2086  # deliberate word-split of the declared build command
  ( cd "$tagtree" && $BUILD_COMMAND "$work/out" ) >&2 \
    || { echo "release.sh: the build at $TAG failed." >&2; return 1; }
  # shellcheck disable=SC2086,SC2012
  artifact="$(ls "$work"/out/$DIST_ARTIFACT_GLOB 2>/dev/null | head -1 || true)"
  [ -n "$artifact" ] || { echo "release.sh: the build at $TAG produced nothing matching '$DIST_ARTIFACT_GLOB'." >&2; return 1; }

  distdir="$work/pub"
  mkdir -p "$distdir"
  cp "$artifact" "$distdir/"
  for rec in ${DIST_DOCS[@]+"${DIST_DOCS[@]}"}; do
    src="${rec%%|*}"; dst="${rec#*|}"
    [ -f "$tagtree/$src" ] && cp "$tagtree/$src" "$distdir/$dst"
  done

  cat > "$distdir/README.md" <<EOF
# $TAG — distribution branch

The current release's artifact and its documents. Nothing else lives here.

    $(basename "$artifact")

This branch is REPLACED on every release (one commit, force-pushed) — clone it
with \`--depth 1\`. Older artifacts come from the annotated tags, which are
authoritative.
EOF

  # A FRESH repo rather than `git checkout --orphan` in this one: it starts with no
  # history at all, which IS the orphan property, and it cannot touch the operator's
  # branches or reflog if any step here fails.
  git -C "$distdir" init --quiet
  git -C "$distdir" symbolic-ref HEAD "refs/heads/$DIST_BRANCH"
  git -C "$distdir" add -A
  git -C "$distdir" \
      -c user.name="$(git -C "$REPO_ROOT" config user.name 2>/dev/null || echo release)" \
      -c user.email="$(git -C "$REPO_ROOT" config user.email 2>/dev/null || echo release@localhost)" \
      -c core.hooksPath=/dev/null \
      commit --quiet -m "[$ROLE] dist: $TAG"

  echo "── publish: force-pushing $DIST_BRANCH (single commit, replaces the previous)…"
  git -C "$distdir" push --quiet --force "$DIST_REMOTE_URL" "HEAD:refs/heads/$DIST_BRANCH" \
    || return 1
  return 0
}

# ── --publish-only: re-run JUST the publish for an ALREADY-CUT tag. ──────────
# This is the recovery path the publish-failure message names, so it has to exist:
# a message telling the operator to run a flag the script does not have would be
# the dangling-pointer defect in its most expensive place. It runs no preflight and
# mutates no version file — it only rebuilds the distribution copy — and it
# REQUIRES the tag to already exist (the inverse of preflight 1 below).
if [ "$PUBLISH_ONLY" = "true" ]; then
  if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
    echo "release.sh: --publish-only needs tag $TAG to exist already; it does not. Cut the release first." >&2
    exit 1
  fi
  # Sitting above the gates means sitting above the DRY-RUN STOP POINT too, so this
  # path has to honour --dry-run ITSELF — it structurally cannot reach the one
  # below. Without this, `<version> --publish-only --dry-run` force-pushed the dist
  # branch; and since --publish-only takes a VERSION argument, that could silently
  # roll the branch BACK to an older release's artifact while reporting a rehearsal.
  # The tag check above still runs, so a rehearsal still tells the operator whether
  # the retry would even be legal.
  if [ "$DRY_RUN" = "true" ]; then
    echo "(dry run) would: rebuild at $TAG and force-push $DIST_BRANCH to"
    echo "          $DIST_REMOTE_URL (one commit, REPLACING the current one)."
    echo "(dry run — nothing was pushed.)"
    exit 0
  fi
  if publish_dist; then
    echo "✓ Republished $DIST_BRANCH from $TAG."
    exit 0
  fi
  echo "release.sh: re-publishing $DIST_BRANCH from $TAG FAILED. The release itself is unaffected." >&2
  exit 1
fi

# ── Preflight 1: the tag must not already exist (idempotency guard). ─────────
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "release.sh: tag $TAG already exists — refusing (a version is cut once)." >&2
  exit 1
fi

# ── The version-bump seam must be DECLARED before anything else runs. ────────
if [ "${#VERSION_FILES[@]}" -eq 0 ] && [ "$VERSION_IN_TAG_ONLY" != "true" ]; then
  {
    echo "release.sh: REFUSING — VERSION_FILES is empty and VERSION_IN_TAG_ONLY is not true."
    echo "  Declare the file(s) that carry your version in the config block at the top of"
    echo "  this script, or set VERSION_IN_TAG_ONLY=true if the tag is genuinely the only"
    echo "  place the version lives. Tagging a commit whose declared version nobody moved"
    echo "  is a silent lie, and this frame will not pretend otherwise."
  } >&2
  exit 1
fi

# ── Preflight 2 (gate a): on the trunk with a clean working tree. ────────────
CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
  echo "release.sh: must run on the trunk ('$DEFAULT_BRANCH'); you are on '${CURRENT_BRANCH:-<detached>}'." >&2
  exit 1
fi
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "release.sh: working tree is not clean — commit or stash first (a cut must be reproducible)." >&2
  git status --short >&2
  exit 1
fi

echo "── release.sh preflight for $TAG (trunk: $DEFAULT_BRANCH, remote: $REMOTE)"

# ── Preflight 2 (gate a), third check: HEAD IS THE PUBLISHED TRUNK'S TIP. ────
# The two checks above read only this machine. A checkout that is on the trunk and
# clean can still be BEHIND the remote, and the cut then names a tree missing what
# already landed. The damage does not arrive through the branch push — that is
# rejected as a non-fast-forward and this script exits before tagging. It arrives
# through THIS SCRIPT'S OWN printed recovery: an operator who makes the branch push
# work the obvious way (`git pull --rebase`) then runs the second half of that line
# and publishes an annotated tag on the PRE-REBASE commit, which is now on no branch.
# `contracts/release-ritual.md` § 2 has always said the point being named is the
# PUBLISHED trunk; this is the check that makes that sentence true.
#
# THE OPERAND IS FETCH_HEAD, NOT refs/remotes/$REMOTE/$DEFAULT_BRANCH. `git fetch
# <remote> <branch>` updates the tracking ref only OPPORTUNISTICALLY — when $REMOTE is
# a configured remote NAME with a standard refspec. RELEASE_REMOTE may be a URL (this
# script already contemplates that where it resolves the dist remote), and a fetch BY
# URL was measured returning 0 while leaving the tracking ref untouched — so a
# tracking-ref comparison passes a behind checkout, which is this defect wearing the
# fix's clothes. Every fetch writes FETCH_HEAD, including a no-op one. `@{upstream}`
# is wrong for a second reason: it may name a remote other than the one pushed to.
#
# THE EXIT STATUS DECIDES; the captured text is shown to the human and never parsed.
# A fetch whose failure is inferred from its output turns a loud transient into a
# silently stale ref, which is the same class of defect again.
if [ "$NO_FETCH" = "true" ]; then
  {
    echo "[a] --no-fetch: THE REMOTE WAS NOT CONSULTED. $TAG may name a tree missing whatever has"
    echo "    landed on $REMOTE/$DEFAULT_BRANCH since this checkout last fetched. This is a DECLARED"
    echo "    offline cut, and it is in this transcript so it is not deniable afterwards."
  } >&2
else
  echo "[a] HEAD is $REMOTE/$DEFAULT_BRANCH's tip (fetching)..."
  # No timeout: POSIX has none, and inventing one would be a second policy nobody asked
  # for. A hung remote hangs HERE, which is safe — release-ritual.md § 2 guarantees a red
  # preflight leaves the repository byte-for-byte untouched, so Ctrl-C costs nothing.
  if ! FETCH_ERR="$(git fetch "$REMOTE" "$DEFAULT_BRANCH" 2>&1 >/dev/null)"; then
    {
      echo "release.sh: could not fetch '$DEFAULT_BRANCH' from '$REMOTE' — refusing to cut $TAG."
      echo "            THIS IS A FACT ABOUT THIS MACHINE'S ACCESS TO THE REMOTE, NOT ABOUT YOUR TREE."
      echo "            It refuses rather than warns because a tag is the one act this ritual never"
      echo "            rolls back, and an arm that degrades quietly is worth nothing when it matters."
      echo "            git said:"
      printf '%s\n' "$FETCH_ERR" | sed 's/^/              /'
      echo "            Either fix the remote, or DECLARE the offline cut:"
      echo "              ./scripts/release.sh $NUM --no-fetch"
      echo "            NOTHING WAS WRITTEN."
    } >&2
    exit 1
  fi
  REMOTE_TIP="$(git rev-parse --verify --quiet FETCH_HEAD || true)"
  LOCAL_TIP="$(git rev-parse HEAD)"
  if [ -z "$REMOTE_TIP" ]; then
    {
      echo "release.sh: the fetch of '$DEFAULT_BRANCH' from '$REMOTE' succeeded but named no commit —"
      echo "            refusing to cut $TAG. Nothing was compared, so nothing is known."
      echo "            NOTHING WAS WRITTEN."
    } >&2
    exit 1
  fi
  if [ "$LOCAL_TIP" != "$REMOTE_TIP" ]; then
    {
      echo "release.sh: HEAD is not $REMOTE/$DEFAULT_BRANCH's tip — refusing to cut $TAG."
      echo "              HEAD                     $LOCAL_TIP"
      echo "              $REMOTE/$DEFAULT_BRANCH  $REMOTE_TIP"
      # THE REMEDY BRANCHES, and it must: `git pull --ff-only` is a NO-OP when you are
      # ahead, so printing it unconditionally manufactures a refusal the operator cannot
      # clear by following its own instruction.
      if git merge-base --is-ancestor "$LOCAL_TIP" "$REMOTE_TIP" 2>/dev/null; then
        echo "            BEHIND: the tag would name a tree missing what has already landed. Catch up:"
        echo "              git pull --ff-only"
      elif git merge-base --is-ancestor "$REMOTE_TIP" "$LOCAL_TIP" 2>/dev/null; then
        echo "            AHEAD: the tag would name commits nobody else has — the same state"
        echo "            check-board.sh's [f1] arm reports. Publish them first:"
        echo "              git push $REMOTE HEAD:$DEFAULT_BRANCH"
        echo "            'git pull --ff-only' will NOT clear this; it is a no-op here."
      else
        echo "            DIVERGED: neither tip contains the other. Reconcile by hand — this script"
        echo "            will not choose a history for you — then re-run."
      fi
      echo "            NOTHING WAS WRITTEN."
    } >&2
    exit 1
  fi
fi

# ── Preflight 3 (gate b): verify.sh green. ───────────────────────────────────
# NOTE the invocation form: ${VAR:-"quoted default"}, NOT a bare `$CMD` variable.
# The quoted default keeps the default path a single word even when the repo path
# contains a space; a bare unquoted expansion word-splits on it, runs the path's
# first word, and produces a FALSE failure on every run. When the seam is SET, the
# unquoted expansion still splits a multi-word stub, as intended.
echo "[b] verify.sh (the project's gate runner)..."
if ! ${RELEASE_VERIFY_CMD:-"$SCRIPT_DIR/verify.sh"}; then
  echo "release.sh: verify.sh FAILED — refusing to cut $TAG on a red gate." >&2
  exit 1
fi

# ── Preflight 4 (gate c): the project's own extra gates, in declared order. ──
for rec in ${PREFLIGHT_GATES[@]+"${PREFLIGHT_GATES[@]}"}; do
  g_name="${rec%%|*}"; g_cmd="${rec#*|}"
  if [ "$g_name" = "$rec" ] || [ -z "$g_cmd" ]; then
    echo "release.sh: malformed PREFLIGHT_GATES record: '$rec' (expected \"<name>|<command…>\")." >&2
    exit 1
  fi
  echo "[c] $g_name..."
  # shellcheck disable=SC2086  # deliberate word-split of the declared command
  if ! $g_cmd; then
    echo "release.sh: preflight gate '$g_name' FAILED — refusing to cut $TAG." >&2
    exit 1
  fi
done

# ── Preflight 5 (gate d): the board is clean. check-board.sh exits 0 always, so
#    judge by its 'board-drift: clean' MARKER, not its exit code. Same quoted-
#    default invocation form as gate b, for the same spaced-path reason.
echo "[d] board-drift (check-board.sh)..."
board_out="$(${RELEASE_BOARD_CMD:-"$SCRIPT_DIR/check-board.sh"} 2>&1)" || true
if ! printf '%s\n' "$board_out" | grep -q 'board-drift: clean'; then
  echo "release.sh: check-board.sh reports drift — resolve it before cutting $TAG." >&2
  printf '%s\n' "$board_out" | grep -E 'board-drift|⚠' >&2 || true
  exit 1
fi

# ── Preflight 6 (gate e): every declared release document covers this version. ─
if [ "${#RELEASE_DOCS[@]}" -eq 0 ]; then
  echo "[e] RELEASE_DOCS is empty — no release document is gated. (Declare them in the"
  echo "    config block; a consumer-facing notes file that nothing enforces stops being"
  echo "    maintained by the second release.)"
fi
for rec in ${RELEASE_DOCS[@]+"${RELEASE_DOCS[@]}"}; do
  doc="${rec%%|*}"; what="${rec#*|}"
  if [ "$doc" = "$rec" ]; then
    echo "release.sh: malformed RELEASE_DOCS record: '$rec' (expected \"<path>|<what to write>\")." >&2
    exit 1
  fi
  echo "[e] $doc has a ## [$NUM] section..."
  if ! grep -qE "^## \[$NUM_RE\]" "$REPO_ROOT/$doc" 2>/dev/null; then
    echo "release.sh: $doc has no '## [$NUM]' section — refusing to tag an undocumented version. Write it: ${what}. Then re-run." >&2
    exit 1
  fi
  # AND THE SECTION HAS CONTENT. The heading alone used to satisfy this gate, so a
  # `## [X.Y.Z]` over a placeholder, a TODO, or nothing at all cut a release whose notes
  # said nothing — and the preflight then reported the section PRESENT, which a reader
  # takes as the notes being in order. This is the MECHANICAL half of the question;
  # whether the notes are TRUE is not gateable and is a human pass before the cut.
  #
  # A PLACEHOLDER IS NOT CONTENT, and the shipped placeholder shape is <angle brackets>
  # (EXTRACTION.md's blanks convention), so it is recognised by shape rather than by a
  # list of words somebody has to keep current.
  doc_body="$(awk -v num_re="^## \\\\[$NUM_RE\\\\]" '
    # FOUR BACKSLASHES, matching gate (f) above, and the difference is invisible on
    # inspection: with two, the shell hands awk `^## [1.1.0]`, where the brackets are a
    # CHARACTER CLASS rather than literal — so the heading never matches, the section is
    # read as empty, and this gate refuses every release. Measured, on the first run.
    BEGIN { inside = 0; n = 0 }
    /^## \[/ { if (inside) exit; if ($0 ~ num_re) { inside = 1; next } }
    inside {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "") next
      if (line ~ /^<.*>$/) next              # an angle-bracket placeholder
      if (line ~ /^[-*+][[:space:]]*$/) next # an empty bullet
      if (line ~ /^[-*+][[:space:]]*<.*>$/) next
      if (toupper(line) ~ /^(TODO|TBD|N\/A|NONE|WIP)[[:punct:]]*$/) next
      n++
    }
    END { print n+0 }
  ' "$REPO_ROOT/$doc" 2>/dev/null)"
  if [ "${doc_body:-0}" -eq 0 ]; then
    echo "release.sh: ${doc}'s '## [$NUM]' section is EMPTY — a heading with no content under it, or only placeholders. The heading being there is not the notes being there. Write it: ${what}. Then re-run." >&2
    exit 1
  fi
done

# ── Preflight 7 (gate f): the section HEADER DATE is not older than its own body.
# One-directional on purpose: an OLDER date in the body is ordinary (a measurement
# taken weeks ago, a superseded ruling), and only a date the header cannot yet have
# known about is a defect. Only the TARGET section is read — history is not swept,
# and a later section's dates are not this cut's business.
for rec in ${RELEASE_DOCS[@]+"${RELEASE_DOCS[@]}"}; do
  doc="${rec%%|*}"
  echo "[f] ${doc}'s [$NUM] header date is not older than its own content..."
  verdict="$(awk -v num_re="^## \\\\[$NUM_RE\\\\]" '
    BEGIN { inside = 0; header = ""; newest = "" }
    /^## \[/ {
      if (inside) { exit }
      if ($0 ~ num_re) {
        inside = 1
        if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
          header = substr($0, RSTART, RLENGTH)
        }
        next
      }
    }
    inside {
      line = $0
      while (match(line, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
        found = substr(line, RSTART, RLENGTH)
        if (found > newest) { newest = found }
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END { print header "\t" newest }
  ' "$REPO_ROOT/$doc" 2>/dev/null)"
  header_date="${verdict%%$'\t'*}"
  newest_date="${verdict##*$'\t'}"
  # A MISSING HEADER DATE IS A REFUSAL, NOT A SKIP — and this is the state the kit's own
  # documented workflow actually produces, because NOTHING IN THE KIT EVER STAMPS THAT
  # DATE. The cutter writes it by hand or does not. The `-n` guard below used to let the
  # dateless case through: a header with no date is not "earlier than" anything, so the
  # comparison was skipped and the section cleared. **A gate that only refuses the state
  # nobody reaches, and passes the state everybody reaches, is not a gate.**
  if [ -z "$header_date" ]; then
    echo "release.sh: ${doc}'s '## [$NUM]' heading carries NO DATE, so this gate cannot order it against its own content — and nothing in the kit writes that date for you. Add it to the heading as '## [$NUM] — YYYY-MM-DD' (the day you cut), then re-run." >&2
    exit 1
  fi
  if [ -n "$newest_date" ] && [ "$header_date" \< "$newest_date" ]; then
    echo "release.sh: ${doc}'s '## [$NUM]' header date is $header_date, but the section itself carries $newest_date — a release dated before the changes it contains. The section DATE is the CUTTER'S: set the header to the day you cut (at least $newest_date), then re-run." >&2
    exit 1
  fi
done

echo "── preflight: all gates green ✓"

# ── Dry run stops here — mutate NOTHING. ─────────────────────────────────────
if [ "$DRY_RUN" = "true" ]; then
  echo
  echo "(dry run) would: bump ${#VERSION_FILES[@]} version file(s) → $NUM, commit as"
  echo "          '[$ROLE] release: $TAG …', tag $TAG (annotated), push to $REMOTE."
  [ "$RELEASE_PUBLISH" = "true" ] && echo "          …then publish the $DIST_BRANCH branch."
  echo "(dry run — nothing was changed.)"
  exit 0
fi

# ── MUTATE. Every gate is green; from here we bump, commit, tag, push. ───────
BUMPED=()
bump_one() {  # <path> <line-prefix> <quote>
  local f="$REPO_ROOT/$1" prefix="$2" q="$3" tmp expr
  [ -f "$f" ] || { echo "release.sh: VERSION_FILES names '$1', which does not exist." >&2; return 1; }
  if [ -n "$q" ]; then
    expr="s|^${prefix}${q}[^${q}]*${q}|${prefix}${q}${NUM}${q}|"
  elif [ -n "$prefix" ]; then
    expr="s|^${prefix}.*|${prefix}${NUM}|"
  else
    # No prefix AND no quote means "the line IS the version" (a plain VERSION
    # file). The pattern is deliberately narrow — a bare `s|^.*|…|` would rewrite
    # EVERY line of the file, which is a destructive way to bump a one-line file
    # and a catastrophic one to bump anything else.
    expr="s|^[0-9][^[:space:]]*[[:space:]]*$|${NUM}|"
  fi
  tmp="$(mktemp)"
  sed "$expr" "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
  # READ IT BACK. A format drift in one file would otherwise ship a half-bumped
  # release, and the read-back is the only thing that can tell the difference
  # between "sed matched" and "sed silently matched nothing".
  grep -qF "${prefix}${q}${NUM}${q}" "$f"
}

if [ "$VERSION_IN_TAG_ONLY" != "true" ]; then
  echo "── bumping version → $NUM in ${#VERSION_FILES[@]} file(s)"
  for rec in "${VERSION_FILES[@]}"; do
    v_path="${rec%%|*}"; v_rest="${rec#*|}"; v_prefix="${v_rest%%|*}"; v_quote="${v_rest#*|}"
    [ "$v_rest" = "$rec" ] && { echo "release.sh: malformed VERSION_FILES record: '$rec' (expected \"<path>|<line-prefix>|<quote>\")." >&2; exit 1; }
    [ "$v_quote" = "$v_rest" ] && v_quote=""
    if bump_one "$v_path" "$v_prefix" "$v_quote"; then
      BUMPED+=("$v_path")
      echo "   ✓ $v_path"
    else
      echo "release.sh: the bump did not apply cleanly to '$v_path' — restoring every file touched, no commit made." >&2
      for done_path in ${BUMPED[@]+"${BUMPED[@]}"}; do
        git checkout -- "$done_path" 2>/dev/null || true
      done
      git checkout -- "$v_path" 2>/dev/null || true
      exit 1
    fi
  done
  git add -- "${BUMPED[@]}"
fi

COMMIT_MSG="[$ROLE] release: $TAG — bump version to $NUM + annotated tag"
if [ "$VERSION_IN_TAG_ONLY" = "true" ]; then
  COMMIT_MSG="[$ROLE] release: $TAG — annotated tag (the version lives in the tag)"
  git commit --allow-empty -m "$COMMIT_MSG" --quiet
else
  git commit -m "$COMMIT_MSG" --quiet
fi
RELEASE_SHA="$(git rev-parse --short HEAD)"
echo "── release commit: $RELEASE_SHA — \"$COMMIT_MSG\""

git tag -a "$TAG" -m "$TAG"
echo "── annotated tag $TAG created."

# ── THE RECOVERY IS PRINTED AS NORMAL OUTPUT, HERE, WHILE THE RUN IS HEALTHY.
#    `doctrine/fix-execution.md` § A.7: a multi-step landing script gets killed
#    mid-run — a caller's timeout, a closed window, the host — and the failure
#    branches below, which carry this same recovery text, DO NOT RUN, because
#    nothing failed. The two lines above assert a release commit and an annotated
#    tag, and neither of them says LOCAL, so a transcript that ends here reads as
#    a cut release. The pushes are what makes that true, so the state is stated
#    BEFORE them, at the point where this cut stops being undoable.
#
#    The mirror of finish-pr.sh's `── LANDED.` block, at the mirror-image moment:
#    there the act HAS published and the cleanup has not; here NOTHING has
#    published. Every command named below is safe to re-run — an already-pushed
#    ref answers "Everything up-to-date", and --publish-only rebuilds — which is
#    what lets ONE block be the whole remaining-steps recovery for a death
#    anywhere after it, rather than one block per seam.
#
#    RE-RUNNING THIS SCRIPT IS NOT one of those safe commands, and that is why the
#    block says so: the tag now exists, so preflight 1 refuses with "a version is
#    cut once" — correct, and baffling to an operator whose tag was never pushed.
{
  echo
  echo "── LOCAL ONLY. NOTHING IS PUSHED YET, so $TAG IS NOT RELEASED."
  echo "   The bump, release commit $RELEASE_SHA and annotated tag $TAG exist in THIS"
  echo "   clone and nowhere else; $REMOTE has none of them. If this run stops here —"
  echo "   killed, timed out, disconnected — finish it with exactly these commands:"
  echo "     git push $REMOTE HEAD:$DEFAULT_BRANCH"
  echo "     git push $REMOTE $TAG"
  if [ "$RELEASE_PUBLISH" = "true" ]; then
    echo "     ./scripts/release.sh $NUM --publish-only     (step 11, the $DIST_BRANCH copy)"
  fi
  echo "   Each is safe to re-run. RE-RUNNING THIS SCRIPT IS NOT — it refuses now that"
  echo "   $TAG exists. To abandon the cut instead, undo the two local acts:"
  echo "     git tag -d $TAG && git reset --hard HEAD~1"
  echo
}

echo "── pushing commit + tag to $REMOTE/$DEFAULT_BRANCH..."
if ! git push "$REMOTE" "HEAD:$DEFAULT_BRANCH"; then
  echo "release.sh: pushing the release commit FAILED. The commit + tag exist LOCALLY but are NOT on $REMOTE." >&2
  echo "            Recover: git push $REMOTE HEAD:$DEFAULT_BRANCH && git push $REMOTE $TAG" >&2
  exit 1
fi
if ! git push "$REMOTE" "refs/tags/$TAG"; then
  echo "release.sh: pushing tag $TAG FAILED. The commit is on $REMOTE but the tag is only LOCAL." >&2
  echo "            Recover: git push $REMOTE $TAG" >&2
  exit 1
fi

# ── PUBLISH the distribution copy. Both pushes are on the remote, so the release
#    is AUTHORITATIVE from here on and nothing below can un-cut it.
if [ "$RELEASE_PUBLISH" = "true" ]; then
  if publish_dist; then
    echo "── published $DIST_BRANCH: consumers can now run"
    echo "     git clone --branch $DIST_BRANCH --depth 1 $DIST_REMOTE_URL"
  else
    echo >&2
    echo "release.sh: PUBLISHING THE $DIST_BRANCH BRANCH FAILED — but THE RELEASE ITSELF SUCCEEDED." >&2
    echo "            Version $NUM is committed on $DEFAULT_BRANCH and tag $TAG is pushed to $REMOTE;" >&2
    echo "            both are authoritative. Only the consumer distribution copy is missing." >&2
    echo "            The tag is NOT rolled back. Recover: re-run just the publish with" >&2
    echo "            ./scripts/release.sh $NUM --publish-only" >&2
  fi
fi

echo
echo "✓ Cut $TAG: version $NUM committed on $DEFAULT_BRANCH, annotated tag pushed to $REMOTE."
