# KIT-CLASS: KIT — the model seam's shared reader: the class table, the ladder cells, the pin
#   frontmatter, the record of what set-models.sh last wrote, and the drift report over them.
#   Sourced by scripts/set-models.sh (the one writer of the record) and scripts/check-board.sh
#   arm [s]. See process/contracts/model-provisioning-seam.md.
#
# A work class's (model, effort) is written in two places an adopter can edit by hand: the
# leaf-worker pin (.claude/agents/<file>.md frontmatter) and the ladder row (.claude/roles/
# orchestrator.md § Model & effort contract). The report below compares the pin with the ladder
# cell when that cell is filled, and with set-models.sh's record when it is not — an unfilled
# cell says nothing to compare against. With neither, the field is counted as not checkable.

# One row per work class: <class>:<ladder label>:<pin file, empty when the class has none>[:optional].
# `optional` marks a pin file whose header declares KIT-DISPOSITION: DELETE-IF-UNUSED: a project that
# removed it has dropped the class, and its absence is not damage.
KIT_MODEL_CLASS_MAP='orchestrator:Orchestrator::
refactorer:Refactorer:refactorer-worker.md:optional
pm-mint:PM-hat mint:pm-mint.md:
spike:Spike / probe:spike-worker.md:
dev:Dev:dev-worker.md:
qa:QA:qa-worker.md:
xs-mechanical:XS / mechanical::
cleanup:Cleanup / classifier:cleanup-worker.md:'
KIT_MODEL_CLASSES="orchestrator refactorer pm-mint spike dev qa xs-mechanical cleanup"
KIT_MODEL_RECORD_NAME="model-pins.record"

# kit_model_class_label <class> / kit_model_class_pin <class> — one field of the class's row;
# a class this table does not carry returns 1.
kit_model_class_label() { printf '%s\n' "$KIT_MODEL_CLASS_MAP" | awk -F: -v c="$1" '$1==c { print $2; f=1; exit } END { exit !f }'; }
kit_model_class_pin()   { printf '%s\n' "$KIT_MODEL_CLASS_MAP" | awk -F: -v c="$1" '$1==c { print $3; f=1; exit } END { exit !f }'; }
# kit_model_class_optional <class> — succeeds when the class's pin file may be absent by design.
kit_model_class_optional() { printf '%s\n' "$KIT_MODEL_CLASS_MAP" | awk -F: -v c="$1" '$1==c && $4=="optional" { f=1 } END { exit !f }'; }

# kit_model_claude_dir <root> — the harness directory under <root>: _claude/ in a tree where it
# is still disarmed (the unarmed kit), .claude/ on an adopted tree. Prints nothing when neither
# exists.
kit_model_claude_dir() {
  local d out=""
  for d in "$1/.claude" "$1/_claude"; do [ -d "$d" ] && out="$d"; done
  printf '%s' "$out"
}

