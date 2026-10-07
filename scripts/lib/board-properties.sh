#!/usr/bin/env bash
# KIT-CLASS: KIT — the six board-property checks, ONE implementation each, called by
# check-board.sh (a report) and by lib/qa-gate.sh's kit_board_property_check (a landing refusal).
# See process/EXTRACTION.md.
#
# THE PROPERTIES, one function each, named by the check-board.sh arm that reports them:
#   kit_bp_ids                [d]  frontmatter id integrity, and the declared registers' id integrity
#   kit_bp_blocks             [i]  blocks:/blocked_by: symmetry
#   kit_bp_citations          [l]  every cited register id resolves to a live entry, and none is retired
#   kit_bp_corpus             [p]  CORPUS.md forward-reference integrity
#   kit_bp_register_shape     [q]  every register entry is exactly three fields; a reopened entry is stamped
#   kit_bp_reverse_coverage   [r]  every live, non-exempt register entry is cited by a PRD
# A second copy of any of them is the one that disagrees with the first, so a fix lands here once.
#
# THE CALLER DECLARES THE OPERANDS, as globals: STATUS_FOLDERS ISSUE_ID_KEY ISSUE_ID_PATTERN
# FRONTMATTER_SCAN_LINES REGISTERS CITATION_EXCLUDE PRD_SURFACE CROSS_CUTTING_MARKER CORPUS_FILE.
# check-board.sh declares them; a landing reads them from the TRUNK's copy of check-board.sh through
# kit_bp_load_declarations, never from the branch it judges.
#
# EACH FUNCTION takes the tree to read as its first argument (a directory), prints the arm's lines
# on stdout, and records every finding through _bp_hit: it counts it in KIT_BP_NHITS and, when
# KIT_BP_HITS_FILE is set, appends one `<keys><TAB><text>` line to that file. A KEY names the
# finding independent of line numbers, so the same finding on two trees carries the same key; a
# finding with several parts carries several keys. The functions neither set a verdict nor exit.
# They are written to run with `set -e` off (a caller under it runs them in a subshell).
#
# If decision-register.sh cannot load, this file stops defining anything: a caller sees its own
# "did not load" path rather than a reader that silently reads differently.
# shellcheck source=decision-register.sh
. "$(dirname "${BASH_SOURCE[0]}")/decision-register.sh" || return 1

KIT_BP_US=$'\037'
KIT_BP_NHITS=0
KIT_BP_HITS_FILE=""
KIT_BP_CARD_FILES=()
KIT_BP_CARD_EMPTY=""
KIT_BP_COLS_READ=0
# When non-empty, kit_bp_citations reads only these tree-relative paths (one per line).
KIT_BP_ONLY=""

_bp_reset() { KIT_BP_NHITS=0; }

# _bp_hit <text> <key>... — print one finding line and record it.
_bp_hit() {
  local text="$1" keys="" k
  shift
  # A tab would split the record the landing reads back; keys and text never carry one.
  text="${text//$'\t'/ }"
  for k in "$@"; do k="${k//$'\t'/ }"; keys="${keys:+$keys$KIT_BP_US}$k"; done
  KIT_BP_NHITS=$((KIT_BP_NHITS+1))
  if [ -n "${KIT_BP_HITS_FILE:-}" ]; then printf '%s\t%s\n' "$keys" "$text" >> "$KIT_BP_HITS_FILE"; fi
  printf '%s\n' "$text"
}

# kit_bp_load_declarations <check-board.sh text file>
#   Sets every operand above from the file's own declarations, read by their fixed shapes and never
#   sourced. Call it directly, never inside $( ): the operands are globals. Returns 1 if any is
#   missing, naming them in KIT_BP_MISSING.
KIT_BP_MISSING=""
kit_bp_load_declarations() {
  local f="$1" n v missing=""
  KIT_BP_MISSING=""
  [ -f "$f" ] || { KIT_BP_MISSING="the declarations file"; return 1; }
  for n in STATUS_FOLDERS ISSUE_ID_KEY ISSUE_ID_PATTERN REGISTERS CITATION_EXCLUDE PRD_SURFACE CROSS_CUTTING_MARKER; do
    v="$(kit_declared_value "$f" "$n")" || v=""
    [ -n "$v" ] || { missing="${missing:+$missing }$n"; continue; }
    printf -v "$n" '%s' "$v"
  done
  FRONTMATTER_SCAN_LINES="$(sed -n 's/^FRONTMATTER_SCAN_LINES=\([0-9][0-9]*\).*/\1/p' "$f" | head -1)"
  [ -n "$FRONTMATTER_SCAN_LINES" ] || missing="${missing:+$missing }FRONTMATTER_SCAN_LINES"
  CORPUS_FILE="$(sed -n 's/^CORPUS_FILE="\${CORPUS_FILE:-\([^}]*\)}".*/\1/p' "$f" | head -1)"
  [ -n "$CORPUS_FILE" ] || missing="${missing:+$missing }CORPUS_FILE"
  if [ -n "$missing" ]; then KIT_BP_MISSING="$missing"; return 1; fi
  return 0
}

