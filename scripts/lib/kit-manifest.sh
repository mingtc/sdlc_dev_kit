# KIT-CLASS: KIT — the one writer of process/KIT-MANIFEST: the release build and scripts/kit-manifest.sh
#   both call it, so a clone and a release zip record the same rows for the same files.
#   See process/EXTRACTION.md.
#
# kit_manifest_write <tree>
#   Writes <tree>/process/KIT-MANIFEST, one row for every regular file under <tree> but the manifest
#   itself: <sha256>  <path>  <class>  <disposition>, in C-locale path order. Status 0 when the manifest
#   was written and describes the tree; otherwise nothing was left half-trusted: the message is on
#   stderr and the status is 1.
#
#   THE MANIFEST IS A STATEMENT OF WHICH FILES ARE THE KIT'S, and the guards that ask about "the shipped
#   scripts" read it, because a glob over scripts/ is wrong once a project adds its own. It records what
#   was SHIPPED, so <tree> is the shipped tree and never one a project has edited.
#
#   The path column is the population and needs no tools to read; the hash column needs a sha256 tool
#   (shasum or sha256sum), which the kit does not otherwise require. The class column is the file's own
#   `KIT-CLASS:` marker, `-` where it has none, read from the first KIT_CLASS_WINDOW lines (a skill or
#   agent doc opens with frontmatter, so the marker sits below line 3). A marker found below the window
#   refuses: either it is not at the top, or the window is too narrow, and neither is "unmarked". The
#   disposition column is the file's `KIT-DISPOSITION:` declaration from its first
#   KIT_DISPOSITION_WINDOW lines, `-` where it declares none; a marker quoted deeper in a sheet as an
#   example is not a declaration, so it has no below-the-window refusal.
KIT_MANIFEST_REL="process/KIT-MANIFEST"
KIT_CLASS_WINDOW=20
KIT_DISPOSITION_WINDOW=12
KIT_DISPOSITION_DECL='^[[:space:]]*(#|<!--|//|--)?[[:space:]]*KIT-DISPOSITION:[[:space:]]*[A-Z][A-Z-]*'

_kit_manifest_sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else printf 'no-sha256-tool-on-this-host'; fi
}

kit_manifest_write() {
  local tree="${1:-}" out rel cls deep dsp listed=0 present
  if [ -z "$tree" ] || [ ! -d "$tree" ]; then
    echo "kit_manifest_write: '${tree}' is not a directory." >&2
    return 1   # return-class: usage
  fi
  out="$tree/$KIT_MANIFEST_REL"
  mkdir -p "$tree/process" || return 1   # return-class: internal
  {
    printf '# KIT-CLASS: KIT — the shipped manifest: which files are the kit'"'"'s.\n'
    printf '# GENERATED AT BUILD AND NEVER TRACKED. Regenerating it is the build; editing it is\n'
    printf '# meaningless. Columns: <sha256>  <path>  <KIT-CLASS or - if the file declares none>  <KIT-DISPOSITION or ->.\n'
    printf '# The path column is the population and needs no tools to read. It EXCLUDES ITSELF.\n'
    printf '# A "-" class means the file carries no KIT-CLASS marker, not that it has no class:\n'
    printf '# process/EXTRACTION.md names where each exception%s class lives instead.\n' "'s"
  } > "$out" || return 1   # return-class: internal
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ "$rel" = "$KIT_MANIFEST_REL" ] && continue          # it cannot hash itself
    cls="$(sed -n "1,${KIT_CLASS_WINDOW}p" "$tree/$rel" 2>/dev/null | sed -n 's/.*KIT-CLASS:[[:space:]]*\([A-Z][A-Z]*\).*/\1/p' | head -1)"
    if [ -z "$cls" ]; then
      # `|| true`: under pipefail a grep that matches nothing, the normal case for an unmarked file, fails the pipeline.
      deep="$(grep -n 'KIT-CLASS:[[:space:]]*[A-Z]' "$tree/$rel" 2>/dev/null | head -1 || true)"
      if [ -n "$deep" ]; then
        printf '%s\n' \
          "$rel declares a KIT-CLASS below line $KIT_CLASS_WINDOW (at ${deep%%:*}), so the manifest would record it as unmarked." \
          "Next: move the marker to the top of the file (process/EXTRACTION.md § The one file classification" \
          "      convention), or widen KIT_CLASS_WINDOW in scripts/lib/kit-manifest.sh, then write the manifest again." >&2
        return 1   # return-class: refusal
      fi
    fi
    dsp="$(sed -n "1,${KIT_DISPOSITION_WINDOW}p" "$tree/$rel" 2>/dev/null | grep -E "$KIT_DISPOSITION_DECL" | head -1 | sed 's/.*KIT-DISPOSITION:[[:space:]]*\([A-Z][A-Z-]*\).*/\1/' || true)"
    printf '%s  %s  %s  %s\n' "$(_kit_manifest_sha256 "$tree/$rel")" "$rel" "${cls:--}" "${dsp:--}" >> "$out" || return 1   # return-class: internal
    listed=$(( listed + 1 ))
  done < <(cd "$tree" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
  # The manifest describes the tree, or it describes nothing: rows counted against the files found.
  present="$( (cd "$tree" && find . -type f | wc -l) | tr -d ' ' )"
  if [ "$listed" -ne "$(( present - 1 ))" ]; then
    echo "the manifest lists $listed file(s) and the tree holds $(( present - 1 )) besides the manifest itself. A manifest that does not describe the tree is worse than none." >&2
    return 1   # return-class: internal
  fi
}
