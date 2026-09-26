#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE progress-record writer. See process/EXTRACTION.md.
#
# ONE RECORD SHAPE, ONE PLACE, TRANSIENT BY CONSTRUCTION.
#
# Progress is already announced by several shipped scripts — to stdout, in their own
# wording, and nowhere a reader can open after the stream has scrolled away. This
# library adds the durable-for-a-day half: the same four fields, appended as one line
# to one gitignored directory, by a script or by a role.
#
# THE FOUR REQUIRED FIELDS, and nothing else is required:
#
#     timestamp   ISO-8601 UTC. Makes elapsed time and liveness EXACT rather than
#                 inferred — that is the whole reason it is not optional.
#     actor       who wrote it, ASSIGNED BY THE CALLER rather than reported by the
#                 agent. TWO KINDS, because the two converted producers are two kinds:
#                 a role side, `<role>` or `<role>:<issue-id>` with the role a member
#                 of the project's declared set; and a script side, `<name>.sh`. An
#                 actor matching neither is written as `unknown` with the offered value
#                 carried in `declared-actor=` — see the validator below.
#     class       status | info | warning | error — what a reader filters on.
#     description the human-readable line.
#
# EVERYTHING ELSE IS OPTIONAL, and optional means an ADDITIONAL FIELD, never a
# different payload. A reader that understands only the four required fields must be
# able to read every record, and that is the test. The temptation this resists: a
# script's phases are known at authoring time while a role's path branches, which
# looks like an argument for two shapes. It is not — a branch is an optional field,
# and a divergent payload is exactly what forces the fork in the parser. A format
# with a fork in the middle has to be learned twice.
#
# THE FORMAT IS TAB-SEPARATED, four fixed columns then `key=value` extras:
#
#     2026-09-16T10:04:11Z<TAB>Dev:KIT-042<TAB>status<TAB>moved to dev_complete<TAB>step=13/13
#
#   Tab, because the four required columns are then split by any reader in any
#   language with no quoting rules to agree on first, and because it is the one
#   separator the description will not contain — newlines and tabs are stripped from
#   every field before it is written (see _pr_clean), so a record is always exactly
#   one line and always has at least four columns. JSON was the alternative and was
#   not taken: it needs an encoder in every writer, and `awk -F'\t'` is the floor
#   this kit already requires.
#
#   THE EXAMPLE'S EXTRA IS `step=13/13` AND NOT `step=13 of 13`, WHICH IS WHAT IT USED
#   TO SAY. Extras are read back by splitting the field on spaces, so a spaced value
#   parses as the key `step=13` followed by two bare tokens — and the one worked example
#   this file offered an adopter was an extra that did not survive being read back. See
#   THE CALLER'S EXTRAS, VERBATIM below for why the fix is here and not in the loop.
#
# TRANSIENT BY CONSTRUCTION — THE RULE TO WRITE DOWN IS *nobody should ever have to
# dig through old logs for anything*. The directory is gitignored, records older than
# KIT_PROGRESS_TTL_DAYS (default 2) are unlinked on every write, and durable insight
# continues to live in reports, the card's Activity log and change files. If you find
# yourself wanting to KEEP one of these, what you actually want is a change file.
#
# THE VOLUME OBJECTION DOES NOT SURVIVE THE EXPIRY RULE. A suite running five-digit
# test counts may emit a line per test: that write is negligible against executing the
# test, and the lines are gone within a day.
#
# UNSUBSCRIBED RECORDS MAY BE OMITTED, AND NOTHING MAY DEPEND ON ONE. Every function
# here returns 0 whatever happens — an unwritable directory, a full disk, a read-only
# checkout. A caller that branches on the return value has made this a dependency,
# which is the one thing it must not become. Each addition must help WITH NO WATCHER
# AT ALL: `kit_progress_tail` is for the operator staring at a terminal, and that is
# the test a new field has to pass. A field that exists only to feed a dashboard fails.
#
# THE DIRECTORY IS A SEAM: KIT_PROGRESS_DIR overrides it. Default `.progress-records/`
# at the repo root, one file per UTC day (`YYYY-MM-DD.tsv`), appended to. One place,
# one structure — not one file.
#
# THE RUN ID IS THE OTHER SEAM: KIT_PROGRESS_RUN, when set and non-empty, appends
# `run=<id>` to every record this process writes. It is what unites an orchestrator and
# the subagents it spawned, and it is an EXTRA rather than a column — see kit_progress.
# ITS PROPAGATION IS NOT GUARANTEED AND CANNOT BE FIXED FROM IN HERE: a subagent spawned
# with a cleared environment writes records with no `run=` and says nothing about it. The
# dispatching site owns passing it on. Stated as a limit rather than left implied.
# THE MEASURED FAILURE ROUTE: on the one harness measured (2026-09-26), an `export` run
# inside an agent's tool call died with that call, reaching neither the agent's next command
# nor any subagent; the environment the session was LAUNCHED with, and its settings `env`
# block, did reach subagents. So an id chosen mid-session travels as a per-command prefix
# via each dispatch brief — .claude/skills/orchestrate/SKILL.md § Dispatch attribution § 7.

