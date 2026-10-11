# KIT-CLASS: KIT — the ONE reader of a scripts/config.sh glob array (CODE_GLOBS, TEST_GLOBS). See process/EXTRACTION.md.
#
# Sourced by every program that reads one of these arrays (derive them: grep -l glob-array.sh
# across scripts/), so none can read the same array a different way.
#
# kit_glob_array <ARRAY> <config.sh>
#   Reads the anchored shape `ARRAY=(` … `)` and echoes one line per item, never sourcing the file:
#     E|<entry>   a real entry, quotes and a trailing comment stripped, blank lines skipped;
#     D           a whole-line `# DECLARED EMPTY` comment sits inside the parens — the project's
#                 "none, on purpose", which is a declaration and leaves the seam unenforced.
#   A file with more than one `ARRAY=(` block (two revisions of the seam read together) yields the
#   items of each in turn. Echoes nothing if the array is absent.
kit_glob_array() {
  awk -v arr="$1" '
        $0 == arr "=(" { in_arr=1; next }
        in_arr && /^\)/ { in_arr=0; next }
        in_arr {
          raw=$0
          line=raw
          sub(/^[[:space:]]*/, "", line)
          if (line ~ /^#[[:space:]]*DECLARED EMPTY([^A-Za-z0-9_]|$)/) { print "D"; next }
          sub(/[[:space:]]*#.*$/, "", line)
          gsub(/^"|"$/, "", line)
          if (line != "") print "E|" line
        }
  ' "$2"
}
