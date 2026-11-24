#!/bin/sh
# KIT-CLASS: KIT — the one reader, and the one builder, of a kitpack: project files the zip ships packed. See process/EXTRACTION.md.
#
# A kitpack is ONE git bundle holding ONE root commit whose tree is the packed files, at the paths
# they unpack to. Reading one needs git and a POSIX shell and nothing else: no tar, gzip, unzip,
# perl or python. Run it as a program: sh scripts/lib/kitpack.sh <verb> …
#
#   verify <pack>                     the pack is whole and every member is allowed; prints "ok: N members"
#   ls     <pack>                     "<mode> <path>" for each member
#   cat    <pack> <path>              one member's bytes on stdout
#   unpack [--missing] [--check] <pack> <dir>
#                                     writes the members under <dir> and prints "wrote <path>" for each.
#                                     No member is overwritten: one already there refuses the unpack before
#                                     anything is written; with --missing it is left as it is and printed
#                                     as "kept <path>". Each member lands whole or not at all. With --check
#                                     every check runs and nothing is written or printed.
#   build  <srcdir> <out> <name> <epoch> [<zlib level, default 9>]
#                                     the builder's half: every file under <srcdir> becomes a member.
#                                     The bytes are a function of the members, the name and the epoch.
#
# THE FORMAT'S RULES, enforced when a pack is built and again when it is read. A pack that breaks one
# is refused, never repaired, and nothing is written:
#   * members are regular files, mode 100644 or 100755; a symlink, a gitlink or a device is refused;
#   * a path is made of A-Z a-z 0-9 . _ / @ + = , : - with no empty, "." or ".." component, no
#     component that starts with "-" or is ".git" in any case, and no two paths that differ only by case;
#   * the bundle holds exactly one ref, refs/kit/<name>, and one commit with no parent.
# Members are written with `git hash-object --no-filters` and read with `git cat-file blob`, in a
# private HOME with no git configuration of the machine's or the caller's, so no autocrlf, attribute
# or config key changes a byte.
#
# EXIT STATUS. 0 done. 1 refused: the pack or the destination breaks a rule above; the message names
# the member. 2 usage. 3 a tool failed (git, mktemp, mkdir). This program runs where bash may not, so
# it cannot call kit_refuse: it reports, and scripts/pack.sh turns each non-zero status into a refusal
# that names its next step.

set -u
# The path rules below are byte ranges; a locale's collation must not widen them.
LC_ALL=C; export LC_ALL

# THE NAMES, ONCE. Nothing else in the kit spells the directory, the extension or the ref namespace.
KIT_PACK_DIR=packs
KIT_PACK_EXT=kitpack
KIT_PACK_REF=refs/kit

_pk_die() { printf 'kitpack: %s\n' "$2" >&2; exit "$1"; }   # exit-class: internal

_pk_usage() { sed -n '4,/^$/{/^$/!s/^# \{0,1\}//p;}' "$0"; }

_pk_tab="$(printf '\t')"
PK_T=""   # the member being written, removed if the run ends before it is in place

# Everything git does here runs with no configuration of the machine's or the caller's reaching it.
_pk_env() {  # <private home>
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
        GIT_NAMESPACE GIT_COMMON_DIR GIT_CEILING_DIRECTORIES GIT_PREFIX GIT_CONFIG GIT_CONFIG_COUNT \
        GIT_CONFIG_PARAMETERS GIT_TEMPLATE_DIR GIT_ATTR_SOURCE
  GIT_CONFIG_NOSYSTEM=1; GIT_CONFIG_GLOBAL=/dev/null; GIT_CONFIG_SYSTEM=/dev/null
  HOME="$1"; XDG_CONFIG_HOME="$1"
  export GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM HOME XDG_CONFIG_HOME
}

_pk_scratch() {  # sets PK_S to a fresh private directory, removed on exit
  PK_S="$(mktemp -d "${TMPDIR:-/tmp}/kitpack.XXXXXX")" || _pk_die 3 "mktemp -d failed; check TMPDIR."
  trap 'rm -f "$PK_T"; rm -rf "$PK_S"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  mkdir "$PK_S/home" || _pk_die 3 "the scratch directory $PK_S is not writable."
  _pk_env "$PK_S/home"
}

