#!/usr/bin/env bash
# KIT-CLASS: KIT — the configuration seam itself — edit the prefixes, take the rest as-is. See process/EXTRACTION.md.
# Configuration for the kanban + roles scripts. Sourced by every script that needs
# to know the project's prefix conventions.
#
# THIS FILE IS THE SEAM. Every value a kanban script needs but cannot derive is
# declared here, once. The rule (process/contracts/config-seam.md § 3): if a
# consumer needs a value this seam does not define, that is a GAP IN THE SEAM, and
# it is fixed by adding it here rather than by hard-coding it at the call site.
#
# `scripts/kit-init.sh` stamps ISSUE_PREFIX, PRD_PREFIX and PROJECT_NAME on day
# one; after that, edit them here. A change takes effect on the next script
# invocation — existing files are NOT renamed.
#
# Override at runtime via env var, e.g.:
#   ISSUE_PREFIX=TEST ./scripts/new-issue.sh foo --id TEST-001
# (--id is REQUIRED by every creation script — this example predates that and, run as
# written, refused.)
#
# The kanban worktree scripts resolve the TRUNK (default branch) from
# <remote>/HEAD — see scripts/lib/kanban-worktree.sh's kwt_resolve(), and state
# your trunk in the project adapter (CLAUDE.md § "The trunk"). It is deliberately
# NOT a knob here: a repository has exactly one answer and git already holds it.

# Issue / bug prefix. Used by new-issue.sh, new-bug.sh, new-refactor.sh,
# next-id.sh, archive.sh. Generated filenames look like ${ISSUE_PREFIX}-001-<slug>.md.
#
# `KIT` is the SHIPPED PLACEHOLDER, not a recommendation — kit-init.sh derives the
# old value from this very line so it can rewrite the templates' example ids, so
# the placeholder must be alphanumeric and start with a letter (an <angle-bracket>
# blank would break that derivation). Replace it with your own two-to-five-letter
# prefix on day one: ./scripts/kit-init.sh --prefix XYZ --trunk main
ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"

# PRD prefix. Used by new-prd.sh.
# Generated filenames look like ${PRD_PREFIX}-001-<slug>.md.
# The default `PRD` is fine for most projects.
# THE ONE FALLBACK LITERAL FOR THIS NAME, and the only one. Consumers write
# "${PRD_PREFIX}" bare: they source this file first, so the name is always set by the
# time they read it, and a second ":-PRD" in a consumer is a second authority for the
# default that nothing keeps in step with this line.
PRD_PREFIX="${PRD_PREFIX:-PRD}"

# Project name — the name the role docs and the templates spell out in prose.
# Declared HERE for the seam rule stated in the header. kit-init.sh reads this
# default to learn what name the travelling docs currently carry, which is what
# lets it rewrite them and then COUNT what it left behind instead of promising a
# clean search. That census is the whole reason this value is a seam and not a
# literal scattered through the docs: a transplant that CLAIMED to be clean has
# been measured leaving hundreds of the donor's own tokens behind.
PROJECT_NAME="${PROJECT_NAME:-<project-name>}"