# kit_bp_card_files <tree> — the board's cards: every non-empty *.md directly inside each
# STATUS_FOLDERS column. Sets KIT_BP_CARD_FILES, KIT_BP_CARD_EMPTY (newline list of
# "<column>/<file>"), KIT_BP_COLS_READ (columns that exist).
kit_bp_card_files() {
  local tree="$1" folder d_dir f
  local -a cols
  KIT_BP_CARD_FILES=(); KIT_BP_CARD_EMPTY=""; KIT_BP_COLS_READ=0
  IFS='|' read -r -a cols <<< "$STATUS_FOLDERS"
  for folder in "${cols[@]}"; do
    d_dir="$tree/progress/$folder"
    [ -d "$d_dir" ] || continue
    KIT_BP_COLS_READ=$((KIT_BP_COLS_READ+1))
    for f in "$d_dir"/*.md; do
      [ -e "$f" ] || continue
      if [ -s "$f" ]; then
        KIT_BP_CARD_FILES+=("$f")
      else
        KIT_BP_CARD_EMPTY="${KIT_BP_CARD_EMPTY}${folder}/$(basename "$f")"$'\n'
      fi
    done
  done
}

# kit_bp_registers_present <tree> — the declared register paths that exist in <tree>, one per line.
kit_bp_registers_present() {
  local tree="$1" path mark shape
  while IFS='|' read -r path mark shape; do
    [ -n "$path" ] || continue
    [ -f "$tree/$path" ] && printf '%s\n' "$path"
  done <<< "$(printf '%s\n' "$REGISTERS")"
  return 0
}

# ── [d] Frontmatter id integrity ─────────────────────────────────────────────
# Every column in STATUS_FOLDERS (done/ included: a new mint can collide with an archived issue).
# One awk pass reports a DUPLICATE id, an id that DISAGREES with its filename prefix, a MISSING or
# MALFORMED id. Read from the frontmatter block only, never a whole-file grep: an id quoted in
# prose or an Activity line is not a declaration. A finding, never a crash. Then the same
# invariant for the declared registers: two legs minting one id in different sections of an
# append-only register merge with no textual conflict, so only a check sees it.
kit_bp_ids() {
  local tree="$1" f d_out dk dt
  local reg_path reg_mark reg_shape reg_file reg_ids reg_total reg_distinct reg_max reg_dupes
  local reg_read=0 reg_skipped=0 d_reg_note rk dupe e
  local -a rkeys
  _bp_reset
  kit_bp_card_files "$tree"
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    _bp_hit "    ⚠ progress/$e: empty file — it carries no ${ISSUE_ID_KEY}: at all; restore it or remove it" "d:empty:progress/$e"
  done <<< "$KIT_BP_CARD_EMPTY"
  d_out=""
  if [ "${#KIT_BP_CARD_FILES[@]}" -gt 0 ]; then
    d_out="$(awk -v key="$ISSUE_ID_KEY" -v pat="$ISSUE_ID_PATTERN" -v scan="$FRONTMATTER_SCAN_LINES" \
                 -v root="$tree/" -v dq='"' -v sq="'" '
      function short(p) { s = p; sub("^" root, "", s); return s }
      FNR == 1 { n++; path[n] = FILENAME; val[n] = ""; inf = 0; closed = 0; got = 0 }
      # The OPENING fence: the first bare `---` within the first `scan` lines. It is
      # deliberately not required on line 1: a card minted from a template carries an HTML
      # comment above it.
      !closed && !inf && FNR <= scan && /^---[[:space:]]*$/ { inf = 1; next }
      inf && /^---[[:space:]]*$/ { inf = 0; closed = 1; next }
      inf && !got && $0 ~ ("^" key ":") {
        v = $0
        sub("^" key ":[[:space:]]*", "", v)
        sub(/[[:space:]]*#.*$/, "", v)        # strip an inline frontmatter comment
        gsub(dq, "", v); gsub(sq, "", v)      # and any quoting around the value
        sub(/[[:space:]]+$/, "", v)
        val[n] = v; got = 1
        next
      }
      END {
        for (i = 1; i <= n; i++) {
          base = path[i]; sub(/.*\//, "", base)
          fid = ""
          if (match(base, "^" pat)) fid = substr(base, 1, RLENGTH)
          v = val[i]
          if (v == "") {
            printf "d:noid:%s\t    ⚠ %s: no %s: line in its frontmatter block — every id-based lookup (git log --grep, move-issue.sh, the Activity trail) keys on it; add it, matching the filename\n", short(path[i]), short(path[i]), key
            continue
          }
          if (v !~ ("^" pat "$")) {
            printf "d:malformed:%s:%s\t    ⚠ %s: malformed %s: %s — expected the %s shape; correct it to match the filename\n", short(path[i]), v, short(path[i]), key, v, pat
            continue
          }
          if (fid != "" && v != fid) {
            printf "d:disagree:%s\t    ⚠ %s: frontmatter %s: %s DISAGREES with its filename prefix %s — one of the two is wrong; make them match (rename the file, or correct the frontmatter — whichever is the stray)\n", short(path[i]), short(path[i]), key, v, fid
          }
          seen[v] = seen[v] ", " short(path[i])
          count[v]++
          order[++m] = v
        }
        for (j = 1; j <= m; j++) {
          v = order[j]
          if (count[v] > 1 && !reported[v]) {
            reported[v] = 1
            files = seen[v]; sub(/^, /, "", files)
            printf "d:dup:%s:%s\t    ⚠ DUPLICATE %s: %s is carried by %d files: %s — renumber the LATER mint (./scripts/next-id.sh gives the next free number) and rename its file, branch and Activity trail to match\n", v, files, key, v, count[v], files
          }
        }
      }
    ' "${KIT_BP_CARD_FILES[@]}" 2>/dev/null)"
  fi
  if [ -n "$d_out" ]; then
    while IFS=$'\t' read -r dk dt; do
      [ -n "$dk" ] || continue
      _bp_hit "$dt" "$dk"
    done <<< "$d_out"
  fi

  # The highest id is computed ORDER-INDEPENDENTLY (a register grouped by section puts later ids
  # above earlier ones, so `tail -1` is not the max): mint from the printed value. An absent
  # register SKIPS with its reason.
  while IFS='|' read -r reg_path reg_mark reg_shape; do
    [ -n "$reg_path" ] || continue
    reg_file="$tree/$reg_path"
    if [ ! -f "$reg_file" ]; then
      echo "    $reg_path: not present  (skipped — this project keeps no register there)"
      reg_skipped=$((reg_skipped+1)); continue
    fi
    # Every id in the file, in the order the file happens to hold them.
    reg_ids="$(grep -oE "^${reg_mark}${reg_shape}" "$reg_file" 2>/dev/null | sed "s|^${reg_mark}||" || true)"
    if [ -z "$reg_ids" ]; then
      # "0 entry headings" must be falsifiable: look for the id shape anywhere and say which.
      if grep -qE "$reg_shape" "$reg_file" 2>/dev/null; then
        _bp_hit "    ⚠ $reg_path: 0 '${reg_mark}${reg_shape}' entry headings, but the file DOES carry '${reg_shape}' elsewhere — the entry SHAPE has drifted off its declared form, so every reading below (duplicates, the highest id) covers nothing while reporting nothing wrong" "d:regshape:$reg_path"
      else
        # Stated limit: an id written without its declared separator (D01 for D-NN) matches
        # neither look; closing it needs an id-prefix field in REGISTERS.
        echo "    $reg_path: 0 '${reg_mark}${reg_shape}' entry headings, and no line anywhere in the file carries '${reg_shape}' either  (nothing to check yet — an id written without its declared separator would still be invisible here)"
      fi
      continue
    fi
    reg_total="$(printf '%s\n' "$reg_ids" | grep -c .)"
    reg_distinct="$(printf '%s\n' "$reg_ids" | sort -u | grep -c .)"
    # ORDER-INDEPENDENT max: a numeric sort on the digits. `sed -E`, not a BSD-hostile `\+`.
    reg_max="$(printf '%s\n' "$reg_ids" | sed -E 's/[^0-9]*([0-9]+)$/\1/' | sort -n | tail -1)"
    reg_dupes="$(printf '%s\n' "$reg_ids" | sort | uniq -d | tr '\n' ' ' | sed 's/ $//')"
    if [ -n "$reg_dupes" ]; then
      rkeys=()
      for dupe in $reg_dupes; do rkeys+=("d:regdup:$reg_path:$dupe"); done
      _bp_hit "    ⚠ $reg_path: DUPLICATE id(s): $reg_dupes  — every reference to them is ambiguous; renumber the later one and its citations" "${rkeys[@]}"
    fi
    reg_read=$((reg_read+1))
    echo "    $reg_path: $reg_total entry heading(s), $reg_distinct distinct, highest id number $reg_max (max over ALL headings, not the file's last line)"
  done <<< "$(printf '%s\n' "$REGISTERS")"
  # The clearance names what it covered: a skipped register is never reported as distinct.
  if [ "$KIT_BP_NHITS" -eq 0 ]; then
    d_reg_note=""
    if   [ "$reg_read" -gt 0 ] && [ "$reg_skipped" -gt 0 ]; then d_reg_note="; ids distinct in the $reg_read register(s) read, $reg_skipped skipped"
    elif [ "$reg_read" -gt 0 ];                            then d_reg_note="; ids distinct in every declared register"
    elif [ "$reg_skipped" -gt 0 ];                         then d_reg_note="; NO register was read ($reg_skipped skipped) — this pass says nothing about them"
    fi
    echo "    ✓ none (every ${ISSUE_ID_KEY}: unique across the $KIT_BP_COLS_READ column(s) read and matching its filename${d_reg_note})"
  fi
  return 0
}

# ── [i] blocks: / blocked_by: symmetry ───────────────────────────────────────
# In both directions; each asymmetric pair fires once and names both cards (either may be the
# stray). A dangling reference is a different finding from an asymmetry and prints as one.
# The count line separates "nothing to check" from "checked, nothing wrong".
kit_bp_blocks() {
  local tree="$1" i_out line
  _bp_reset
  kit_bp_card_files "$tree"
  if [ "${#KIT_BP_CARD_FILES[@]}" -eq 0 ]; then
    echo "      – no issue file on the board  (skipped)"
    return 0
  fi
  i_out="$(awk -v scan="$FRONTMATTER_SCAN_LINES" '
    function flush_list(   n, i, parts) {
      # A flow list: [A, B] — or a single bare scalar.
      if (curval ~ /^\[/) {
        gsub(/^\[|\]$/, "", curval)
        n = split(curval, parts, /[[:space:]]*,[[:space:]]*/)
        for (i = 1; i <= n; i++) if (parts[i] != "") add(parts[i])
      } else if (curval != "") add(curval)
    }
    function add(t) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", t); if (t == "") return
                      DECL++; if (curkey == "blocks") B[id "\x1f" t] = 1; else BB[id "\x1f" t] = 1 }
    FNR == 1 { if (id != "") { flush_list(); CARD[id] = 1 }
               id = ""; curkey = ""; curval = ""; inlist = 0 }
    FNR > scan { next }
    {
      line = $0
      sub(/[[:space:]]*#.*$/, "", line)          # the templates END these lines with a # comment
      if (line ~ /^[[:space:]]*id:[[:space:]]*/) { v = line; sub(/^[[:space:]]*id:[[:space:]]*/, "", v)
                                                   gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); id = v }
      if (line ~ /^[[:space:]]*(blocks|blocked_by):/) {
        flush_list()
        curkey = (line ~ /^[[:space:]]*blocks:/) ? "blocks" : "blocked_by"
        curval = line; sub(/^[[:space:]]*(blocks|blocked_by):[[:space:]]*/, "", curval)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", curval)
        inlist = (curval == "")                  # empty value ⇒ a BLOCK-style list may follow
        if (!inlist) { flush_list(); curval = ""; curkey = "" }
        next
      }
      # A fence is not a list item: YAML requires a space after the dash.
      if (line ~ /^---[[:space:]]*$/) { inlist = 0; curkey = ""; curval = ""; next }
      if (inlist && line ~ /^[[:space:]]*-[[:space:]]+[^[:space:]]/) {
        v = line; sub(/^[[:space:]]*-[[:space:]]*/, "", v); add(v); next
      }
      if (inlist && line !~ /^[[:space:]]*$/) { inlist = 0; curkey = ""; curval = "" }
    }
    END {
      if (id != "") { flush_list(); CARD[id] = 1 }
      for (k in B)  { split(k, p, "\x1f")
                      if (!(p[2] in CARD))            print "    ⚠ " p[1] " declares blocks: [" p[2] "] — " p[2] " is not on this board (a DANGLING reference, not an asymmetry: check the id)"
                      else if (!((p[2] "\x1f" p[1]) in BB)) print "    ⚠ " p[1] " declares blocks: [" p[2] "] and " p[2] " does not declare blocked_by: [" p[1] "] — either card may be the stray one" }
      for (k in BB) { split(k, p, "\x1f")
                      if (!(p[2] in CARD))            print "    ⚠ " p[1] " declares blocked_by: [" p[2] "] — " p[2] " is not on this board (a DANGLING reference, not an asymmetry: check the id)"
                      else if (!((p[2] "\x1f" p[1]) in B))  print "    ⚠ " p[1] " declares blocked_by: [" p[2] "] and " p[2] " does not declare blocks: [" p[1] "] — either card may be the stray one" }
      n = 0; for (c in CARD) n++
      printf "    %d card(s) read, %d dependency declaration(s)\n", n, DECL
    }
  ' "${KIT_BP_CARD_FILES[@]}" 2>/dev/null || true)"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      *⚠*) _bp_hit "$line" "i:${line#"${line%%[![:space:]]*}"}" ;;
      *)   printf '%s\n' "$line" ;;
    esac
  done <<< "$i_out"
  return 0
}