_pk_path_ok() {  # 0 when $1 is a path the format allows
  case "$1" in
    ""|/*|*//*|*/|.|..|./*|*/.|../*|*/..|*/../*|*/./*) return 1 ;;   # return-class: predicate
    *[!A-Za-z0-9._/@+=,:-]*) return 1 ;;   # return-class: predicate
    -*|*/-*) return 1 ;;   # return-class: predicate
  esac
  case "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" in
    .git|.git/*|*/.git|*/.git/*) return 1 ;;   # return-class: predicate
  esac
  return 0
}

_pk_name_ok() {  # 0 when $1 is a pack name: lowercase letters, digits and "-", not starting with "-"
  case "$1" in ""|-*|*[!a-z0-9-]*) return 1 ;; esac   # return-class: predicate
  return 0
}

_pk_no_case_twins() {  # <file of paths>; 0 when no two paths differ only by case
  tr 'A-Z' 'a-z' < "$1" | LC_ALL=C sort > "$PK_S/lower" || _pk_die 3 "could not sort the member paths."
  _pc_prev=""
  while IFS= read -r _pc_p; do
    if [ "$_pc_p" = "$_pc_prev" ]; then PK_TWIN=$_pc_p; return 1; fi   # return-class: predicate
    _pc_prev=$_pc_p
  done < "$PK_S/lower"
  return 0
}

pack_build() {  # <srcdir> <out> <name> <epoch> [level]
  src=$1; out=$2; name=$3; epoch=$4; level=${5:-9}
  [ -d "$src" ] || _pk_die 1 "build: $src is not a directory."
  [ ! -e "$out" ] && [ ! -L "$out" ] || _pk_die 1 "build: $out exists; this will not overwrite it."
  _pk_name_ok "$name" || _pk_die 1 "build: the name '$name' must be lowercase letters, digits and '-'."
  case "$epoch" in ""|*[!0-9]*) _pk_die 1 "build: the epoch '$epoch' is not a number." ;; esac
  case "$level" in [0-9]) ;; *) _pk_die 1 "build: the zlib level '$level' is not 0 to 9." ;; esac
  _pk_scratch
  src="$(cd "$src" && pwd -P)" || _pk_die 3 "build: could not enter $src."
  bad="$(cd "$src" && find . ! -type f ! -type d -print)" || _pk_die 3 "build: find failed."
  [ -z "$bad" ] || _pk_die 1 "build: not a regular file or directory (a symlink, socket or device): $bad"
  ( cd "$src" && find . -type f -print | sed 's|^\./||' | LC_ALL=C sort ) > "$PK_S/paths" || _pk_die 3 "build: find failed."
  [ -s "$PK_S/paths" ] || _pk_die 1 "build: $src holds no files."
  while IFS= read -r p; do
    _pk_path_ok "$p" || _pk_die 1 "build: the path '$p' is outside the format's alphabet or shape (see the header of kitpack.sh)."
  done < "$PK_S/paths"
  _pk_no_case_twins "$PK_S/paths" || _pk_die 1 "build: two paths differ only by case ('$PK_TWIN')."
  g="$PK_S/g"
  git -c init.defaultBranch=main init -q --bare --template= "$g" || _pk_die 3 "build: git init failed."
  GIT_DIR="$g"; export GIT_DIR
  while IFS= read -r p; do printf '%s/%s\n' "$src" "$p"; done < "$PK_S/paths" > "$PK_S/abs"
  git hash-object -w --no-filters --stdin-paths < "$PK_S/abs" > "$PK_S/shas" || _pk_die 3 "build: git hash-object failed."
  [ "$(wc -l < "$PK_S/paths" | tr -d ' ')" = "$(wc -l < "$PK_S/shas" | tr -d ' ')" ] || _pk_die 3 "build: git hashed a different number of files than were listed."
  : > "$PK_S/idx"
  exec 3< "$PK_S/shas"
  while IFS= read -r p; do
    IFS= read -r sha <&3
    if [ -x "$src/$p" ]; then mode=100755; else mode=100644; fi
    printf '%s %s\t%s\n' "$mode" "$sha" "$p" >> "$PK_S/idx"
  done < "$PK_S/paths"
  exec 3<&-
  GIT_INDEX_FILE="$PK_S/index"; export GIT_INDEX_FILE
  git update-index --add --index-info < "$PK_S/idx" || _pk_die 3 "build: git update-index failed."
  tree="$(git write-tree)" || _pk_die 3 "build: git write-tree failed."
  GIT_AUTHOR_NAME=kitpack GIT_AUTHOR_EMAIL=kitpack@invalid GIT_AUTHOR_DATE="$epoch +0000"
  GIT_COMMITTER_NAME=kitpack GIT_COMMITTER_EMAIL=kitpack@invalid GIT_COMMITTER_DATE="$epoch +0000"
  export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
  commit="$(printf 'kitpack %s\n' "$name" | git commit-tree "$tree")" || _pk_die 3 "build: git commit-tree failed."
  git update-ref "$KIT_PACK_REF/$name" "$commit" || _pk_die 3 "build: git update-ref failed."
  # One thread, no delta search and a pinned zlib level: the bytes are a function of the members.
  git -c pack.threads=1 -c pack.window=0 -c pack.depth=0 -c "pack.compression=$level" -c pack.useBitmaps=false \
      bundle create "$PK_S/out.bundle" "$KIT_PACK_REF/$name" >/dev/null 2>"$PK_S/err" \
    || { cat "$PK_S/err" >&2; _pk_die 3 "build: git bundle create failed."; }
  cat "$PK_S/out.bundle" > "$out" || _pk_die 3 "build: could not write $out."
}

# _pk_open <pack> — sets PK_G (a private bare repository holding the pack's objects), PK_C (its one
# commit) and PK_S/members (git's own `ls-tree -r` lines); refuses a pack that is not whole or breaks a rule.
_pk_open() {
  _po_arg=$1
  [ -f "$_po_arg" ] || _pk_die 1 "$_po_arg is not a file."
  case "$_po_arg" in /*) _po_abs=$_po_arg ;; *) _po_abs="$PWD/$_po_arg" ;; esac
  _pk_scratch
  PK_G="$PK_S/g"
  git -c init.defaultBranch=main init -q --bare --template= "$PK_G" || _pk_die 3 "git init failed."
  GIT_DIR="$PK_G"; export GIT_DIR
  _po_heads="$(git bundle list-heads "$_po_abs" 2>/dev/null)" || _pk_die 1 "$_po_arg is not a whole kitpack (git could not read it)."
  [ -n "$_po_heads" ] || _pk_die 1 "$_po_arg is not a whole kitpack (it holds no ref)."
  [ "$(printf '%s\n' "$_po_heads" | wc -l | tr -d ' ')" = 1 ] || _pk_die 1 "$_po_arg must hold exactly one ref, $KIT_PACK_REF/<name>; it holds: $(printf '%s' "$_po_heads" | tr '\n' ' ')"
  _po_ref="${_po_heads#* }"
  case "$_po_ref" in "$KIT_PACK_REF"/*) ;; *) _pk_die 1 "$_po_arg must hold exactly one ref, $KIT_PACK_REF/<name>; it holds $_po_ref." ;; esac
  _pk_name_ok "${_po_ref#"$KIT_PACK_REF"/}" || _pk_die 1 "$_po_arg: the ref '$_po_ref' is not $KIT_PACK_REF/<lowercase letters, digits and '-'>."
  git -c transfer.fsckObjects=true fetch -q "$_po_abs" "$_po_ref:$_po_ref" 2>"$PK_S/err" \
    || _pk_die 1 "$_po_arg is not a whole kitpack (git could not read or verify it)."
  PK_C="$(git rev-parse --verify -q "$_po_ref^{commit}")" || _pk_die 1 "$_po_arg is not a whole kitpack (its ref is no commit)."
  [ "$(git rev-list --count "$PK_C")" = 1 ] || _pk_die 1 "$_po_arg holds more than one commit; a kitpack holds one, with no parent."
  git ls-tree -r "$PK_C" > "$PK_S/members" || _pk_die 1 "$_po_arg is not a whole kitpack (git could not list it)."
  [ -s "$PK_S/members" ] || _pk_die 1 "$_po_arg holds no files."
  : > "$PK_S/paths"
  while IFS="$_pk_tab" read -r _po_meta _po_p; do
    case "$_po_meta" in
      "100644 blob "*|"100755 blob "*) ;;
      *) _pk_die 1 "$_po_arg: the member '$_po_p' has mode and type '${_po_meta%% blob*}', and only regular files are allowed." ;;
    esac
    _pk_path_ok "$_po_p" || _pk_die 1 "$_po_arg: the member path '$_po_p' is outside the format's alphabet or shape (see the header of kitpack.sh)."
    printf '%s\n' "$_po_p" >> "$PK_S/paths"
  done < "$PK_S/members"
  _pk_no_case_twins "$PK_S/paths" || _pk_die 1 "$_po_arg: two members differ only by case ('$PK_TWIN')."
}

pack_ls() {  # <pack>
  _pk_open "$1"
  while IFS="$_pk_tab" read -r meta p; do printf '%s %s\n' "${meta%% *}" "$p"; done < "$PK_S/members"
}

pack_verify() {  # <pack>
  _pk_open "$1"
  printf 'ok: %s members\n' "$(wc -l < "$PK_S/members" | tr -d ' ')"
}

pack_cat() {  # <pack> <path>
  _pk_open "$1"
  while IFS="$_pk_tab" read -r meta p; do
    [ "$p" = "$2" ] || continue
    sha="${meta#* blob }"
    git cat-file blob "$sha" || _pk_die 3 "could not read $p from $1."
    return 0
  done < "$PK_S/members"
  _pk_die 1 "$1 has no member '$2'."
}

_pk_parents_ok() {  # <dest> <member path>: no component on the way to the member is a symlink or a file
  _d=$1; _r=$2
  while :; do
    case "$_r" in */*) ;; *) break ;; esac
    _d="$_d/${_r%%/*}"; _r="${_r#*/}"
    [ ! -L "$_d" ] || return 1   # return-class: predicate
    [ ! -e "$_d" ] || [ -d "$_d" ] || return 1   # return-class: predicate
  done
  return 0
}