# _pr_clean <string> — collapse a field to something that cannot break the record.
# Tabs and newlines become spaces; a trailing space is trimmed. NOT a quoting scheme:
# there is nothing to unquote, because nothing survives that would need it.
_pr_clean() {
  printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/[[:space:]]\{1,\}$//'
}

# _pr_tok <string> — collapse a field to a SINGLE TOKEN, for a value that has to survive
# being read back out of the space-separated `key=value` extras. _pr_clean is not enough
# there: it turns a tab into a SPACE, and a space inside an extra's value splits one key
# into two when a reader tokenises the field. Runs of whitespace become `_`, and an empty
# result becomes `<empty>` so the key is never written with nothing after the `=`.
#
# THE ORDER OF THE THREE EXPRESSIONS IS THE WHOLE CORRECTNESS ARGUMENT, and getting it
# wrong is a defect that has already shipped here. The edges are trimmed FIRST, while the
# thing at the edge is still WHITESPACE; only then is what remains in the interior
# collapsed to `_`. An earlier draft substituted first and trimmed `^_` and `_$` after —
# and at that point a substituted `_` and a `_` THE CALLER TYPED are the same byte, so
# the trim could not tell them apart and ate both. `_x` came back as `x`, and `_` came
# back as `<empty>`: the placeholder that means "there was nothing here", written over a
# value the caller did offer. Trimming whitespace at the ends can never target a literal
# underscore, so the distinction is structural rather than guessed at.
#
# WHAT MUST STAY TRUE EITHER WAY: a value that is ALREADY one token is carried BYTE FOR
# BYTE. Preserving the offered value is the entire reason the declared- keys exist — a
# typo stays VISIBLE — and a writer that quietly rewrites it produces a record that is
# well-formed and wrong, which a reader cannot detect at all. That is a worse failure
# than the split this function exists to prevent, because a split is visible.
_pr_tok() {
  local v
  v="$(printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/^[[:space:]]\{1,\}//; s/[[:space:]]\{1,\}$//; s/[[:space:]]\{1,\}/_/g')"
  [ -n "$v" ] || v='<empty>'
  printf '%s' "$v"
}