# ── [l] Declared reference integrity ─────────────────────────────────────────
# Every register id cited ANYWHERE IN THE TREE, outside CITATION_EXCLUDE, resolves to a live entry,
# and no RETIRED id is cited. Two findings, printed separately: a dangling id and a retired one.
# Only text that DECLARES itself a citation is read (kit_decisions_cited); a bare id mention is
# counted, never read as a citation. Counts are printed so "nothing cited" and "all resolve" read
# differently, and the population (files read, files excluded) is printed before either verdict.
# Each exclusion in CITATION_EXCLUDE is a directory this project's own tooling writes, never the
# adopting project's own prose. With KIT_BP_ONLY set, only those paths are read.
kit_bp_citations() {
  local tree="$1" l_cites=0 l_files_read=0 l_live="" l_retired="" l_reg_named="" l_reg_read=0 l_shapes=""
  local lreg_path lreg_mark lreg_shape lreg_file l_live_n l_retired_n l_excl_named l_files lex lex_fixed
  local l_bare=0 cfile l_cids lshp cid l_stripped only
  _bp_reset
  while IFS='|' read -r lreg_path lreg_mark lreg_shape; do
    [ -n "$lreg_path" ] || continue
    lreg_file="$tree/$lreg_path"
    [ -f "$lreg_file" ] || continue
    l_reg_read=$((l_reg_read+1))
    l_reg_named="${l_reg_named:+$l_reg_named, }$lreg_path"
    # Every declared register's own id SHAPE, so a project with two registers of different id
    # shapes has citations of BOTH recognised below.
    l_shapes="$l_shapes
$lreg_shape"
    # § Retired ids are read through two filters (HTML comment spans stripped, then anchored on the
    # row's FIRST backticked id): lib/decision-register.sh, one parser shared with the forks check.
    l_live="$l_live
$(kit_decision_register_live "$lreg_file" "$lreg_mark" "$lreg_shape")"
    l_retired="$l_retired
$(kit_decision_register_retired "$lreg_file" "$lreg_shape")"
  done <<< "$(printf '%s\n' "$REGISTERS")"
  l_live="$(printf '%s\n' "$l_live" | grep -E '^D-[0-9]+$' | sort -u || true)"
  l_retired="$(printf '%s\n' "$l_retired" | grep -E '^D-[0-9]+$' | sort -u || true)"
  l_shapes="$(printf '%s\n' "$l_shapes" | awk 'NF' | sort -u || true)"
  l_live_n="$(printf '%s\n' "$l_live" | grep -c . || true)"
  l_retired_n="$(printf '%s\n' "$l_retired" | grep -c . || true)"

  echo "    register(s) read: $l_reg_named — $l_live_n live id(s), $l_retired_n retired id(s)"
  # THE POPULATION: every file under the tree, less CITATION_EXCLUDE's prefixes. Named here, not
  # just filtered silently — the printed exclusion list IS the arm's population statement.
  l_excl_named="$(printf '%s\n' "$CITATION_EXCLUDE" | grep -c . || true)"
  echo "    population: every file in this source except: $(printf '%s' "$CITATION_EXCLUDE" | tr '\n' ' ')($l_excl_named path(s) excluded — see CITATION_EXCLUDE's header for why each one is)"
  l_files="$(cd "$tree" 2>/dev/null && find . -type f 2>/dev/null | sed 's|^\./||' | sort || true)"
  while IFS= read -r lex; do
    [ -n "$lex" ] || continue
    # A literal PREFIX match on the exclusion path (fixed-string, anchored), never a substring or
    # a regex: "scripts/" must not also drop a "somescripts/" false hit, and the exclusion's own
    # literal "." must not act as a wildcard.
    lex_fixed="$(printf '%s' "$lex" | sed 's/[.[\*^$/]/\\&/g')"
    l_files="$(printf '%s\n' "$l_files" | grep -v -E "^${lex_fixed}" || true)"
  done <<< "$(printf '%s\n' "$CITATION_EXCLUDE")"
  if [ -n "$KIT_BP_ONLY" ]; then
    only="$KIT_BP_ONLY"
    l_files="$(printf '%s\n' "$l_files" | grep -Fxf <(printf '%s\n' "$only") || true)"
  fi
  while IFS= read -r cfile; do
    [ -n "$cfile" ] || continue
    l_files_read=$((l_files_read+1))
    # Every declared register's own id shape is read against this file — almost always one shape,
    # read once; each occurrence is counted once per shape it matches.
    l_cids=""
    while IFS= read -r lshp; do
      [ -n "$lshp" ] || continue
      l_cids="$l_cids
$(kit_decisions_cited "$tree/$cfile" "$lshp" || true)"
    done <<< "$l_shapes"
    while IFS= read -r cid; do
      [ -n "$cid" ] || continue
      l_cites=$((l_cites+1))
      if printf '%s\n' "$l_retired" | grep -qx "$cid"; then
        _bp_hit "    ⚠ $cfile cites $cid, which is RETIRED — a retired id is never reused, so this citation resolves to nothing; re-point it at the ruling that replaced it, or drop it" "l:retired:$cfile:$cid"
      elif ! printf '%s\n' "$l_live" | grep -qx "$cid"; then
        _bp_hit "    ⚠ $cfile cites $cid, which is NOT an entry in $l_reg_named — a dangling citation; fix the id, or add the ruling it names" "l:dangling:$cfile:$cid"
      fi
    done <<< "$(printf '%s\n' "$l_cids" | awk 'NF')"
    # A bare id mention OUTSIDE any '[decision: ...]' bracket is never read as a citation above.
    # Counted here by blanking every marker SPAN first (so an id already counted as a citation is
    # not counted twice), then matching the id shape(s) on what is left.
    l_stripped="$(grep -IaE . "$tree/$cfile" 2>/dev/null \
      | sed -E 's/\[[Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn][[:space:]]*:[[:space:]]*[^]]*[[:space:]]*\]//g' || true)"
    [ -n "$l_stripped" ] || continue
    while IFS= read -r lshp; do
      [ -n "$lshp" ] || continue
      l_bare=$((l_bare + $(printf '%s\n' "$l_stripped" | grep -oE "$lshp" 2>/dev/null | grep -c . || true)))
    done <<< "$l_shapes"
  done <<< "$l_files"
  if [ "$KIT_BP_NHITS" -eq 0 ]; then
    if [ "$l_cites" -eq 0 ]; then
      echo "    ✓ none ($l_files_read file(s) read, 0 citations found — nothing cites the register yet)"
    else
      echo "    ✓ none (all $l_cites citation(s) across $l_files_read file(s) resolve to a live entry; none cites a retired id)"
    fi
  fi
  echo "    population checked: $l_cites marker-form citation(s) against $l_bare bare id mention(s) outside a '[decision: ...]' marker, across $l_files_read file(s) — a bare mention is read, never silently counted as a citation"
  return 0
}

