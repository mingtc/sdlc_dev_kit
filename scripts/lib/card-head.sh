#!/usr/bin/env bash
# KIT-CLASS: KIT — the mint-time card re-head and publish, in one place.
# See process/EXTRACTION.md.
#
# The creation scripts strip a template's travel-classification marker at mint time and put
# a live-card head in its place; this is that block's one copy. The card path is an argument
# because `${BASH_SOURCE[0]}` inside a sourced function names this library, not the caller.

# kit_card_work <dest-dir> — print a new temp file beside the destination, so publishing is a
# rename on one filesystem. Dot-named, so no board glob sees it. The caller's EXIT trap removes
# it and the siblings the functions below write, plus any the caller makes itself:
#   rm -f "$WORK" "$WORK.bak" "$WORK.rehead" "$WORK.stamp" "$WORK.fill"
kit_card_work() {
  mktemp "$1/.mint.XXXXXX"
}

# kit_publish_card <work> <dest> — give the file the umask's mode (mktemp makes it 0600), then
# move it into place.
kit_publish_card() {
  chmod "$(printf '%o' $(( 0666 & ~$(umask) )))" "$1" && mv "$1" "$2"
}

# kit_rehead_card <card-file>
#
# REPLACE, DON'T DELETE: a minted card's class is PROJECT, so the KIT-CLASS: marker goes
# (process/EXTRACTION.md § The marker and graduation), but it carried a FILL instruction still
# in force, and the head below is its only other statement.
#
# THE HEAD MUST NOT CONTAIN THE MARKER KEY, NOT EVEN TO DENY IT: `grep -rl` for that key is how
# classified files are derived, and a minted card must stay unmarked.
#
# THE HEAD IS PREPENDED BY THE SHELL, NOT PASSED INTO awk: `awk -v x="$MULTILINE"` fails with
# "newline in string" and awk then writes nothing, leaving an empty card.
kit_rehead_card() {
  local card="$1" body head
  [ -n "$card" ] && [ -f "$card" ] || {
    echo "kit_rehead_card: called without a readable card path — the caller must pass the file it is minting." >&2
    return 1   # return-class: usage
  }
  head='<!-- A live card, not a template. It carries NO travel-classification marker, by design:
     this file was born in this repository and never travels, and process/EXTRACTION.md § The one
     file classification convention states that the absence is deliberate rather than an oversight.
     Fill every <angle-bracket>; never leave one in a live card. -->'
  body="${card}.rehead"
  # Two comment blocks are the template's, not the card's: the classification marker and the
  # LINKS declaration (addressed to whoever maintains the template; the self-test reads it there).
  awk '
    /^<!-- (KIT-CLASS:|LINKS IN THIS FILE ARE RELATIVE TO WHERE IT LANDS)/ { if (!/-->/) skip = 1; next }
    skip && /-->/      { skip = 0; next }
    skip              { next }
                      { print }
  ' "$card" > "$body"
  { printf '%s\n' "$head"; cat "$body"; } > "$card"
  rm -f "$body"
  # The postcondition is asserted because every failure mode here is silent.
  [ -s "$card" ] \
    || { echo "kit_rehead_card: '$card' is EMPTY after the re-head — the card was destroyed, not minted." >&2; return 1; }   # return-class: internal
  grep -q '^<!-- KIT-CLASS:' "$card" \
    && { echo "kit_rehead_card: '$card' still carries a KIT-CLASS: marker after the re-head — a live card must not." >&2; return 1; }   # return-class: internal
  return 0
}

# kit_stamp_card <card-file> <id> <date> — write what the mint already knows into the body: the id
# in the H1 (the first `# ` line, up to its ` — `) and the date of the seed Activity entry (the
# LAST `- YYYY-MM-DD ` line). Values travel through ENVIRON, not `awk -v`, which expands escapes.
kit_stamp_card() {
  KIT_STAMP_ID="$2" KIT_STAMP_DATE="$3" awk '
    { l[NR] = $0 }
    !h && /^# / { h = NR }
    /^- YYYY-MM-DD / { s = NR }
    END {
      id = ENVIRON["KIT_STAMP_ID"]; d = ENVIRON["KIT_STAMP_DATE"]
      for (i = 1; i <= NR; i++) {
        x = l[i]
        if (i == h && (p = index(x, " — ")) > 0) x = "# " id substr(x, p)
        if (i == s) x = "- " d substr(x, 13)
        print x
      }
    }' "$1" > "$1.stamp" && mv "$1.stamp" "$1"
}