# kit_model_ladder_cell <orchestrator.md> <ladder label> <model|effort> — the first backticked
# token of that cell in the label's row; nothing when the row is absent or the cell still reads
# `<fill in…>`. The label matches as a prefix inside the bold span ("XS / mechanical (any role)").
kit_model_ladder_cell() {
  local col=3
  [ "$3" = effort ] && col=4
  awk -F'|' -v want="| **$2" -v col="$col" '
    index($0, want) == 1 {
      c = $col
      if (match(c, /`[^`]*`/)) { v = substr(c, RSTART + 1, RLENGTH - 2); if (v !~ /^<fill in/) print v }
      exit
    }' "$1"
}

# kit_model_pin_get <pin file> <model|effort> — the frontmatter value; nothing when absent.
kit_model_pin_get() {
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//'
}

# The record: one line per pin file set-models.sh wrote — <pin file> TAB <model> TAB <effort>.
# set-models.sh is its only writer; a hand edit of a pin never reaches it.
# kit_model_record_set <claude-dir> <pin file> <model> <effort>
kit_model_record_set() {
  local rec="$1/$KIT_MODEL_RECORD_NAME"
  {
    echo "# Written by scripts/set-models.sh: what it last wrote to each pin file. Read by check-board.sh [s]. Do not edit."
    { [ -f "$rec" ] && awk -F'\t' -v p="$2" '/^#/ { next } $1 != p' "$rec"
      printf '%s\t%s\t%s\n' "$2" "$3" "$4"
    } | LC_ALL=C sort
  } > "$rec.new" && mv "$rec.new" "$rec"
}
# kit_model_record_get <claude-dir> <pin file> <model|effort> — nothing when no line names the file.
kit_model_record_get() {
  local col=2
  [ "$3" = effort ] && col=3
  awk -F'\t' -v p="$2" -v col="$col" '/^#/ { next } $1 == p { print $col; exit }' "$1/$KIT_MODEL_RECORD_NAME" 2>/dev/null
}

# kit_model_drift <root> — print one "      – ..." line per pin field that disagrees with the
# ladder cell or, where that cell is unfilled, with the record, and a closing line that counts
# what was compared and what could not be. Reads <root> only; it never writes. Sets
# KIT_MODEL_NHITS to the number of disagreements. Returns 1 when <root> has no harness
# directory or no orchestrator.md to read.
kit_model_drift() {
  local cdir orch class label pin f val ladder rec n_lad=0 n_rec=0 n_none=0
  KIT_MODEL_NHITS=0
  cdir="$(kit_model_claude_dir "$1")"
  orch="$cdir/roles/orchestrator.md"
  [ -n "$cdir" ] && [ -f "$orch" ] || return 1   # return-class: predicate
  for class in $KIT_MODEL_CLASSES; do
    pin="$(kit_model_class_pin "$class")"
    [ -n "$pin" ] && [ -f "$cdir/agents/$pin" ] || continue
    label="$(kit_model_class_label "$class")"
    for f in model effort; do
      val="$(kit_model_pin_get "$cdir/agents/$pin" "$f")"
      ladder="$(kit_model_ladder_cell "$orch" "$label" "$f")"
      if [ -n "$ladder" ]; then
        n_lad=$((n_lad + 1))
        [ "$val" = "$ladder" ] && continue
        echo "      ⚠ $pin $f: the pin says '${val:-<none>}', the ladder's $label row says '$ladder'"
        KIT_MODEL_NHITS=$((KIT_MODEL_NHITS + 1))
        continue
      fi
      rec="$(kit_model_record_get "$cdir" "$pin" "$f")"
      if [ -z "$rec" ]; then n_none=$((n_none + 1)); continue; fi
      n_rec=$((n_rec + 1))
      [ "$val" = "$rec" ] && continue
      echo "      ⚠ $pin $f: the pin says '${val:-<none>}', set-models.sh last wrote '$rec' and the ladder's $label row is unfilled — a hand edit?"
      KIT_MODEL_NHITS=$((KIT_MODEL_NHITS + 1))
    done
  done
  local n_cmp=$((n_lad + n_rec)) verdict=""
  if [ "$KIT_MODEL_NHITS" -eq 0 ]; then
    if [ "$n_cmp" -gt 0 ]; then verdict=" ✓ all $n_cmp compared field(s) agree"; else verdict=" — nothing was compared, so this is no verdict"; fi
  fi
  echo "      $n_lad pin field(s) compared with the ladder, $n_rec with set-models.sh's record, $n_none not checkable (no filled ladder cell and no record line)$verdict"
}

# kit_model_blank_rows <root> — one line, only when some hand-kept row of a role doc's § Model &
# effort contract table still holds a `<fill in…>` cell: how many rows, and in which files. The rows
# set-models.sh writes — orchestrator.md's ladder rows, one per class label — are not counted: it
# fills them, and the line would stay true of rows it just wrote. Nothing else shows the per-role
# tables are blank. Reads <root> only; prints nothing when none is blank or <root> has no role docs.
kit_model_blank_rows() {
  local cdir f n total=0 names="" labels
  cdir="$(kit_model_claude_dir "$1")"
  [ -n "$cdir" ] || return 0
  labels="$(printf '%s\n' "$KIT_MODEL_CLASS_MAP" | awk -F: '{ print $2 }' | tr '\n' '|')"
  for f in "$cdir"/roles/*.md; do
    [ -f "$f" ] || continue
    n="$(awk -v ladder="$([ "$(basename "$f")" = orchestrator.md ] && echo 1)" -v labels="$labels" '
      BEGIN { k = split(labels, L, "|") }
      /^## /{ s = ($0 ~ /^## Model & effort contract/) }
      s && /^\|/ && /<fill in/ {
        if (ladder) { for (i = 1; i <= k; i++) if (L[i] != "" && index($0, "| **" L[i]) == 1) next }
        c++
      }
      END { print c + 0 }' "$f")"
    [ "$n" -gt 0 ] || continue
    total=$((total + n))
    names="${names:+$names, }$(basename "$f") ($n)"
  done
  [ "$total" -gt 0 ] || return 0
  echo "      ⚠ $total role-doc model row(s) still \`<fill in>\`: $names — set-models.sh does not write the role docs' own tables; fill them by hand (reports only)"
}
