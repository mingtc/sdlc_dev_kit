#!/usr/bin/env bash
# KIT-CLASS: KIT — the decision register's live/retired id resolution, the diff-derived
# touched-id set, and the one reader of a `[decision: ...]` CITATION. See process/EXTRACTION.md.
#
# ONE PARSER FOR "what does the register say", shared by check-board.sh arm [l] (declared
# reference integrity) and finish-pr.sh (the `forks:` landing precondition). Both read the same
# register(s) and must agree on what is live and what is retired; a second implementation is the
# one that drifts. The same reasoning covers "what does a citation name": check-board.sh's arms
# [l] and [r], and lib/qa-gate.sh's `forks:` check, all read the SAME marker through
# kit_decisions_cited below — two readers of one marker would disagree on what is cited.
#
# The reader folds Unicode dashes through lib/attrib-trailer.sh's kit_normalize_hyphens, loaded here
# so every caller reads identically. If it cannot load, this file stops defining anything: callers
# see their own "readers did not load" path rather than a reader that silently reads differently.
# shellcheck source=attrib-trailer.sh
. "$(dirname "${BASH_SOURCE[0]}")/attrib-trailer.sh" || return 1

# kit_registers_declared <check-board.sh path>
#   Echoes check-board.sh's declared `REGISTERS=` value verbatim — one `<path>|<mark>|<shape>`
#   record per line, exactly as arm [l] reads it. THE ONE DECLARATION, never re-typed: a caller
#   that hard-codes a register path or shape disagrees with check-board.sh the day a project
#   declares its own. Reads the single-quoted value even where it spans several source lines (one
#   physical line per added record, as the declaration's own comment invites); prints nothing,
#   and returns 1, if no `REGISTERS=` assignment is found — a caller must refuse on that, never
#   fall back to a guessed path.
kit_registers_declared() {
  kit_declared_value "$1" REGISTERS
}

# kit_declared_value <check-board.sh path> <NAME>
#   Echoes the value of the single-quoted declaration `NAME='...'` verbatim, even where it spans
#   several source lines; prints nothing and returns 1 if no such assignment is found. The file is
#   read, never sourced.
kit_declared_value() {
  local file="$1" name="$2"
  [ -f "$file" ] || return 1
  awk -v n="$name" '
    BEGIN { head = "^" n "=\047" }
    $0 ~ head { f=1 }
    f {
      l=$0
      sub(head, "", l)
      if (l ~ /\047/) { sub(/\047.*$/, "", l); buf = (buf=="" ? l : buf "\n" l); print buf; found=1; exit }
      buf = (buf=="" ? l : buf "\n" l)
      next
    }
    END { if (!found) exit 1 }
  ' "$file" 2>/dev/null
}

# kit_decision_register_live <file> <heading-mark> <id-shape>
#   Echoes, one per line, every id matching <heading-mark><id-shape> at line start. <heading-mark>
#   and <id-shape> are the register's own declared shape (REGISTERS in check-board.sh), never
#   re-typed by a caller.
# ALWAYS RETURNS 0: "no id found" is a legitimate answer (an empty or day-one-blank register),
# never a failure a `pipefail` caller should abort on.
kit_decision_register_live() {
  local file="$1" mark="$2" shape="$3"
  [ -f "$file" ] || return 0
  grep -oE "^${mark}${shape}" "$file" 2>/dev/null | sed "s|^${mark}||" || true
}

# kit_decision_register_retired <file> <id-shape>
#   Echoes, one per line, every id retired under "## Retired ids" — HTML comment spans stripped
#   first (the shipped register names example ids inside one), anchored on the row's FIRST
#   backticked id (a retired row names its live successor in the same sentence).
# ALWAYS RETURNS 0 — see kit_decision_register_live.
kit_decision_register_retired() {
  local file="$1" shape="$2"
  [ -f "$file" ] || return 0
  sed -n '/^## Retired ids/,/^## /{ /^## Retired ids/d; /^## /d; p; }' "$file" 2>/dev/null \
    | awk 'BEGIN{c=0} { line=$0
            while (1) {
              if (c) { i=index(line,"-->"); if (!i) { line=""; break }
                       line=substr(line,i+3); c=0; continue }
              i=index(line,"<!--"); if (!i) break
              rest=substr(line,i+4); line=substr(line,1,i-1)
              j=index(rest,"-->")
              if (j) { line=line substr(rest,j+3); continue }
              c=1; break }
            print line }' \
    | grep -oE "^[[:space:]]*\`${shape}\`" \
    | grep -oE "$shape" || true
}