# kit_fill_card <card-file> <token> <value> [<token> <value>]... — replace each literal token in the
# BODY (below the frontmatter, which the creators fill by key). An empty value is skipped, so an
# absent flag leaves its blank for the author. index/substr, not gsub: `&` and a backslash are live
# in gsub's replacement.
kit_fill_card() {
  local card="$1" n=0; shift
  while [ "$#" -ge 2 ]; do
    if [ -n "$2" ]; then export "KIT_FILL_T$n=$1" "KIT_FILL_V$n=$2"; n=$((n + 1)); fi
    shift 2
  done
  KIT_FILL_N="$n" awk '
    BEGIN { n = ENVIRON["KIT_FILL_N"] + 0
            for (i = 0; i < n; i++) { t[i] = ENVIRON["KIT_FILL_T" i]; v[i] = ENVIRON["KIT_FILL_V" i] } }
    fm < 2 { if ($0 == "---") fm++; print; next }
    { for (i = 0; i < n; i++) {
        out = ""; r = $0
        while ((p = index(r, t[i])) > 0) { out = out substr(r, 1, p - 1) v[i]; r = substr(r, p + length(t[i])) }
        $0 = out r
      }
      print }' "$card" > "$card.fill" && mv "$card.fill" "$card"
}

# kit_card_fragments <card-file> <template> <fragments-dir> — the last step of a mint: place what an
# add-on contributes, and remove what the core left for it. <template> is the template's stem
# (`PRD`, `ISSUE`); the fragments are the files in <fragments-dir>/<template>/, read from the working tree
# like the template itself, in file-name order:
#
#   <name>.frontmatter   lines added before the frontmatter's closing `---`
#   <name>.body-end      a paragraph added after the last section, above a closing `## Activity`
#   <name>.slot-<slot>   lines put where the template has its `<!-- KIT-MODULES:<slot> -->` line
#
# <name> and <slot> are lowercase letters, digits and `-`, opening with a letter; a README.md is not a
# fragment. EVERY slot line is removed, fragment or none, so a project that enables nothing has no
# trace of it. A fragment the template cannot take, a name that is no mode, or a fragment that carries
# a slot line of its own, refuses through kit_refuse and the caller's EXIT trap removes the work file.
# The work file is rewritten through <card-file>.fill, which that trap names.
kit_card_fragments() {
  local card="$1" tpl="$2" dir="$3/$2" f base name mode slot text nl=$'\n'
  local fm="" be="" out="$1.fill" rs=$'\036' us=$'\037' gs=$'\035' slot_texts=""
  if [ -d "$dir" ]; then
    for f in "$dir"/*; do
      [ -f "$f" ] || continue
      base="${f##*/}"
      [ "$base" != README.md ] || continue
      name="${base%%.*}"; mode="${base#*.}"
      case "$name" in ''|[!a-z]*|*[!a-z0-9-]*) name="" ;; esac
      case "$mode" in
        frontmatter|body-end) ;;
        slot-[a-z]*) slot="${mode#slot-}"; case "$slot" in *[!a-z0-9-]*) name="" ;; esac ;;
        *) name="" ;;
      esac
      if [ -z "$name" ] || [ "$base" = "$name" ]; then
        kit_refuse 1 fragment-name-unknown \
          "Error: process/fragments.d/${f#"$3"/} is not a fragment of the ${tpl} template." \
          "       A fragment is <name>.frontmatter, <name>.body-end or <name>.slot-<slot>, with a lowercase <name>" \
          "       (letters, digits and '-', opening with a letter)." \
          "Next: rename it to one of those shapes, or remove it; the mint made nothing."
      fi
      if [ ! -r "$f" ]; then
        kit_refuse 1 fragment-unreadable \
          "Error: process/fragments.d/${f#"$3"/} is not readable, so the ${tpl} mint cannot place it." \
          "Next: fix its permissions, or remove it; the mint made nothing."
      fi
      if grep -qF 'KIT-MODULES' "$f"; then
        kit_refuse 1 fragment-content-markers \
          "Error: process/fragments.d/${f#"$3"/} carries a KIT-MODULES slot line of its own, which would leave the minted file with a marker no reader removes." \
          "Next: take that line out of the fragment (the template owns the slots); the mint made nothing."
      fi
      text="$(sed 's/\r$//' "$f")"
      case "$mode" in
        frontmatter) fm="${fm}${fm:+$nl}${text}" ;;
        body-end)    be="${be}${be:+$nl}${text}" ;;
        slot-*)
          if ! grep -qE "^<!-- KIT-MODULES:${slot}( |-->|\$)" "$card"; then
            kit_refuse 1 fragment-slot-missing \
              "Error: process/fragments.d/${f#"$3"/} fills the '${slot}' slot, and this ${tpl} template has no <!-- KIT-MODULES:${slot} --> line." \
              "Next: restore that line in the ${tpl} template (the release ships it; take it from there), or remove the fragment; the mint made nothing."
          fi
          slot_texts="${slot_texts}${slot_texts:+$rs}${slot}${us}${text//$nl/$gs}"
          ;;
      esac
    done
  fi
  # The three placements and the strip, in one pass over the card. The texts travel through ENVIRON,
  # since awk -v expands escapes; the slots arrive as <slot> US <text>, separated by RS, a text's newlines
  # carried as GS (macOS awk splits on a newline when asked to split on another separator).
  KIT_FRAG_SLOTS="$slot_texts" KIT_FRAG_FM="$fm" KIT_FRAG_BE="$be" awk '
    function lines(t, arr,   n) { n = split(t, arr, "\n"); return n }
    function trim_end(arr, n) { while (n > 0 && arr[n] == "") n--; return n }
    { L[NR] = $0 }
    END {
      nfm = lines(ENVIRON["KIT_FRAG_FM"], FM); nfm = (ENVIRON["KIT_FRAG_FM"] == "") ? 0 : nfm
      nbe = lines(ENVIRON["KIT_FRAG_BE"], BE); nbe = (ENVIRON["KIT_FRAG_BE"] == "") ? 0 : trim_end(BE, nbe)
      nsl = split(ENVIRON["KIT_FRAG_SLOTS"], SL, "\036")
      for (k = 1; k <= nsl; k++) { p = index(SL[k], "\037"); sn = substr(SL[k], 1, p - 1); st = substr(SL[k], p + 1); gsub("\035", "\n", st); ST[sn] = (sn in ST) ? ST[sn] "\n" st : st }
      for (i = 1; i <= NR; i++) if (L[i] == "---") { if (++nd == 2) { close_ = i; break } }
      act = 0
      for (i = NR; i >= 1; i--) if (L[i] ~ /^## Activity[ \t]*$/) { act = i; break }
      if (nfm > 0 && !close_) exit 3
      for (i = 1; i <= NR; i++) {
        if (act && i == act && nbe > 0) { if (prev != "") print ""; for (j = 1; j <= nbe; j++) print BE[j]; print ""; prev = "" }
        if (i == close_) for (j = 1; j <= nfm; j++) print FM[j]
        if (L[i] ~ /^<!-- KIT-MODULES:/) {
          for (sn in ST) {
            if (L[i] ~ ("^<!-- KIT-MODULES:" sn "( |-->|$)")) {
              m = lines(ST[sn], T); m = trim_end(T, m)
              for (j = 1; j <= m; j++) print T[j]
              if (m > 0) print ""
              break
            }
          }
          continue
        }
        print L[i]; prev = L[i]
      }
      if (!act && nbe > 0) { if (prev != "") print ""; for (j = 1; j <= nbe; j++) print BE[j] }
    }
  ' "$card" > "$out"
  case $? in
    0) mv "$out" "$card" ;;
    3) rm -f "${out:?}"
       kit_refuse 1 fragment-frontmatter-missing \
         "Error: a ${tpl} fragment adds frontmatter, and this ${tpl} template has no frontmatter (two '---' lines)." \
         "Next: restore the frontmatter in the ${tpl} template (the release ships it), or remove the .frontmatter fragment; the mint made nothing." ;;
    *) rm -f "${out:?}"
       echo "kit_card_fragments: could not rewrite '$card' — the fragments were not placed." >&2
       return 1 ;;   # return-class: internal
  esac
  return 0
}

