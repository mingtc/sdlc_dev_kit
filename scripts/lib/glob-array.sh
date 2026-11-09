# KIT-CLASS: KIT — the ONE reader of a scripts/config.sh glob array (CODE_GLOBS, TEST_GLOBS). See process/EXTRACTION.md.
#
# Sourced by every program that reads one of these arrays (derive them: grep -l glob-array.sh
# across scripts/), so none can read the same array a different way.
#
# kit_glob_array <ARRAY> <config.sh>
#   Reads the anchored shape `ARRAY=(` … `)` and echoes one line per item, never sourcing the file:
#     E|<entry>   a real entry, quotes and a trailing comment stripped, blank lines skipped;
#     N|<entry>   an entry whose own line ends in a `# DECLARED NONE` comment — the project's "none, on
#                 purpose" for that one glob. It is not an `E` line, so no enforcing reader takes it;
#     D           a whole-line `# DECLARED EMPTY` comment sits inside the parens — the project's
#                 "none, on purpose", which is a declaration and leaves the seam unenforced. An array
#                 whose every entry is an `N` line is declared empty the same way, and yields `D` too.
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
          none = 0
          if (line ~ /#[[:space:]]*DECLARED NONE([^A-Za-z0-9_]|$)/) none = 1
          sub(/[[:space:]]*#.*$/, "", line)
          gsub(/^"|"$/, "", line)
          if (line == "") next
          if (none) { print "N|" line; nn++ } else { print "E|" line; ne++ }
        }
        END { if (nn > 0 && ne == 0) print "D" }
  ' "$2"
}