# Validate a caller-supplied issue id and check for collisions (read-only; no
# side effects). The new-* creation scripts are STATELESS: the caller (the agent,
# which has context the scripts don't) determines the next number — typically via
# ./scripts/next-id.sh — and passes it as --id. This just guards the input.
#   Usage:  validate_issue_id "$ID" "$ROOT"   # uses ISSUE_PREFIX; returns non-0 on a hard error
# THE SHORT NAME'S SHAPE IS DECLARED IN process/contracts/issue-creation.md § 5, and
# this implements it — it does not define it. The ONE prose statement of the shape here is
# the gloss the refusal prints, and it belongs to this single site rather than contradicting
# it: it sits in the same function as the pattern, so the two cannot drift apart independently
# the way a copy in another tool would, and an operator who has just been refused should not
# have to open a contract to learn roughly what was wanted. Nothing else restates the rule —
# a shape written twice in two PLACES is a shape that drifts, which is the sheet's own reason
# for stating it once. Read § 5 for the shape and for WHY it is this narrow (the name
# travels into both a git ref and a filename, and it is the intersection of what those
# two accept).
#
# IT IS ALSO WHY THIS REFUSES RATHER THAN SANITISING. Rewriting a bad name into a legal
# one is the tempting fix and the wrong one: a caller who asked for one name and got
# another has lost the one thing they typed, and will not find it by the name they used.
# ESCAPE THE REPLACEMENT HALF. Free-text values reach a `s|…|REPL|` expression, and in
# the replacement three characters are not literal: the delimiter `|` ends the
# expression, `\` escapes, and `&` means "the whole match". A --prd of `a|b` used to
# abort sed mid-run; a value containing `&` was silently corrupted into the card.
#
# THIS IS THE ONE DEFINITION. It was copied byte-for-byte into three minting scripts and
# ABSENT from the one that takes the most free text — subtask.sh, whose create arm
# publishes to the trunk. A rule stated in four places is a rule that holds in three.
#
# WHAT IT DOES NOT COVER, said here so nobody infers otherwise: an embedded NEWLINE.
# `printf '%s' | sed` on a multi-line value yields a multi-line replacement, which sed
# rejects. That is true of every caller and is not closed.
sed_repl() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

validate_slug() {
  local slug="$1" pos ch
  if [ -z "$slug" ]; then
    echo "Error: <slug> is required — see process/contracts/issue-creation.md § 5." >&2
    return 1
  fi
  printf '%s' "$slug" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' && return 0

  # NAME THE POSITION AND THE CHARACTER, per § 3. "Invalid name" makes the caller guess
  # which rule they broke, and the commonest offender — a space — is invisible at the end
  # of a line, so the one thing they cannot see is the one thing they are not told.
  pos=1
  while [ "$pos" -le "${#slug}" ]; do
    ch="$(printf '%s' "$slug" | cut -c"$pos")"
    if ! printf '%s' "$ch" | grep -qE '^[a-z0-9-]$'; then
      case "$ch" in
        " ") ch="a space" ;;
        "")  ch="a non-printing character" ;;
        *)   ch="'$ch'" ;;
      esac
      echo "Error: <slug> '$slug' — $ch at position $pos is not allowed." >&2
      break
    fi
    pos=$(( pos + 1 ))
  done
  if [ "$pos" -gt "${#slug}" ]; then
    # Every character is individually legal, so the fault is where the hyphens sit.
    case "$slug" in
      -*)   echo "Error: <slug> '$slug' — a leading hyphen at position 1 is not allowed." >&2 ;;
      *-)   echo "Error: <slug> '$slug' — a trailing hyphen at position ${#slug} is not allowed." >&2 ;;
      *--*) echo "Error: <slug> '$slug' — two hyphens in a row are not allowed." >&2 ;;
      *)    echo "Error: <slug> '$slug' does not match the declared shape." >&2 ;;
    esac
  fi
  echo "       A short name is lower-case letters, digits and single hyphens between" >&2
  echo "       them — the shape is declared in process/contracts/issue-creation.md § 5." >&2
  echo "       It is not rewritten for you: the name you type is the name you get." >&2
  return 1
}

