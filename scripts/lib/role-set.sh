#!/usr/bin/env bash
# KIT-CLASS: KIT — the shared role-set read and the pre-mutation tag check.
# See process/EXTRACTION.md § 2.4.
#
# WHY THIS EXISTS. Three shipped scripts commit under a role tag that is ONE MEMBER of
# the project's role set — archive.sh's sweep, subtask.sh's create arm, finish-pr.sh's
# squash. Those tags used to be hardcoded, so a project that narrowed its role set got a
# commit-msg hook that rejected its own tools MID-OPERATION: the file is already git-mv'd
# and the Activity entry already appended inside the shared kanban worktree, and the
# commit that would have carried them fails. The next board operation `reset --hard`s
# that worktree. So the failure mode is not an error message — it is silent data loss in
# somebody else's lane. subtask.sh's `move` arm already argued exactly this for its
# --role whitelist; these three sites are the same argument, unapplied.
#
# WHY A KNOB AND A REFUSAL, AND NEVER A DERIVED TAG. The obvious "fix" is to derive the
# tag from the set — `${ROLE_PREFIXES%%|*}` or similar. Do not. These tags carry SEAT
# IDENTITY: [Orchestrator] on the archive sweep means session-close housekeeping,
# [QA] on finish-pr means the review seat landed it, [Orchestrator] on subtask.sh means
# the decomposer. A derived tag attributes all three to whichever role happens to sort
# first and writes a FALSE SEAT into git history, permanently. And an adopter's set may
# legally have ONE member, so a derivation cannot express a distinction its source does
# not contain. The project renames the seat by setting the knob; the kit refuses rather
# than guessing.
#
# WHY IT IS A LIBRARY. All three consumers already source from scripts/lib/. Written
# inline this would be three more copies of the ROLE_PREFIXES read, an idiom that is
# already duplicated across the tree; here it is one.

# kit_role_set <repo-root> — echo the project's declared role set, or nothing.
# Callers MUST treat empty as "could not read", never as "no roles declared".
kit_role_set() {
  sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$1/scripts/githooks/commit-msg" 2>/dev/null | head -1
}

# kit_role_display <repo-root> — the declared set rendered FOR USAGE TEXT, or, when the seam
# cannot be read, a sentence naming the seam. NEVER empty and NEVER a failure.
#
# WHY THIS IS A RENDERER AND NOT A SECOND COPY. A script's usage text has to tell the operator
# which roles are legal, and the obvious way to do that — type the list into the header — is what
# this library was extended for: `move-issue.sh` carried the set space-padded in its `--help`
# header and unpadded in its enforcement, `kit-init --roles` stamps by `grep -lF` on the unpadded
# shape, so the enforcement moved and the header did not. The same script then advertised four
# roles it refused, on every adopted tree. The fix is not a second shape for the matcher to
# learn; it is one authoring site — the seam — read at print time.
#
# WHY IT DEGRADES TO NAMING THE SEAM RATHER THAN TO A GUESS OR AN ERROR. A usage request must
# ALWAYS succeed (`process/contracts/issue-creation.md` § 3), so this cannot fail. It must also
# not GUESS: printing the kit's shipped set on a tree whose seam is unreadable would reproduce
# exactly the defect above — a list that is right about the kit and wrong about this project.
# Naming the seam is the only answer that is true on every tree. The caller's own `--help` is
# still complete and still exits 0; one line of it says where to look instead of what to type.
kit_role_display() {
  local set_
  set_="$(kit_role_set "$1" 2>/dev/null || true)"
  if [ -n "$set_" ]; then
    printf '%s' "$set_" | sed 's/|/ | /g'
  else
    printf 'as declared in scripts/githooks/commit-msg (ROLE_PREFIXES) — unreadable from here, so not listed'
  fi
}

# kit_require_role <repo-root> <tag> <knob-name> — refuse, on stderr, with status 1, if
# <tag> is not a member of the declared set. Silent and 0 when it is.
#
# AN UNREADABLE HOOK IS NOT A PASS AND NOT A FAILURE — it is a NAMED skip. The set is the
# only authority on what is legal, and a script that cannot read it knows nothing. It
# says so and proceeds, because refusing every board operation on a tree whose hook was
# deleted would be a worse failure than the one this guard exists to prevent, and the
# hook itself will still refuse the commit if the tag is genuinely wrong.
kit_require_role() {
  local root="$1" tag="$2" knob="$3" set_
  set_="$(kit_role_set "$root")"
  if [ -z "$set_" ]; then
    echo "Note: could not read ROLE_PREFIXES from scripts/githooks/commit-msg — the role tag '$tag' was NOT checked against your declared set. If it is wrong, the commit-msg hook will refuse mid-operation." >&2
    return 0
  fi
  case "|$set_|" in
    *"|$tag|"*) return 0 ;;
  esac
  {
    echo "Error: the role tag '$tag' is not in this project's declared role set."
    echo "         declared: $set_"
    echo "       This script commits under that tag, and the commit-msg hook would reject it"
    echo "       AFTER the board move had already been made — leaving uncommitted state in the"
    echo "       shared kanban worktree that the next board operation discards. Refusing first."
    echo "       Set the seat this script acts as:  $knob=<one of the above> $0 ..."
    echo "       NOTHING WAS CHANGED."
  } >&2
  return 1
}