# kit_decisions_touched_by_diff <repo> <old-rev> <new-rev> <path> <heading-mark>
#   Echoes, one per line, every id whose "<heading-mark><id>" entry SPAN in <new-rev>'s copy of
#   <path> overlaps a hunk of `git diff <old-rev>...<new-rev> -- <path>`. Catches both a NEW entry
#   (its heading line is itself added) and an EXISTING entry CHANGED without its heading line
#   moving (found by span, not by literal id text on an added line — an id rarely repeats inside
#   its own body).
#   A hunk that only reaches an entry's trailing blank line can flag that entry too (the span test
#   is deliberately >=, not exact) — conservative in the direction of a false REFUSAL rather than a
#   missed one, which is the correct bias for a landing precondition. An entry's span STOPS at the
#   next section heading ("## ") even where no further "### D-NN" follows it — otherwise the LAST
#   entry in a section reads as reaching every unrelated line to the next id, including a whole
#   following section's own insertions.
kit_decisions_touched_by_diff() {
  local repo="$1" old="$2" new="$3" path="$4" mark="$5"
  local branch_copy spans
  branch_copy="$(git -C "$repo" show "${new}:${path}" 2>/dev/null)" || return 0
  [ -n "$branch_copy" ] || return 0
  # ONE PASS builds each entry's SPAN "<id> <start> <end>" directly: an entry's end is the line
  # before whichever comes first, the next "<mark><id>" heading or the next "## " section
  # boundary — so the LAST entry in a section does not read as reaching every unrelated line
  # up to the next id, possibly across a whole following section's own insertions.
  spans="$(printf '%s\n' "$branch_copy" | awk -v m="$mark" '
    index($0,m)==1 {
      if (cur != "") print cur, start, NR-1
      id=substr($0,length(m)+1); sub(/[[:space:]].*$/,"",id)
      cur=id; start=NR; next
    }
    /^## / {
      if (cur != "") { print cur, start, NR-1; cur="" }
    }
    END { if (cur != "") print cur, start, NR }
  ')"
  [ -n "$spans" ] || return 0

  # A branch with NO hunk in <path> is the common case (most landings touch no register entry
  # at all), and under the caller's `pipefail` an empty `grep '^@@'` — nothing to loop over — must
  # not read as this FUNCTION failing: the `while` still ran zero times, correctly. `|| true`
  # guards the whole pipeline, including `sort -u` on empty input.
  { git -C "$repo" diff --unified=0 "${old}...${new}" -- "$path" 2>/dev/null | grep '^@@' | while IFS= read -r hunk; do
      local cd_part c d end
      cd_part=$(printf '%s' "$hunk" | sed -E 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+(,[0-9]+)?).*/\2/')
      c=${cd_part%%,*}
      if [ "$cd_part" = "$c" ]; then d=1; else d=${cd_part#*,}; [ "$d" -eq 0 ] && d=1; fi
      end=$(( c + d - 1 ))
      printf '%s\n' "$spans" | awk -v lo="$c" -v hi="$end" '$2 <= hi && $3 >= lo { print $1 }'
    done | sort -u; } || true
}