# ── [p] CORPUS forward-reference integrity ───────────────────────────────────
# requirements/CORPUS.md's manifest `Status` column. Each finding is single-ended (the marker or
# the row is wrong, no second party). Three findings, printed separately:
#   - a `forward-referenced (<ISSUE-ID>)` naming an id that is in NO column of STATUS_FOLDERS;
#   - a `forward-referenced (<ISSUE-ID>)` naming an id that HAS reached a landed column
#     (progress/done/ or progress/qa_complete/) while the row's own Status is still the marker;
#   - any `forward-referenced (SEED step <N>)` marker once day one has closed.
# <graduated> is `1` once day one has closed, `0` before, and empty when the caller cannot say
# (the SEED-step finding is then not evaluated). Cannot see a row left with NO marker at all.
kit_bp_corpus() {
  local tree="$1" graduated="${2:-}"
  local p_known="" p_landed="" pcol pf pbase p_rows prow pid p_seen=0
  _bp_reset
  if [ ! -f "$tree/$CORPUS_FILE" ]; then
    echo "      – $CORPUS_FILE not present  (skipped — no manifest to read)"
    return 0
  fi
  # Every id known to the board, from the same frontmatter reading arm [d] does (every column,
  # id: only, never a whole-file grep).
  kit_bp_card_files "$tree"
  if [ "${#KIT_BP_CARD_FILES[@]}" -gt 0 ]; then
    p_known="$(awk -v key="$ISSUE_ID_KEY" -v pat="$ISSUE_ID_PATTERN" -v scan="$FRONTMATTER_SCAN_LINES" '
      FNR == 1 { inf = 0; closed = 0; got = 0 }
      !closed && !inf && FNR <= scan && /^---[[:space:]]*$/ { inf = 1; next }
      inf && /^---[[:space:]]*$/ { inf = 0; closed = 1; next }
      inf && !got && $0 ~ ("^" key ":") {
        v = $0
        sub("^" key ":[[:space:]]*", "", v); sub(/[[:space:]]*#.*$/, "", v)
        gsub(/"/, "", v); gsub(/'"'"'/, "", v); sub(/[[:space:]]+$/, "", v)
        if (v ~ ("^" pat "$")) print v
        got = 1
      }
    ' "${KIT_BP_CARD_FILES[@]}" 2>/dev/null)"
  fi
  # The landed subset, by filename prefix — a landed card's filename already carries its id.
  for pcol in done qa_complete; do
    [ -d "$tree/progress/$pcol" ] || continue
    for pf in "$tree/progress/$pcol"/*.md; do
      [ -e "$pf" ] || continue
      pbase="$(basename "$pf")"
      if [[ "$pbase" =~ ^($ISSUE_ID_PATTERN)- ]]; then
        p_landed="$p_landed
${BASH_REMATCH[1]}"
      fi
    done
  done

  # Every manifest row's Status cell. A LEADING `|` makes awk's first -F'|' field empty, so Status
  # (the table's 3rd column) is $4. A table row only — the header and its `|---|` separator are
  # not data.
  p_rows="$(awk -F'|' '
    /^\|/ {
      if ($0 ~ /^\|[[:space:]]*-+/) next
      if (NF < 5) next
      status = $4
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      gsub(/`/, "", status)
      if (status ~ /^forward-referenced \(/) print status
    }
  ' "$tree/$CORPUS_FILE" 2>/dev/null)"

  while IFS= read -r prow; do
    [ -n "$prow" ] || continue
    p_seen=$((p_seen+1))
    if [[ "$prow" =~ ^forward-referenced\ \(SEED\ step\ [0-9]+\)$ ]]; then
      if [ "$graduated" = "1" ]; then
        _bp_hit "      ⚠ $prow — day one has closed (arm [g] reads graduation COMPLETE), and this SEED-step marker does not outlive day one (requirements/CORPUS.md's own rule); re-point it at an id, or remove the row" "p:seedstale:$prow"
      fi
      continue
    fi
    if [[ "$prow" =~ ^forward-referenced\ \(([A-Za-z]+-[0-9]+)\)$ ]]; then
      pid="${BASH_REMATCH[1]}"
      if ! printf '%s\n' "$p_known" | grep -qx "$pid"; then
        _bp_hit "      ⚠ $prow — $pid is not the frontmatter id: of any card in this source (every STATUS_FOLDERS column read) — a dangling forward reference; fix the id, or mint the work item it names" "p:dangling:$prow"
      elif printf '%s\n' "$p_landed" | grep -qx "$pid"; then
        _bp_hit "      ⚠ $prow — $pid has LANDED (progress/done/ or progress/qa_complete/) but its row's Status is still the forward-reference marker, not present — flip Status to present in the same change (requirements/CORPUS.md's own rule)" "p:landed:$prow"
      fi
      continue
    fi
    # A marker whose parenthesised content is neither shape: reported so a third form does not
    # pass silently as neither an id nor a step.
    _bp_hit "      ⚠ $prow — neither the <ISSUE-ID> form nor the SEED-step form; this marker's shape has drifted from requirements/CORPUS.md's own rule" "p:shape:$prow"
  done <<< "$p_rows"

  if [ "$p_seen" -eq 0 ]; then
    echo "      – 0 forward-referenced row(s) in this manifest  (nothing to resolve)"
  elif [ "$KIT_BP_NHITS" -eq 0 ]; then
    echo "      ✓ none ($p_seen forward-referenced row(s), every id resolves, none has landed unflipped, no stale SEED-step marker)"
  fi
  return 0
}

# _bp_entry_spans <file> <heading-mark> <id-shape> — "<id> <start> <end>" per entry: an entry ends
# at the next heading of the SAME shape, at any OTHER heading (any level), or at a
# bucket-separator `---` rule.
_bp_entry_spans() {
  awk -v m="$2" -v s="$3" '
    index($0,m)==1 {
      rest=substr($0,length(m)+1)
      if (rest ~ ("^" s "([[:space:]]|$)")) {
        if (cur != "") print cur, start, NR-1
        id=rest; sub(/[[:space:]].*$/,"",id)
        cur=id; start=NR; next
      }
      if (cur != "") { print cur, start, NR-1; cur="" }
      next
    }
    /^##[[:space:]]/ || /^---[[:space:]]*$/ {
      if (cur != "") { print cur, start, NR-1; cur="" }
    }
    END { if (cur != "") print cur, start, NR }
  ' "$1" 2>/dev/null
}

# ── [q] Declared-register entry shape ────────────────────────────────────────
# Every `D-NN` entry is exactly three things (`**Ruling.**`, `**Why.**`, `**Provenance.**`, each at
# the start of its own line, once, in that order); no OTHER bold-labelled line appears (what
# catches a stacked, dated amendment or a fourth field without counting them); Why is one
# paragraph; nothing follows Provenance's own paragraph. SEPARATELY: an entry cited by a LATER
# entry with reopen/supersede wording is reported if its own body carries no stamp word.
# A WITHDRAWN or WORKING DEFAULT entry states its token at the head of the Ruling field, in the
# same three fields, so a legally-shaped one reads clean.
# CANNOT SEE: an entry whose shape passes and whose current ruling is wrong; a reopen relationship
# in words the vocabulary does not cover; a stamp that is present but false.
kit_bp_register_shape() {
  local tree="$1" q_reg_read=0 q_entries=0 q_stamped="" q_reopeners=""
  local qreg_path qreg_mark qreg_shape qreg_file q_spans qid qstart qend qbody
  local r_line w_line p_line r_n w_n p_n q_missing q_extra q_n_extra q_why_body q_after q_trailing qtgt
  local q_reopen_hits=0 q_by q_ekeys eline efrag qby_one
  local -a qk
  _bp_reset
  while IFS='|' read -r qreg_path qreg_mark qreg_shape; do
    [ -n "$qreg_path" ] || continue
    qreg_file="$tree/$qreg_path"
    [ -f "$qreg_file" ] || continue
    q_reg_read=$((q_reg_read+1))
    q_spans="$(_bp_entry_spans "$qreg_file" "$qreg_mark" "$qreg_shape")"

    while read -r qid qstart qend; do
      [ -n "$qid" ] || continue
      q_entries=$((q_entries+1))
      qbody="$(sed -n "${qstart},${qend}p" "$qreg_file")"

      r_line="$(printf '%s\n' "$qbody" | grep -n '^\*\*Ruling\.\*\*' | head -1 | cut -d: -f1)"
      w_line="$(printf '%s\n' "$qbody" | grep -n '^\*\*Why\.\*\*' | head -1 | cut -d: -f1)"
      p_line="$(printf '%s\n' "$qbody" | grep -n '^\*\*Provenance\.\*\*' | head -1 | cut -d: -f1)"
      r_n="$(printf '%s\n' "$qbody" | grep -c '^\*\*Ruling\.\*\*' || true)"
      w_n="$(printf '%s\n' "$qbody" | grep -c '^\*\*Why\.\*\*' || true)"
      p_n="$(printf '%s\n' "$qbody" | grep -c '^\*\*Provenance\.\*\*' || true)"

      q_missing=""
      [ -n "$r_line" ] || q_missing="${q_missing:+$q_missing, }Ruling"
      [ -n "$w_line" ] || q_missing="${q_missing:+$q_missing, }Why"
      [ -n "$p_line" ] || q_missing="${q_missing:+$q_missing, }Provenance"
      if [ -n "$q_missing" ]; then
        _bp_hit "      ⚠ $qreg_path $qid — missing field(s): $q_missing" "q:$qreg_path:$qid:missing:$q_missing"
      fi
      if [ "${r_n:-0}" -gt 1 ] || [ "${w_n:-0}" -gt 1 ] || [ "${p_n:-0}" -gt 1 ]; then
        _bp_hit "      ⚠ $qreg_path $qid — a canonical field label appears more than once (Ruling×${r_n:-0}, Why×${w_n:-0}, Provenance×${p_n:-0})" "q:$qreg_path:$qid:labelrepeat"
      fi

      # Any OTHER line-start bold label besides the three canonical ones — a stacked amendment or
      # a fourth field, uncounted: one is already one too many.
      q_extra="$(printf '%s\n' "$qbody" | grep -noE '^\*\*[^*]+\.\*\*' \
                  | grep -Ev ':\*\*(Ruling|Why|Provenance)\.\*\*$' || true)"
      if [ -n "$q_extra" ]; then
        q_n_extra="$(printf '%s\n' "$q_extra" | grep -c . || true)"
        # One key per fragment, without its line number: adding a second amendment to an entry
        # that already has one is a new finding, and moving the entry is not.
        qk=()
        while IFS= read -r eline; do
          [ -n "$eline" ] || continue
          efrag="${eline#*:}"
          qk+=("q:$qreg_path:$qid:extra:$efrag")
        done <<< "$q_extra"
        _bp_hit "      ⚠ $qreg_path $qid — $q_n_extra extra dated/bold fragment(s) beyond the three fields, a running log rather than a single conclusion: $(printf '%s' "$q_extra" | tr '\n' ' ')" "${qk[@]}"
      fi

      # Why is one paragraph: no blank line between its label and Provenance's.
      if [ -n "$w_line" ] && [ -n "$p_line" ] && [ "$p_line" -gt "$w_line" ]; then
        q_why_body="$(printf '%s\n' "$qbody" | sed -n "$((w_line+1)),$((p_line-1))p")"
        if printf '%s\n' "$q_why_body" | grep -qx ''; then
          _bp_hit "      ⚠ $qreg_path $qid — the Why field spans more than one paragraph" "q:$qreg_path:$qid:whypara"
        fi
      fi

      # Nothing after Provenance's own paragraph before the entry ends.
      if [ -n "$p_line" ]; then
        q_after="$(printf '%s\n' "$qbody" | sed -n "$((p_line+1)),\$p")"
        q_trailing="$(printf '%s\n' "$q_after" | awk 'BEGIN{seen=0} { if ($0 ~ /^[[:space:]]*$/) {seen=1; next} if (seen && NF) {print; exit} }')"
        if [ -n "$q_trailing" ]; then
          _bp_hit "      ⚠ $qreg_path $qid — content follows Provenance's own paragraph: \"$q_trailing\"" "q:$qreg_path:$qid:trailing:$q_trailing"
        fi
      fi

      # Stamp words, for the reopened-without-stamp check below.
      if printf '%s\n' "$qbody" | grep -qiE '\*\*(Amended|CONFIRMED|Clarified|SUPERSEDED|WITHDRAWN|WORKING DEFAULT)\b'; then
        q_stamped="$q_stamped
$qid"
      fi

      # Reopen/supersede vocabulary naming another id, either order, the id never matched inside a
      # longer identifier (a preceding letter, as in PRD-NNN, disqualifies it).
      while read -r qtgt; do
        [ -n "$qtgt" ] || continue
        [ "$qtgt" = "$qid" ] && continue
        q_reopeners="$q_reopeners
$qtgt $qid"
      done < <(printf '%s\n' "$qbody" \
                 | grep -oiE "([^A-Za-z]${qreg_shape}.{0,60}(reopen|supersed|overturn)[a-z]*|(reopen|supersed|overturn)[a-z]*.{0,60}[^A-Za-z]${qreg_shape})" \
                 | grep -oE "$qreg_shape" || true)
    done <<< "$q_spans"
  done <<< "$(printf '%s\n' "$REGISTERS")"

  if [ "$q_reg_read" -eq 0 ]; then
    echo "      – no register was read (none of the declared ones is present in this source)  (skipped)"
    return 0
  fi
  while read -r qtgt; do
    [ -n "$qtgt" ] || continue
    if ! printf '%s\n' "$q_stamped" | grep -qx "$qtgt"; then
      q_by="$(printf '%s\n' "$q_reopeners" | awk -v t="$qtgt" '$1==t{print $2}' | sort -u | tr '\n' ' ')"
      qk=()
      for qby_one in $q_by; do qk+=("q:$qtgt:unstamped:$qby_one"); done
      _bp_hit "      ⚠ $qtgt — reopened or superseded by ${q_by}but carries no stamp of its own (pm.md: \"a ruling is not done until the predecessor carries its stamp, in the same change\")" "${qk[@]}"
    fi
  done <<< "$(printf '%s\n' "$q_reopeners" | awk 'NF{print $1}' | sort -u)"

  if [ "$q_entries" -eq 0 ]; then
    echo "      – 0 entr(ies) in the register(s) read  (nothing to check)"
  elif [ "$KIT_BP_NHITS" -eq 0 ]; then
    echo "      ✓ none ($q_entries entr(ies) read, every one exactly three fields, no unstamped reopen)"
  fi
  return 0
}

# ── [r] Declared reverse coverage ────────────────────────────────────────────
# Arm [l] walks FROM a citing surface TO the register. This walks the other way: a LIVE register
# entry that constrains a PRD but that PRD never cites. Keyed as "cited BY THE PRD it constrains",
# not "cited anywhere": a card citing the id is not the PRD citing it. EXEMPT: an entry whose
# Ruling field opens with CROSS_CUTTING_MARKER binds the whole project, so no PRD is expected to
# cite it. CANNOT SEE: an entry cited by its PRD in words but not the marker; an entry that
# legitimately belongs to NO PRD and is not marked exempt (it cannot tell that from a miss); a
# citation from a PRD outside PRD_SURFACE.
kit_bp_reverse_coverage() {
  local tree="$1" r_reg_read=0 r_live="" r_exempt="" r_shapes="" r_cited="" r_hits=0
  local rreg_path rreg_mark rreg_shape rreg_file r_spans rid rstart rend rbody
  local r_live_n r_exempt_n r_prds r_prd_n rpf rshp rcid _g
  _bp_reset
  while IFS='|' read -r rreg_path rreg_mark rreg_shape; do
    [ -n "$rreg_path" ] || continue
    rreg_file="$tree/$rreg_path"
    [ -f "$rreg_file" ] || continue
    r_reg_read=$((r_reg_read+1))
    r_shapes="$r_shapes
$rreg_shape"
    r_live="$r_live
$(kit_decision_register_live "$rreg_file" "$rreg_mark" "$rreg_shape")"
    r_spans="$(_bp_entry_spans "$rreg_file" "$rreg_mark" "$rreg_shape")"
    while read -r rid rstart rend; do
      [ -n "$rid" ] || continue
      rbody="$(sed -n "${rstart},${rend}p" "$rreg_file")"
      if printf '%s\n' "$rbody" | grep -qE "^\*\*Ruling\.\*\*[[:space:]]*${CROSS_CUTTING_MARKER}"; then
        r_exempt="$r_exempt
$rid"
      fi
    done <<< "$r_spans"
  done <<< "$(printf '%s\n' "$REGISTERS")"
  r_live="$(printf '%s\n' "$r_live" | grep -E '^D-[0-9]+$' | sort -u || true)"
  r_exempt="$(printf '%s\n' "$r_exempt" | grep -E '^D-[0-9]+$' | sort -u || true)"
  r_shapes="$(printf '%s\n' "$r_shapes" | awk 'NF' | sort -u || true)"
  r_live_n="$(printf '%s\n' "$r_live" | grep -c . || true)"
  r_exempt_n="$(printf '%s\n' "$r_exempt" | grep -c . || true)"

  if [ "$r_reg_read" -eq 0 ]; then
    echo "      – no register was read (none of the declared ones is present in this source)  (skipped)"
    return 0
  fi
  # The PRD population: every file matching PRD_SURFACE, named so "no PRD" and "PRDs read but none
  # cites X" are distinguishable. A local nullglob: with no match the glob must expand to NOTHING,
  # never stay literal.
  r_prds="$(
    shopt -s nullglob nocaseglob 2>/dev/null
    cd "$tree" 2>/dev/null || exit 0
    for _g in $PRD_SURFACE; do
      [ -f "$_g" ] && printf '%s\n' "$_g"
    done
  )"
  r_prd_n="$(printf '%s\n' "$r_prds" | grep -c . || true)"

  # Every id any PRD cites — the SAME marker reader arm [l] uses, against every declared
  # register's own id shape.
  while IFS= read -r rpf; do
    [ -n "$rpf" ] || continue
    while IFS= read -r rshp; do
      [ -n "$rshp" ] || continue
      while IFS= read -r rcid; do
        [ -n "$rcid" ] || continue
        r_cited="$r_cited
$rcid"
      done <<< "$(kit_decisions_cited "$tree/$rpf" "$rshp" || true)"
    done <<< "$r_shapes"
  done <<< "$r_prds"
  r_cited="$(printf '%s\n' "$r_cited" | grep -E '^D-[0-9]+$' | sort -u || true)"

  echo "      PRDs read ($PRD_SURFACE): $r_prd_n file(s) — $r_live_n live id(s), $r_exempt_n declared [cross-cutting]"
  while read -r rid; do
    [ -n "$rid" ] || continue
    printf '%s\n' "$r_exempt" | grep -qx "$rid" && continue
    if ! printf '%s\n' "$r_cited" | grep -qx "$rid"; then
      _bp_hit "      ⚠ $rid is not cited by any PRD under $PRD_SURFACE, and is not declared [cross-cutting] — if it constrains a requirement, cite it there; if it is project law no single PRD should cite, mark it [cross-cutting]" "r:$rid"
      r_hits=$((r_hits+1))
    fi
  done <<< "$r_live"
  if [ "$r_hits" -eq 0 ]; then
    if [ "$r_live_n" -eq 0 ]; then
      echo "      – 0 live id(s) in the register(s) read  (nothing to check)"
    else
      echo "      ✓ none (every live, non-exempt id is cited by a PRD under $PRD_SURFACE)"
    fi
  fi
  return 0
}