validate_issue_id() {
  local id="$1" root="$2" existing
  if [ -z "$id" ]; then
    echo "Error: --id is required (e.g. --id ${ISSUE_PREFIX}-034)." >&2
    echo "       Get the next id with:  ./scripts/next-id.sh   (then sanity-check it)." >&2
    echo "       These scripts are stateless — the caller passes the number in." >&2
    return 1
  fi
  if ! printf '%s' "$id" | grep -qE "^${ISSUE_PREFIX}-[0-9]+$"; then
    echo "Error: --id '$id' must look like ${ISSUE_PREFIX}-NNN." >&2
    return 1
  fi
  # Hard collision: this id is already a live file anywhere under progress/.
  existing="$(find "$root/progress" -type f -name "${id}-*.md" 2>/dev/null | head -1)"
  if [ -n "$existing" ]; then
    echo "Error: ${id} already exists at ${existing#"$root"/}." >&2
    return 1
  fi
  # Soft collision: this id appears in ARCHIVE.md (an archived issue used it).
  if [ -f "$root/ARCHIVE.md" ] && grep -qE "(^|[^A-Za-z0-9])${id}([^0-9]|\$)" "$root/ARCHIVE.md" 2>/dev/null; then
    echo "Warning: ${id} appears in ARCHIVE.md — it may already belong to an archived issue." >&2
    echo "         Proceeding; ensure this is intentional (./scripts/next-id.sh suggests the next free id)." >&2
  fi
  return 0
}

# THE PUSH-BEFORE-YOU-MOVE TRAP, replicated THREE times independently by three
# different agents on their first day with this kit — the same twenty minutes lost
# each time.
#
# A creation script writes a file into the OPERATOR'S checkout; move-issue.sh works on
# the TRUNK, by two reads rather than one: it moves the file inside .kanban-wt/, which
# is `reset --hard <remote>/<trunk>` on every op, and when it finds nothing there it
# re-reads the trunk's board straight out of the freshly-fetched <remote>/<trunk> REF
# so it can say precisely what it looked at. Neither read can see the operator's own
# checkout, so a minted-but-unpushed file is INVISIBLE to the mover, which reports
# "no file matching <ID>-*.md found under progress/" — a true statement with an
# unfindable cause.
#
# POSTURE: PRINT, NOT PERFORM — decided here, once, for every creation script.
# process/contracts/issue-creation.md § 2 makes creation INERT ("it writes the new
# item and nothing else: no state change, no publication"), and § 4.3 makes
# "nothing else changed" the definition of green. A creation script that committed
# and pushed would violate its own contract sheet, and would publish drafts nobody
# had read yet. So the fix is to make the step UNMISSABLE, not automatic.
#
#   Usage:  print_push_before_move "<path/to/created/file.md>"
print_push_before_move() {
  local path="${1:-}" rel
  # `${BASH_SOURCE[0]:-$0}`, never the bare form: THIS FILE IS SOURCED, and the
  # bare form is empty in any shell that does not set BASH_SOURCE. Measured
  # 2026-08-26: under `set -u` (which all three callers run) the expansion below
  # then fails and THIS WARNING NEVER PRINTS — silently skipped, after the card
  # has already been created, which is the exact created-but-unpushed trap this
  # function exists to prevent. The message is the whole point, so the fallback
  # only has to keep it ALIVE: where `$0` resolves to something other than this
  # file's directory the path prints unshortened, which is a cosmetic loss and
  # the correct trade against silence. Latent under the kit's own paths (the
  # three callers are bash-executed, so BASH_SOURCE is always populated there) —
  # fixed because it is reachable, one line, and the last member of its class.
  # The guarded sites are derivable — `grep -rn 'BASH_SOURCE\[0\]:-\$0' scripts`
  # — deliberately not written here as a number.
  rel="${path#"$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/"}"
  echo ""
  echo "  ⚠ PUSH IT BEFORE YOU MOVE IT. ./scripts/move-issue.sh reads the board from the"
  echo "    trunk — the .kanban-wt worktree for the move itself, and the freshly-fetched"
  echo "    remote ref when it reports a miss — so a file that exists only in this"
  echo "    checkout is invisible to it — the move fails with 'no file matching'."
  echo ""
  echo "      git add \"${rel}\" && git commit -m \"[<Role>] <ID>: mint\" && git push"
  echo ""
  echo "    Then, and only then:  ./scripts/move-issue.sh <ID> in_progress --role <Role> --note \"…\""
}