# kit_progress_dir — where records go. Derived, never assumed present.
#
# EVERY WORKTREE OF ONE REPOSITORY WRITES ONE PLACE: the MAIN checkout's root, not this
# checkout's. It was `--show-toplevel`, which in a linked worktree is that worktree — so a
# dispatched leg's records landed where the orchestrator never read them, and were deleted
# with the worktree when the leg landed. The main checkout is the first entry of
# `git worktree list --porcelain` (git 2.7+), accepted only if it is not bare AND is its own
# top level — asked with GIT_DIR and GIT_WORK_TREE unset, because a git hook exports GIT_DIR and
# then `git -C <any dir> rev-parse --show-toplevel` answers <any dir>, which would accept a git dir.
# Otherwise this checkout's top level, as before — for example a bare repository's linked
# worktree (no main checkout), a submodule or a `--separate-git-dir` repository's linked worktree
# (their first entry is a git dir), and no repository at all ($PWD). A worktree whose main checkout
# was deleted or moved without `git worktree repair` has no working repository: it writes at $PWD.
# Those fallbacks write into a tree that may be removed; carry an absolute KIT_PROGRESS_DIR there.
kit_progress_dir() {
  if [ -n "${KIT_PROGRESS_DIR:-}" ]; then printf '%s' "$KIT_PROGRESS_DIR"; return 0; fi
  local root main
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
  [ -n "$root" ] || root="$PWD"
  main="$(git worktree list --porcelain 2>/dev/null \
    | awk 'NR==1 && /^worktree /{p=substr($0,10)} /^$/{exit} /^bare$/{p=""} END{print p}')"
  if [ -n "$main" ] && [ "$(unset GIT_DIR GIT_WORK_TREE; git -C "$main" rev-parse --show-toplevel 2>/dev/null)" = "$main" ]; then
    root="$main"
  fi
  printf '%s/.progress-records' "$root"
}

# _pr_expire <dir> — unlink day files older than the TTL. Best-effort, always 0.
# `find -mtime` is POSIX and needs no date arithmetic in shell.
_pr_expire() {
  local d="$1" ttl="${KIT_PROGRESS_TTL_DAYS:-2}"
  case "$ttl" in ''|*[!0-9]*) ttl=2 ;; esac
  find "$d" -maxdepth 1 -name '*.tsv' -type f -mtime "+$ttl" -exec rm -f {} + 2>/dev/null
  return 0
}

# _pr_role_set — the project's declared role set, `|`-separated, or empty.
#
# THERE IS NO SECOND READ OF ROLE_PREFIXES IN HERE, DELIBERATELY, AND THAT IS THE WHOLE POINT.
# `scripts/lib/role-set.sh` owns the read (process/EXTRACTION.md § 2.4) and this library CALLS it
# rather than carrying the sed expression. An earlier draft of this function held its own copy of
# that expression as a "fallback" for the case where role-set.sh was not sourced — and the harness
# was right to redden it: a copy is a copy whatever it is called, the copies then disagree about the
# same file with nothing in either to show it, and § 2.4 exists because that has already happened
# here. So the seam is reached exactly once, through its owner.
#
# FALLBACK POLICY — AN UNREADABLE SET IS A NAMED ACCEPT, NOT A REJECT, and it is different from
# every other reader's policy on purpose. `kit_require_role` announces its skip on stderr;
# `kit_role_resolve` substitutes a stamped default and says so. NEITHER IS AVAILABLE HERE: this
# library is forbidden to write to stderr or to fail its caller (see the header — a record may be
# omitted and nothing may depend on one), so it can neither announce nor refuse. What it CAN do is
# choose the harmless direction. Tagging every role-side record `unknown` on a tree whose hook was
# deleted would corrupt the very column the shape exists to make filterable — turning a missing
# hook into a poisoned log — whereas accepting them leaves the column exactly as filterable as it
# was before this validator existed. So: an empty set means ACCEPT THE MEMBERSHIP QUESTION — it
# does NOT skip the structural half, which _pr_actor_ok checks before ever asking this function.
# An unreadable seam stops this reader guessing WHICH ROLES are legal; it does not excuse it from
# reading the shape it declares. Callers MUST treat empty as "could not read", never as "no roles
# declared".
_pr_role_set() {
  command -v kit_role_set >/dev/null 2>&1 || return 0
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
  [ -n "$root" ] || root="$PWD"
  kit_role_set "$root" 2>/dev/null
}

