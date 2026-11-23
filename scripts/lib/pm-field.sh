#!/usr/bin/env bash
# KIT-CLASS: KIT — the ONE `PROJECT.md` marker-line field reader and the ONE blank test for its
# value. See process/EXTRACTION.md.
#
# scripts/ask.sh and check-board.sh arm [g] both read the `principal:` and channel lines through
# kit_pm_field, and both judge whether a value is filled through kit_pm_blank, so the two can
# never disagree about either. The channel's path is read from that line by kit_pm_channel_token,
# and kit_pm_channel_dir judges whether it is a directory; ask.sh, register-commit.sh and
# check-board.sh's answered-question arm share both, and kit_answer_present decides whether a
# question file holds an answer, so the two readers of an `**Answer` line cannot disagree.
#
# kit_pm_field <marker-regex> <file>
#   Reads the FIRST line in <file> matching <marker-regex> (an awk ERE, the same shape both
#   callers already passed: `` `principal:` `` or `\*\*Their channel:\*\*` ) and echoes the
#   value that follows the marker on that line:
#     - the first backtick-delimited span after the marker, if there is one;
#     - otherwise the REST OF THE LINE, with leading and trailing Markdown emphasis (`*`, `_`)
#       and whitespace stripped — a bare fill (`PM`, `nobody`) is read as that text, and a bare
#       path keeps its own underscores.
#   Echoes nothing if the marker is not found.
kit_pm_field() {
  awk -v marker="$1" '
    match($0, marker) {
      rest = substr($0, RSTART + RLENGTH)
      if (match(rest, /`[^`]*`/)) {
        print substr(rest, RSTART + 1, RLENGTH - 2)
        exit
      }
      v = rest
      gsub(/^[*_ \t]+/, "", v)
      gsub(/[*_ \t]+$/, "", v)
      print v
      exit
    }' "$2"
}

# kit_answer_present [file]
#   Prints 1 when a question file (stdin when no file is given) carries an answer: a line opening
#   `**Answer` AFTER the file's own `**To answer:**` line, the one scripts/ask.sh writes below the
#   question. Text above that line is the question's, and anything quoted into a question can open a
#   line the same way, so only the block added below it counts. The last such line is the file's own
#   (ask.sh writes it last). Prints nothing otherwise, and nothing for a file with no such line.
kit_answer_present() {
  awk '
    /^\*\*To answer:\*\*/ { open = 1; found = 0; next }
    open && /^\*\*Answer/ { found = 1 }
    END { if (found) print 1 }' ${1+"$1"}
}

# kit_pm_channel_token <channel-line-value>
#   Echoes the channel PATH a channel line (as kit_pm_field extracted it) names. The channel line is
#   prose ("dev/questions/, one dated file per question"): the FIRST token that looks like a
#   repo-relative path is the channel, else the line's first word; a trailing comma is dropped. A
#   trailing `/` means a directory; a bare name is a directory only if it exists (kit_pm_channel_dir),
#   else a file. scripts/ask.sh (which writes there)
#   and check-board.sh's answered-question arm (which reads there) both call this, so the two
#   cannot name different places.
kit_pm_channel_token() {
  local tok
  tok="$(printf '%s' "$1" | awk '{ for (i=1;i<=NF;i++) if ($i ~ /^[A-Za-z0-9._-]+\/?([A-Za-z0-9._\/-]*)?$/ && $i ~ /\//) { print $i; exit } }')"
  [ -n "$tok" ] || tok="$(printf '%s' "$1" | awk '{print $1}')"
  printf '%s\n' "${tok%,}"
}

# kit_pm_channel_dir <root> <token>
#   The ONE reading of whether a channel token is a directory, for every caller. On a directory it
#   prints the repo-relative path without a trailing `/` and returns 0: a token ending in `/`, or a
#   bare token that names an existing directory under <root>. Otherwise it prints a reason on stdout
#   and returns 1 when the token is not a path inside the repository (absolute, or with `..`), or 2
#   when it is a file: one file holding several questions.
kit_pm_channel_dir() {
  local root="$1" tok="$2"
  case "$tok" in
    /*|..|../*|*/../*|*/..) printf 'the declared channel (%s) is not a path inside the repository\n' "$tok"; return 1 ;;   # return-class: predicate
    */) printf '%s\n' "${tok%/}"; return 0 ;;
  esac
  if [ -d "$root/$tok" ]; then printf '%s\n' "$tok"; return 0; fi
  printf 'the channel (%s) is one file, or a directory that is not here: no answer in it can be tied to one question\n' "$tok"
  return 2   # return-class: predicate
}

# kit_pm_blank <value> — status 0 if <value> (as kit_pm_field extracted it) carries no usable
# content, 1 otherwise. Blank is:
#   - empty, or empty after trimming leading/trailing whitespace;
#   - the shipped `<angle-bracket>` span, whole value;
#   - a placeholder a project left instead of answering: `TBD` (case-insensitive, the whole
#     value), `[fill in…]` / `[fill in: …]` (case-insensitive, bracketed), `{{ … }}`, or nothing but
#     underscores.
# This is a SHAPE test, not a truth test: a plausible non-answer ("the team", "someone") is not
# caught, and is not this function's job.
kit_pm_blank() {
  local v="$1" lower
  v="${v#"${v%%[![:space:]]*}"}"   # trim leading whitespace
  v="${v%"${v##*[![:space:]]}"}"   # trim trailing whitespace
  [ -n "$v" ] || return 0
  case "$v" in
    '<'[a-z]*'>') return 0 ;;
    '{{'*'}}') return 0 ;;
  esac
  case "$v" in
    *[!_]*) ;;
    *) return 0 ;;   # nothing but underscores (the empty case is caught above)
  esac
  lower="$(printf '%s' "$v" | tr 'A-Z' 'a-z')"
  case "$lower" in
    tbd) return 0 ;;
    '[fill in'*']') return 0 ;;
  esac
  return 1   # return-class: predicate
}