# kit_decisions_cited <file> <id-shape>
#   Echoes, one per line, every id a '[decision: ...]' MARKER in <file> cites — never a bare
#   mention: the brackets and the label are what make a sentence a citation rather than prose
#   about one. <id-shape> is the register's own declared id pattern (e.g. 'D-[0-9]+', REGISTERS'
#   third field) — never re-typed by a caller. The id's literal letter+hyphen head (e.g. 'D-') is
#   derived FROM <id-shape> here (everything before its first regex metacharacter), so a caller
#   passes the one string check-board.sh already declares, not a second copy of its head.
#
#   Recognises, inside one pair of brackets: the 'decision' label in any case ('[Decision: ...]'
#   as freely as '[decision: ...]'); the colon's space OPTIONAL and reusable to any width
#   ('[decision:D-01]' and '[decision:   D-01]' both cite); a comma-separated LIST
#   ('[decision: D-05, D-93]', every id named); and a '..'-joined RANGE between two ids sharing
#   one prefix ('[decision: D-05..D-07]', citing D-05 through D-07 inclusive) — a Unicode dash in
#   either id (en/em/figure/minus, the same set lib/attrib-trailer.sh folds) is read as the plain
#   '-' first, so a pasted 'D–05' cites the same id as a typed 'D-05'. '..' itself is the ONLY
#   range separator: an id's OWN hyphen is part of <id-shape>, so a single '-' between two ids is
#   indistinguishable from one id's own prefix and is read as prose, not a range. Trailing spaces
#   before the closing bracket are tolerated.
#
#   The kit's own illustrative marker, '[decision: D-NN]' (a literal 'NN'), never matches: 'NN'
#   is not digits, so it fails <id-shape> the same way a real typo would, on every surface this
#   reads. A bare mention with no brackets ('per D-NN') is not a citation and is never returned —
#   a caller that wants that population counts it separately, against this function's count.
# ALWAYS RETURNS 0 — see kit_decision_register_live.
kit_decisions_cited() {
  local file="$1" shape="$2"
  [ -f "$file" ] || return 0
  # The id's literal head, for the range reader below: everything in <id-shape> before its first
  # regex metacharacter ('D-[0-9]+' -> 'D-'). A shape with no metacharacter at all (a bare
  # literal id, no register ever declares one) heads itself; harmless either way, since the
  # range arm only fires when BOTH bounds already matched the full <id-shape>.
  local prefix
  prefix="$(printf '%s' "$shape" | sed -E 's/[].[^$*+?(){|\\].*$//')"
  local marker='\[[Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn][[:space:]]*:[[:space:]]*[^]]*[[:space:]]*\]'
  local _dc_hit _dc_inner _dc_tok _dc_lo _dc_hi _dc_lo_n _dc_hi_n _dc_w _dc_i _dc_oifs
  # The OUTER loop is the only one reading a pipe's stdin: a `while read` nested inside another
  # `while read`'s own piped body shares the same fd 0 in this shell and silently drops lines
  # (the inner loop must never itself be fed by `|`). Each marker's inner
  # list is split with `set --` under a scoped IFS instead, never a second pipe.
  while IFS= read -r _dc_hit; do
    # Strip the label and the brackets, leaving only what is between ':' and ']'.
    _dc_inner="${_dc_hit#*:}"; _dc_inner="${_dc_inner%]}"
    _dc_oifs="$IFS"; IFS=','; set -- $_dc_inner; IFS="$_dc_oifs"
    for _dc_tok in "$@"; do
      _dc_tok="$(printf '%s' "$_dc_tok" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      case "$_dc_tok" in
        *..*)
          _dc_lo="${_dc_tok%%..*}"; _dc_hi="${_dc_tok##*..}"
          printf '%s' "$_dc_lo" | grep -qE "^${shape}\$" || continue
          printf '%s' "$_dc_hi" | grep -qE "^${shape}\$" || continue
          _dc_lo_n="${_dc_lo#"$prefix"}"; _dc_hi_n="${_dc_hi#"$prefix"}"
          _dc_w=${#_dc_lo_n}
          case "$_dc_lo_n$_dc_hi_n" in *[!0-9]*) continue ;; esac
          [ "$((10#$_dc_lo_n))" -le "$((10#$_dc_hi_n))" ] || continue
          for ((_dc_i = 10#$_dc_lo_n; _dc_i <= 10#$_dc_hi_n; _dc_i++)); do
            printf '%s%0*d\n' "$prefix" "$_dc_w" "$_dc_i"
          done
          ;;
        *)
          printf '%s' "$_dc_tok" | grep -qE "^${shape}\$" && printf '%s\n' "$_dc_tok"
          ;;
      esac
    done
  done < <(
    grep -IaoE "$marker" "$file" 2>/dev/null | kit_normalize_hyphens
  )
  return 0
}