# _pr_actor_ok <actor> — status 0 when <actor> has the declared shape.
#
# AN UNREADABLE SEAM ACCEPTS THE MEMBERSHIP QUESTION ONLY, never the structural one — see
# _pr_role_set's FALLBACK POLICY above for why this reader's policy differs from every other
# one's, and the TWO HALVES note below for what stays enforced regardless.
#
# CASE-SENSITIVE, DELIBERATELY. The commit-msg hook matches `^\[($ROLE_PREFIXES)\] `
# case-sensitively and kit_role_member compares as literal text, so `dev` is not the seat
# `Dev` anywhere else in this kit. Accepting it here would put two spellings of one seat in
# the column — which is the split filter this validator exists to close — and NORMALISING it
# would rewrite attribution the caller assigned, which § 2 of the contract reserves to the
# caller. So a case typo is tagged, and tagged means VISIBLE, which is the property being
# copied from the class arm.
_pr_actor_ok() {
  local a="$1" role set_
  # The script side: `<name>.sh`. The converted script-side producer names itself this way
  # and is not a role at all — contracts/progress-record.md § 5a says so directly, a
  # converted producer need not be a member of the role population.
  case "$a" in
    *.sh) case "$a" in *[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac ;;
  esac
  # The role side: `<role>` or `<role>:<id>`. Split on the FIRST colon only — an issue id
  # may legally contain one.
  #
  # TWO HALVES, AND ONLY THE SECOND NEEDS THE ROLE SET. The STRUCTURAL half — a non-empty
  # role, a non-empty id after any colon, and no whitespace anywhere — is true of the
  # declared shape on every tree, so it is checked FIRST and unconditionally. An earlier
  # draft folded it in after the set lookup and a control caught what that costs: on a tree
  # whose hook is unreadable, `has space` was accepted as a role. The fallback policy is
  # meant to stop this reader guessing WHICH ROLES are legal, not to stop it reading the
  # shape it declares.
  case "$a" in
    *[[:space:]]*) return 1 ;;
  esac
  role="${a%%:*}"
  [ -n "$role" ] || return 1
  case "$a" in *:*) [ -n "${a#*:}" ] || return 1 ;; esac
  # The MEMBERSHIP half. Empty set = could not read = accept; see _pr_role_set's policy.
  set_="$(_pr_role_set)"
  [ -n "$set_" ] || return 0
  case "|$set_|" in *"|$role|"*) return 0 ;; esac
  return 1
}