# kit_drop_story_blank <card-file> <stories-given> — a card minted with no `--stories` names no
# story: write `stories: []` and drop the template's ` — stories <story ids>` from the References
# line and `, stories <story ids>` from the seed entry (a bug's `, story <story ids>` likewise), so
# no example id stands where a real one was owed. A caller that named stories (<stories-given> non-empty) is left alone.
kit_drop_story_blank() {
  [ -z "${2:-}" ] || return 0
  sed -i.bak -e 's|^stories: .*|stories: []|' -e 's| — stories <story ids>||' -e 's|, stories <story ids>||' -e 's|, story <story ids>||' "$1" \
    && rm -f "$1.bak"
}

# kit_prd_free_card <card-file> <stories-given> — a card minted with `--prd n/a` is on the lite
# path: no PRD, no stories. Rewrite the PRD-shaped lines the template ships (the issue's References
# line and seed entry, the bug's Expected and Related PRD lines) to say so, and set `stories: []`
# unless the caller named stories (<stories-given> non-empty). A line the card does not carry is
# left alone. Run it before the PRD fills; the caller then passes no PRD value to them.
kit_prd_free_card() {
  local card="$1"
  [ -z "${2:-}" ] && { sed -i.bak -e 's|^stories: .*|stories: []|' "$card" && rm -f "$card.bak"; }
  kit_fill_card "$card" \
    '- **PRD:** [PRD-NNN](../../requirements/PRD-NNN-<slug>.md) — stories <story ids>' '- **PRD:** none — lite path; `prd_reason:` says why' \
    'PRD-NNN, stories <story ids>.' 'No PRD (lite path).' \
    '(per [PRD-NNN](../../requirements/PRD-NNN-<slug>.md), story <story ids>)' '(no PRD covers this; `prd_reason:` says why)' \
    '- Related PRD: PRD-NNN, story <story ids>' '- Related PRD: none'
}