pack_unpack() {  # [--missing] [--check] <pack> <dest>: every check runs before the first byte is written
  missing=0; check=0
  while :; do
    case "${1:-}" in --missing) missing=1 ;; --check) check=1 ;; *) break ;; esac
    shift
  done
  dest=$2
  _pk_open "$1"
  [ ! -L "$dest" ] || _pk_die 1 "unpack: $dest is a symlink."
  [ ! -e "$dest" ] || [ -d "$dest" ] || _pk_die 1 "unpack: $dest exists and is not a directory."
  : > "$PK_S/skip"
  while IFS="$_pk_tab" read -r meta p; do
    _pk_parents_ok "$dest" "$p" || _pk_die 1 "unpack: a symlink or a file is in the way of $dest/$p (nothing written)."
    if [ -e "$dest/$p" ] || [ -L "$dest/$p" ]; then
      if [ "$missing" = 1 ] && [ -f "$dest/$p" ] && [ ! -L "$dest/$p" ]; then
        printf '%s\n' "$p" >> "$PK_S/skip"
      else
        _pk_die 1 "unpack: $dest/$p already exists; this will not overwrite it (nothing written)."
      fi
    fi
  done < "$PK_S/members"
  [ "$check" = 0 ] || return 0
  mkdir -p "$dest" || _pk_die 3 "unpack: could not create $dest."
  while IFS="$_pk_tab" read -r meta p; do
    mode="${meta%% *}"; sha="${meta#* blob }"
    _pu_skip=0
    while IFS= read -r _pu_s; do [ "$_pu_s" = "$p" ] && { _pu_skip=1; break; }; done < "$PK_S/skip"
    if [ "$_pu_skip" = 1 ]; then printf 'kept %s\n' "$p"; continue; fi
    mkdir -p "$dest/$(dirname "$p")" || _pk_die 3 "unpack: could not create the directory for $p."
    PK_T="$(mktemp "$dest/$(dirname "$p")/.kitpack.XXXXXX")" || _pk_die 3 "unpack: could not create a file beside $p."
    git cat-file blob "$sha" > "$PK_T" || _pk_die 3 "unpack: could not write $p."
    if [ "$mode" = 100755 ]; then chmod 755 "$PK_T"; else chmod 644 "$PK_T"; fi
    mv "$PK_T" "$dest/$p" || _pk_die 3 "unpack: could not put $p in place."
    PK_T=""
    printf 'wrote %s\n' "$p"
  done < "$PK_S/members"
}

