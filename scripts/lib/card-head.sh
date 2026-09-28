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
    return 1
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
    || { echo "kit_rehead_card: '$card' is EMPTY after the re-head — the card was destroyed, not minted." >&2; return 1; }
  grep -q '^<!-- KIT-CLASS:' "$card" \
    && { echo "kit_rehead_card: '$card' still carries a KIT-CLASS: marker after the re-head — a live card must not." >&2; return 1; }
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
