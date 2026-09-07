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

# kit_role_resolve <repo-root> <stamped-default> — resolve the set an OPERATOR-SUPPLIED role is
# checked against. Sets two variables and echoes nothing:
#   KIT_ROLE_SET        the set to enforce against — never empty
#   KIT_ROLE_SRC        where it came from, in words, FOR PRINTING
#   KIT_ROLE_DEFAULTED  empty when derived; `1` when the default was used
#
# KIT_ROLE_DEFAULTED exists so a caller can decide whether to announce WITHOUT parsing
# KIT_ROLE_SRC. Keying an announcement off the first word of a sentence is a matcher on prose, and
# prose gets reworded; a flag does not.
#
# WHY THIS IS NOT kit_require_role. That function is for a tag the SCRIPT CHOOSES (seat identity),
# and its unreadable-hook policy is a named SKIP: it does not check and proceeds, because the tag
# came from the kit and the hook will still refuse a genuinely wrong one. `--role` is different in
# the one way that matters: the operator typed it, and
# `process/contracts/issue-creation.md` § 3 says a value outside a declared enum is refused. A skip
# would silently widen what `--role` accepts to ANYTHING on a tree whose hook is gone. So this
# resolves an enum to check against instead of deciding whether to check.
#
# WHY A DEFAULT IS NOT A SECOND COPY, which is the objection this function has to answer, because
# removing second copies of the role set is the whole point of this library:
#
#   A literal beside a READABLE authority is a DUPLICATE. A literal reached only when the
#   authority is UNREADABLE is a DEFAULT.
#
# Duplicates drift — that is the entire reason § 2.4 hunts them, and it is what happened to
# `move-issue.sh`'s help text. A default CANNOT drift, because the thing it could disagree with is
# gone at the moment it is used. They are different objects that happen to be spelled alike.
#
# AND WHAT STOPS A DEFAULT BECOMING A FALSE CLAIM IS THAT IT SAYS SO. The moment a fallback is
# presented as *this project's set*, it is a statement of fact about this tree and it is wrong, and
# § 3 forbids that correctly. So KIT_ROLE_SRC exists to be PRINTED, and the wording below is
# `check-board.sh`'s, deliberately: that script has carried derive-with-ANNOUNCED-fallback for two
# separate lists since before this function existed, and its own comment gives the reason — a run
# that used the fallback says so, "otherwise ✓ every scanned subject carries a [Role] prefix can
# mean …one of a set this project may not actually use".
#
# WHY THE DEFAULT IS AN ARGUMENT RATHER THAN A LITERAL IN HERE. It has to be STAMPABLE.
# `kit-init --roles` rewrites the set by `grep -lF` over `scripts/*.sh` and `scripts/githooks/*` —
# a glob that deliberately does NOT reach `scripts/lib/`, and whose own comment says to keep it
# narrow because a hand-edited hook could make `grep -lF` match widely and corrupt substrings. A
# default living in this file would therefore never be stamped, so on a narrowed tree whose hook
# later became unreadable it would enforce the KIT'S set instead of the project's — strictly more
# permissive than the literal it replaced. So: the POLICY lives here, once; the VALUE lives in the
# caller, where the existing stamper already reaches it. One mechanism, no widening.
#
# WHY GLOBALS. This returns two things — the set and its provenance — and the provenance must reach
# the operator. A shell function echoes one value; encoding both into one string and splitting it in
# every caller is the sort of second parsing site this library exists to remove.
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