# kit_progress <actor> <class> <description> [key=value …]
#
# ALWAYS RETURNS 0. See the header: an unsubscribed record may be omitted, so a
# failure to write is not a failure of the caller's work.
kit_progress() {
  local actor="$1" class="$2" desc="$3"; shift 3 2>/dev/null || true

  # THE CLASS IS CLOSED, and an unknown one is NOT dropped — it is written as `info`
  # with the offered value carried in an optional field. Dropping the record would
  # make a typo in a caller look like work that never happened, which is the one
  # reading this format must never produce.
  local extra=""
  case "$class" in
    status|info|warning|error) ;;
    *) extra="declared-class=$(_pr_tok "$class")"; class="info" ;;
  esac

  # THE ACTOR HAS A SHAPE, AND IT IS ENFORCED THE SAME WAY — written, never refused and
  # never dropped. Same reason, one column over: an actor a reader cannot filter on is a
  # record that reads as work by nobody, and an actor that broke the caller would make this
  # library a dependency, which the header forbids absolutely.
  actor="$(_pr_clean "$actor")"
  if ! _pr_actor_ok "$actor"; then
    extra="declared-actor=$(_pr_tok "$actor")${extra:+ }${extra}"
    actor="unknown"
  fi

  local dir; dir="$(kit_progress_dir)"
  mkdir -p "$dir" 2>/dev/null || return 0
  [ -w "$dir" ] || return 0
  _pr_expire "$dir"

  local ts day
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || return 0
  day="${ts%%T*}"

  # THE CALLER'S EXTRAS, VERBATIM. `run=` is watched for on the way past — see below.
  #
  # VERBATIM MEANS VERBATIM, AND THE VALUE'S SHAPE IS THE CALLER'S OBLIGATION RATHER THAN
  # THIS WRITER'S. An extra's value must be ONE TOKEN — the extras field is read back by
  # splitting on spaces, so `step=13 of 13` reaches a reader as the key `step=13` plus two
  # bare tokens. The contract states that obligation (contracts/progress-record.md
  # § Reserved extra keys); this loop does NOT enforce it, and that is a decision rather
  # than an omission.
  #
  # WHY THERE IS NO MECHANISM HERE, when there is one for `declared-class=` and
  # `declared-actor=` two blocks up: those are keys THIS LIBRARY INVENTS, so it owes their
  # shape. An extra is the caller's own `key=value`. Running it through _pr_tok would
  # rewrite data the caller typed — the same overreach the actor validator refuses in
  # _pr_actor_ok above ("NORMALISING it would rewrite attribution the caller assigned"),
  # and the same defect as a writer that silently reshapes a preserved value. The library declined
  # ownership of caller-supplied values deliberately, and a documented obligation is the
  # correct instrument where the alternative is taking ownership back.
  #
  # SO A CALLER REMAINS FREE TO SPLIT THE FIELD, and that is accepted, not overlooked. An
  # unenforced obligation is weaker than a guard; it is the right trade only because the
  # guard would have to rewrite the caller's data to exist.
  local k run_given=0
  for k in "$@"; do
    [ -n "$k" ] || continue
    case "$k" in run=*) run_given=1 ;; esac
    extra="${extra}${extra:+ }$(_pr_clean "$k")"
  done

  # THE RUN ID — A DECLARED EXTRA, NEVER A FIFTH REQUIRED COLUMN. It groups an
  # orchestrator and the subagents it spawned, across every producer, within a day file
  # and across the two files a run spanning midnight lands in: a reader greps `run=<id>`.
  # It is an EXTRA because § 2's four-field envelope is what every reader must understand,
  # and a fifth column would oblige a reader that does not care about runs to learn it.
  #
  # EMPTY OR UNSET WRITES NOTHING — no `run=` key at all, not `run=` with an empty value.
  # An empty key is a column that looks answered and is not, and a reader filtering on
  # `run=` would collect every unrelated record that merely declared the key.
  #
  # AN EXPLICIT `run=` ARGUMENT WINS over the environment, and never produces two keys.
  # The environment is AMBIENT and inherited; an argument was typed at this call site for
  # this record. That is the precedence that makes "change the run id on the fly" mean what
  # it says — a caller re-runs under a new id by passing it, without disturbing an
  # environment its children also read.
  if [ "$run_given" -eq 0 ] && [ -n "${KIT_PROGRESS_RUN:-}" ]; then
    extra="${extra}${extra:+ }run=$(_pr_tok "$KIT_PROGRESS_RUN")"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$ts" "$actor" "$class" "$(_pr_clean "$desc")" "$extra" \
    >> "$dir/$day.tsv" 2>/dev/null
  return 0
}

# kit_progress_tail [n] — the operator's read. THIS IS THE NO-WATCHER HALF: it is
# what makes the records useful to a person with nothing running but a terminal, and
# it is why this library is not a dashboard feed wearing additive clothes.
kit_progress_tail() {
  local n="${1:-20}" dir; dir="$(kit_progress_dir)"
  [ -d "$dir" ] || { echo "no progress records under $dir"; return 0; }
  # shellcheck disable=SC2012  # ls is fine here: the names are ISO dates, never odd.
  cat $(ls "$dir"/*.tsv 2>/dev/null | sort) 2>/dev/null | tail -n "$n" \
    | awk -F'\t' '{printf "%s  %-22s %-7s %s%s\n", $1, $2, $3, $4, ($5 != "" ? "  [" $5 "]" : "")}'
  return 0
}
