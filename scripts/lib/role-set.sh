#!/usr/bin/env bash
# KIT-CLASS: KIT — the shared role-set read and the pre-mutation tag check.
# See process/EXTRACTION.md § 2.4.
#
# WHY THIS EXISTS: archive.sh, subtask.sh and finish-pr.sh commit under a role tag that must be a
# member of the project's role set. A tag the commit-msg hook rejects fails AFTER the git mv and
# the Activity append in the shared kanban worktree, and the next board operation reports that
# dirty state (process/contracts/board-mover.md § 2). Refusing BEFORE the mutation costs a re-run;
# after it, a reconciliation.
#
# A KNOB AND A REFUSAL, NEVER A DERIVED TAG: the tag carries SEAT IDENTITY ([Orchestrator] on the
# archive sweep, [QA] on finish-pr). Deriving it from the set (`${ROLE_PREFIXES%%|*}`) writes a
# false seat into git history, and a one-member set cannot express the distinction at all.
#
# Its consumers are the files that SOURCE it (a filename grep also returns files that only name it):
#   grep -rlE '^[^#]*\.[[:space:]]+"\$SCRIPT_DIR/lib/role-set\.sh"' scripts --include='*.sh'

# kit_role_set <repo-root> — echo the project's declared role set, or nothing.
# Callers MUST treat empty as "could not read", never as "no roles declared".
kit_role_set() {
  sed -n "s/^ROLE_PREFIXES='\(.*\)'/\1/p" "$1/scripts/githooks/commit-msg" 2>/dev/null | head -1
}

# kit_role_display <repo-root> — the declared set rendered FOR USAGE TEXT, or, when the seam
# cannot be read, a sentence naming the seam. NEVER empty and NEVER a failure.
#
# The set is RENDERED from the seam at print time, never typed into a header: a typed copy drifts
# from the enforcement. It degrades to NAMING THE SEAM, never to a guess or an error: a usage
# request must always succeed (`process/contracts/issue-creation.md` § 3), and the kit's shipped
# set would be wrong about this project.
kit_role_display() {
  local set_
  set_="$(kit_role_set "$1" 2>/dev/null || true)"
  if [ -n "$set_" ]; then
    printf '%s' "$set_" | sed 's/|/ | /g'
  else
    printf 'as declared in scripts/githooks/commit-msg (ROLE_PREFIXES) — unreadable from here, so not listed'
  fi
}

# kit_role_resolve <repo-root> <stamped-default> — resolve the set an OPERATOR-SUPPLIED role is
# checked against. Sets two variables and echoes nothing:
#   KIT_ROLE_SET        the set to enforce against — never empty
#   KIT_ROLE_SRC        where it came from, in words, FOR PRINTING
#   KIT_ROLE_DEFAULTED  empty when derived; `1` when the default was used
#
# KIT_ROLE_DEFAULTED lets a caller decide whether to announce without matching on KIT_ROLE_SRC's
# prose.
#
# NOT kit_require_role, whose unreadable-hook policy is a named SKIP: `--role` is the OPERATOR'S
# value, and `process/contracts/issue-creation.md` § 3 refuses a value outside a declared enum. A
# skip would widen `--role` to anything on a tree whose hook is gone.
#
# THE DEFAULT IS NOT A SECOND COPY: a literal reached only when the authority is UNREADABLE cannot
# drift from it. It must SAY it is a fallback, so KIT_ROLE_SRC exists to be printed.
#
# THE DEFAULT IS AN ARGUMENT, and every caller's ROLE_SET_DEFAULT literal points here: it must be
# stampable, and `kit-init --roles` rewrites scripts/*.sh and scripts/githooks/* but never
# scripts/lib/. The POLICY lives here once; the VALUE lives in the caller.
#
# Globals, because the provenance must reach the operator alongside the set.
kit_role_resolve() {
  KIT_ROLE_SET="$(kit_role_set "$1" 2>/dev/null || true)"
  if [ -n "$KIT_ROLE_SET" ]; then
    KIT_ROLE_SRC="derived from scripts/githooks/commit-msg"
    KIT_ROLE_DEFAULTED=""
  else
    KIT_ROLE_SET="$2"
    KIT_ROLE_SRC="THE KIT'S FALLBACK SET — commit-msg was not readable in this source, so this is not your project's declared role set"
    KIT_ROLE_DEFAULTED=1
  fi
}

# kit_role_member <set> <value> — status 0 if <value> is a member of the `|`-separated <set>.
# The value is an operator's, so it is compared as TEXT: the quoted pattern makes any glob or `|`
# inside it literal. Same idiom as kit_require_role's membership test, deliberately — one shape.
kit_role_member() {
  case "|$1|" in
    *"|$2|"*) return 0 ;;
  esac
  return 1
}

# kit_require_role <repo-root> <tag> <knob-name> — refuse, on stderr, with status 1, if
# <tag> is not a member of the declared set. Silent and 0 when it is.
#
# AN UNREADABLE HOOK IS A NAMED SKIP, not a pass or a failure: refusing every board operation on
# a tree whose hook was deleted is worse, and the hook still refuses a genuinely wrong tag.
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
    echo "       shared kanban worktree that blocks every later board operation. Refusing first."
    echo "       Set the seat this script acts as:  $knob=<one of the above> $0 ..."
    echo "       NOTHING WAS CHANGED."
  } >&2
  return 1
}