# validate_card_links "$PRD" "$STORIES" "$DISCOVERED" — the shape of the link options the creation
# scripts take (read-only; an empty value is not given). A malformed value returns non-0 after
# naming the option, so the caller exits as a usage error before any card is written. Uses
# PRD_PREFIX and ISSUE_PREFIX.
validate_card_links() {
  local prd="$1" stories="$2" disc="$3" item rest nl=$'\n'
  # grep matches line by line, so a value holding a newline would pass on its first line.
  case "$prd" in *"$nl"*) echo "Error: --prd must be one line." >&2; return 1 ;; esac   # return-class: usage
  case "$stories" in *"$nl"*) echo "Error: --stories must be one line." >&2; return 1 ;; esac   # return-class: usage
  case "$disc" in *"$nl"*) echo "Error: --discovered-in must be one line." >&2; return 1 ;; esac   # return-class: usage
  if [ -n "$prd" ] && [ "$prd" != "n/a" ] && ! grep -qE "^${PRD_PREFIX}-[0-9]+$" <<< "$prd"; then
    echo "Error: --prd '$prd' must look like ${PRD_PREFIX}-NNN, or n/a on the lite path." >&2
    return 1   # return-class: usage
  fi
  if [ -n "$stories" ]; then
    rest="$stories,"
    while [ -n "$rest" ]; do
      item="${rest%%,*}"; rest="${rest#*,}"
      if ! grep -qE "^${PRD_PREFIX}-[0-9]+-F[0-9]+-S[0-9]+$" <<< "$item"; then
        echo "Error: --stories entry '$item' must look like ${PRD_PREFIX}-NNN-F1-S1; separate several with commas and no spaces." >&2
        return 1   # return-class: usage
      fi
    done
  fi
  if [ -n "$disc" ] && ! grep -qE "^${ISSUE_PREFIX}-[0-9]+$" <<< "$disc"; then
    echo "Error: --discovered-in '$disc' must look like ${ISSUE_PREFIX}-NNN." >&2
    return 1   # return-class: usage
  fi
  return 0
}