_pk_main() {
  _pm_cmd=${1:-}
  [ $# -eq 0 ] || shift
  case "$_pm_cmd" in
    -h|--help) _pk_usage; exit 0 ;;
    verify) [ $# -eq 1 ] || { _pk_usage >&2; exit 2; }   # exit-class: usage
            pack_verify "$1" ;;
    ls)     [ $# -eq 1 ] || { _pk_usage >&2; exit 2; }   # exit-class: usage
            pack_ls "$1" ;;
    cat)    [ $# -eq 2 ] || { _pk_usage >&2; exit 2; }   # exit-class: usage
            pack_cat "$1" "$2" ;;
    unpack) _pm_n=2
            for _pm_a in "$@"; do case "$_pm_a" in --missing|--check) _pm_n=$(( _pm_n + 1 )) ;; esac; done
            [ $# -eq "$_pm_n" ] || { _pk_usage >&2; exit 2; }   # exit-class: usage
            pack_unpack "$@" ;;
    build)  { [ $# -eq 4 ] || [ $# -eq 5 ]; } || { _pk_usage >&2; exit 2; }   # exit-class: usage
            pack_build "$@" ;;
    *)      _pk_usage >&2; exit 2 ;;   # exit-class: usage
  esac
}

# Run as a program, a verb runs; sourced (to read the names above), nothing does.
case "${0##*/}" in kitpack.sh) _pk_main "$@"; exit 0 ;; esac
