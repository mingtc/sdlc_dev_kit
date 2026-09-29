#!/usr/bin/env bash
# KIT-CLASS: KIT — the decision register's live/retired id resolution, and the diff-derived
# touched-id set. See process/EXTRACTION.md.
#
# ONE PARSER FOR "what does the register say", shared by check-board.sh arm [l] (declared
# reference integrity) and finish-pr.sh (the `forks:` landing precondition). Both read the same
# register(s) and must agree on what is live and what is retired; a second implementation is the
# one that drifts.
#
# kit_registers_declared <check-board.sh path>
#   Echoes check-board.sh's declared `REGISTERS=` value verbatim — one `<path>|<mark>|<shape>`
#   record per line, exactly as arm [l] reads it. THE ONE DECLARATION, never re-typed: a caller
#   that hard-codes a register path or shape disagrees with check-board.sh the day a project
#   declares its own. Reads the single-quoted value even where it spans several source lines (one
#   physical line per added record, as the declaration's own comment invites); prints nothing,
#   and returns 1, if no `REGISTERS=` assignment is found — a caller must refuse on that, never
#   fall back to a guessed path.
kit_registers_declared() {
  local file="$1"
  [ -f "$file" ] || return 1
  awk '
    /^REGISTERS='"'"'/ { f=1 }
    f {
      l=$0
      sub(/^REGISTERS='"'"'/, "", l)
      if (l ~ /'"'"'/) { sub(/'"'"'.*$/, "", l); buf = (buf=="" ? l : buf "\n" l); print buf; found=1; exit }
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
