# KIT-CLASS: MIXED — self-test harness, kitpack reader and builder cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/packs.sh — sourced by scripts/test/run.sh, never run on its own.
# scripts/lib/kitpack.sh driven against FIXTURE packs that each case builds itself: no pack the
# kit ships is read here. A case fails, never skips, while the reader is absent.
# =============================================================================

# _pkc_names — "<dir> <ext> <ref>", read out of the reader so no case spells them.
_pkc_names() { ( . "$REAL_SCRIPTS/lib/kitpack.sh" >/dev/null 2>&1; printf '%s %s %s\n' "$KIT_PACK_DIR" "$KIT_PACK_EXT" "$KIT_PACK_REF" ); }

# _pkc_which <utility> — its path on the machine's PATH (a function or an alias of the same name does not count).
_pkc_which() {
  local d IFS=:
  for d in $PATH; do [ -n "$d" ] && [ -f "$d/$1" ] && [ -x "$d/$1" ] && { printf '%s\n' "$d/$1"; return 0; }; done
  return 1
}

# _pkc_fixture <dir> — the twelve-file source tree every round trip uses.
_pkc_fixture() {
  local d="$1"
  mkdir -p "$d/bin" "$d/deep/a/b/c" || return 1
  printf '#!/bin/sh\necho tool\n' > "$d/bin/tool.sh"; chmod 755 "$d/bin/tool.sh"
  printf '#!/bin/sh\necho second\n' > "$d/bin/second"; chmod 755 "$d/bin/second"
  printf 'one\r\ntwo\r\nthree\r\n' > "$d/crlf.txt"
  printf 'a\0b\001\002\0\377\n' > "$d/nul.bin"
  : > "$d/empty"
  printf 'x' > "$d/one"
  printf 'nested\n' > "$d/deep/a/b/c/d.txt"
  printf 'mixed\n' > "$d/Mixed-Case_1.md"
  printf 'odd\n' > "$d/at@sign+plus=eq,comma:colon.txt"
  printf 'no final newline' > "$d/noeol"
  printf 'one\ntwo\n' > "$d/lf.txt"
  printf '{"a": 1}\n' > "$d/a.json"
}

# _pkc_hostile <dir> <command…> — run a command under every kind of git configuration a machine or a caller can
# set: a global file, an environment-held key, an attributes file, a stray GIT_DIR and GIT_WORK_TREE.
_pkc_hostile() {
  local h="$1"; shift
  mkdir -p "$h"
  printf '* text eol=crlf\n' > "$h/attrs"
  printf '[core]\n\tautocrlf = true\n\tattributesFile = %s/attrs\n[pack]\n\tcompression = 1\n\twindow = 10\n\tthreads = 4\n[init]\n\tdefaultBranch = nonsense\n[transfer]\n\tfsckObjects = false\n' "$h" > "$h/gitconfig"
  env HOME="$h" XDG_CONFIG_HOME="$h" GIT_CONFIG_GLOBAL="$h/gitconfig" \
      GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=true \
      GIT_DIR="$h/no-such-git-dir" GIT_WORK_TREE="$h" "$@"
}

# _pkc_same_tree <a> <b> — 0 when the two directories hold the same files, bytes and executable bits.
_pkc_same_tree() {
  local a="$1" b="$2" f la lb
  diff -r "$a" "$b" >/dev/null 2>&1 || return 1
  la="$(cd "$a" && find . -type f | sort)"; lb="$(cd "$b" && find . -type f | sort)"
  [ "$la" = "$lb" ] || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -x "$a/$f" ]; then [ -x "$b/$f" ] || return 1; else [ ! -x "$b/$f" ] || return 1; fi
  done <<EOF_PKC_SAME
$la
EOF_PKC_SAME
  return 0
}

# _pkc_entry <mode> <path> — the top-level tree entry for ONE path, built from the innermost entry outward with
# `git mktree`, which does not judge names: a pack git's own check would refuse can be made here. Needs GIT_DIR and BLOB.
_pkc_entry() {
  local mode="$1" path="$2" name rest ent tree tab
  tab="$(printf '\t')"
  name="${path##*/}"; rest="${path%/*}"; [ "$rest" != "$path" ] || rest=""
  if [ "$mode" = 160000 ]; then ent="160000 commit 1111111111111111111111111111111111111111${tab}${name}"
  else ent="$mode blob $BLOB${tab}${name}"; fi
  while [ -n "$rest" ]; do
    tree="$(printf '%s\n' "$ent" | git mktree --missing)" || return 1
    name="${rest##*/}"
    if [ "$rest" = "$name" ]; then rest=""; else rest="${rest%/*}"; fi
    ent="040000 tree $tree${tab}${name}"
  done
  printf '%s\n' "$ent"
}

# _pkc_raw_bundle <out> <shape> [<mode> <path>] — a bundle built with git's plumbing, past the builder's checks.
# Every shape holds good.txt. Shapes: entry (the one hostile entry), two-refs, other-ref, parent, empty.
_pkc_raw_bundle() {
  local out="$1" shape="$2" mode="${3:-}" path="${4:-}" g tab top tree c c2 id
  tab="$(printf '\t')"
  g="$(mktemp -d)" || return 1
  id="GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@b.invalid GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@b.invalid"
  (
    git init -q --bare "$g" || exit 1
    export GIT_DIR="$g" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    BLOB="$(printf 'x\n' | git hash-object -w --stdin)"; export BLOB
    if [ "$shape" = empty ]; then
      tree="$(printf '' | git mktree)"
    else
      top=""; [ "$shape" != entry ] || top="$(_pkc_entry "$mode" "$path")"
      tree="$( { printf '100644 blob %s%sgood.txt\n' "$BLOB" "$tab"; [ -z "$top" ] || printf '%s\n' "$top"; } | git mktree --missing)"
    fi
    c="$(echo m | env $id git commit-tree "$tree")"
    git update-ref refs/kit/p "$c"
    case "$shape" in
      two-refs) git update-ref refs/kit/q "$c"; git bundle create "$out" refs/kit/p refs/kit/q >/dev/null 2>&1 ;;
      other-ref) git update-ref refs/heads/p "$c"; git update-ref -d refs/kit/p; git bundle create "$out" refs/heads/p >/dev/null 2>&1 ;;
      parent) c2="$(echo m2 | env $id git commit-tree "$tree" -p "$c")"; git update-ref refs/kit/p "$c2"; git bundle create "$out" refs/kit/p >/dev/null 2>&1 ;;
      *) git bundle create "$out" refs/kit/p >/dev/null 2>&1 ;;
    esac
  )
  local rc=$?
  rm -rf "$g"
  [ "$rc" -eq 0 ] && [ -s "$out" ]
}

# _pkc_nfiles <dir> — the number of files under <dir>, 0 when it is not there.
_pkc_nfiles() { if [ -d "$1" ]; then find "$1" -type f | wc -l | tr -d ' '; else echo 0; fi; }

# =============================================================================
# CASE — A PACK BUILT FROM FILES UNPACKS TO THE SAME FILES, BYTE FOR BYTE.
# Twelve files: executable, CRLF-bearing, NUL-bearing, empty, one byte, no final newline, nested.
# Built, verified and unpacked clean and under a hostile git configuration, then compared with
# diff, cmp and the executable bit.
# =============================================================================
case_pack_round_trip_is_byte_equal() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" t out rc
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: there is no reader to drive"; finish "a pack built from twelve files verifies and unpacks to the same files, bytes and executable bits, clean and under a hostile git configuration"; return; }
  t="$(mktemp -d)" || _fixture_die "case_pack_round_trip_is_byte_equal: no scratch directory"
  _pkc_fixture "$t/src" || _fixture_die "case_pack_round_trip_is_byte_equal: the fixture was not written"

  sh "$kp" build "$t/src" "$t/clean.kitpack" demo 1700000000 >/dev/null 2>&1 || cf "(a) the clean build failed"
  out="$(sh "$kp" verify "$t/clean.kitpack" 2>&1)"
  [ "$out" = "ok: 12 members" ] || cf "(b) verify printed '$out', want 'ok: 12 members'"
  out="$(sh "$kp" unpack "$t/clean.kitpack" "$t/clean-out" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(c) unpack exited $rc: $(printf '%s' "$out" | head -2 | tr '\n' '|')"
  _pkc_same_tree "$t/src" "$t/clean-out" || cf "(d) the clean round trip changed a file, a byte or an executable bit"

  _pkc_hostile "$t/h1" sh "$kp" build "$t/src" "$t/hostile.kitpack" demo 1700000000 >/dev/null 2>&1 || cf "(e) the build under a hostile configuration failed"
  _pkc_hostile "$t/h2" sh "$kp" unpack "$t/hostile.kitpack" "$t/hostile-out" >/dev/null 2>&1 || cf "(f) unpack under a hostile configuration failed"
  _pkc_same_tree "$t/src" "$t/hostile-out" || cf "(g) under a hostile configuration (autocrlf, an eol attribute, a stray GIT_DIR) a file, a byte or an executable bit changed"
  [ -f "$t/hostile.kitpack" ] && cmp -s "$t/clean.kitpack" "$t/hostile.kitpack" || cf "(h) the pack built under a hostile configuration differs from the clean one"

  mkdir "$t/empty-dir"
  sh "$kp" unpack "$t/clean.kitpack" "$t/empty-dir" >/dev/null 2>&1 && _pkc_same_tree "$t/src" "$t/empty-dir" || cf "(i) unpacking into an existing empty directory failed or changed a file"

  finish "a pack built from twelve files (executable, CRLF-bearing, NUL-bearing, empty, one byte, no final newline, nested) verifies as 12 members and unpacks to the same files, bytes and executable bits, clean and under a hostile git configuration, and the two packs are the same bytes"
  rm -rf "$t"
}

# =============================================================================
# CASE — A PACK IS A FUNCTION OF ITS MEMBERS AND THE EPOCH, AND OF NOTHING ELSE.
# The same bytes after a rebuild, other mtimes, another location, another TZ, a hostile git
# configuration, a stray GIT_DIR, under dash and bash; the control: one second more differs.
# =============================================================================
case_pack_is_a_function_of_its_members() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" t sh_
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: there is no builder to drive"; finish "a pack's bytes are a function of its members and the epoch"; return; }
  t="$(mktemp -d)" || _fixture_die "case_pack_is_a_function_of_its_members: no scratch directory"
  _pkc_fixture "$t/src" || _fixture_die "case_pack_is_a_function_of_its_members: the fixture was not written"
  sh "$kp" build "$t/src" "$t/base.kitpack" demo 1700000000 >/dev/null 2>&1 || cf "(a) the base build failed"

  sh "$kp" build "$t/src" "$t/again.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/base.kitpack" "$t/again.kitpack" || cf "(b) a rebuild differs"
  ( cd "$t/src" && find . -type f -exec touch -t 200001010101 {} + ) || _fixture_die "case_pack_is_a_function_of_its_members: touch failed"
  cp -R "$t/src" "$t/elsewhere" || _fixture_die "case_pack_is_a_function_of_its_members: the copy failed"
  sh "$kp" build "$t/src" "$t/mtime.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/base.kitpack" "$t/mtime.kitpack" || cf "(c) other mtimes change the pack"
  sh "$kp" build "$t/elsewhere" "$t/where.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/base.kitpack" "$t/where.kitpack" || cf "(d) the source's location changes the pack"
  TZ=America/New_York sh "$kp" build "$t/src" "$t/tz.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/base.kitpack" "$t/tz.kitpack" || cf "(e) the time zone changes the pack"
  _pkc_hostile "$t/h" sh "$kp" build "$t/src" "$t/hostile.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/base.kitpack" "$t/hostile.kitpack" || cf "(f) a hostile git configuration (pack.compression=1, a stray GIT_DIR) changes the pack"
  bash "$kp" build "$t/src" "$t/bash.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/base.kitpack" "$t/bash.kitpack" || cf "(g) bash builds other bytes than sh"
  sh_="$(_pkc_which dash || true)"
  if [ -n "$sh_" ]; then
    "$sh_" "$kp" build "$t/src" "$t/dash.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/base.kitpack" "$t/dash.kitpack" || cf "(h) dash builds other bytes than sh"
  fi
  sh "$kp" build "$t/src" "$t/epoch.kitpack" demo 1700000001 >/dev/null 2>&1 || cf "(i) the epoch+1 build failed"
  if [ -f "$t/epoch.kitpack" ] && cmp -s "$t/base.kitpack" "$t/epoch.kitpack"; then cf "(control) one second more of epoch gave the same pack: the comparison above could not have seen a difference"; fi
  printf 'changed\n' >> "$t/src/lf.txt"
  sh "$kp" build "$t/src" "$t/member.kitpack" demo 1700000000 >/dev/null 2>&1
  if [ -f "$t/member.kitpack" ] && cmp -s "$t/base.kitpack" "$t/member.kitpack"; then cf "(control) a changed member gave the same pack"; fi

  finish "a pack is byte-identical after a rebuild, other mtimes, another source location, another TZ, a hostile git configuration with a stray GIT_DIR, and under bash${sh_:+ and dash}; one second more of epoch and one changed member each give different bytes"
  rm -rf "$t"
}

# =============================================================================
# CASE — A HOSTILE PACK IS REFUSED, NAMING THE MEMBER, AND NOTHING IS WRITTEN.
# Each row is a bundle built past the builder's checks. The destination is left as it was. Positive
# controls (a nested member, a flat one) are written. The path rules are also driven on their own,
# because a newer git refuses `.git` and `..` before the reader looks.
# =============================================================================
case_pack_reader_refuses_hostile_members() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" t row name mode path want out rc n
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: there is no reader to drive"; finish "each hostile pack is refused with nothing written"; return; }
  t="$(mktemp -d)" || _fixture_die "case_pack_reader_refuses_hostile_members: no scratch directory"
  n=0

  # name|mode|path|the text the refusal must carry ('-' when git may refuse first)
  for row in 'symlink|120000|link|link' 'gitlink|160000|sub|sub' 'space|100644|a b.txt|a b.txt' 'dash|100644|-rf|-rf' \
             'quote|100644|a"b|a\"b' 'dotgit|100644|.git/hooks/post-checkout|-' 'dotgit-upper|100644|.GIT/config|-' \
             'dotgit-mid|100644|sub/.git/config|-' 'dotdot|100644|../escape.txt|-'; do
    name="${row%%|*}"; row="${row#*|}"; mode="${row%%|*}"; row="${row#*|}"; path="${row%|*}"; want="${row##*|}"
    n=$(( n + 1 ))
    _pkc_raw_bundle "$t/$name.kitpack" entry "$mode" "$path" || { _fixture_die "case_pack_reader_refuses_hostile_members: the $name bundle was not built"; }
    out="$(sh "$kp" unpack "$t/$name.kitpack" "$t/out-$name" 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || cf "($name) a pack holding '$path' was unpacked"
    [ "$(_pkc_nfiles "$t/out-$name")" -eq 0 ] || cf "($name) files were written for a refused pack: $(find "$t/out-$name" -type f | head -3 | tr '\n' ' ')"
    if [ "$want" != - ]; then
      case "$out" in *"$want"*) ;; *) cf "($name) the refusal does not name the member '$want': $(printf '%s' "$out" | head -2 | tr '\n' '|')" ;; esac
    fi
    sh "$kp" verify "$t/$name.kitpack" >/dev/null 2>&1 && cf "($name) verify accepts it"
  done

  for row in two-refs other-ref parent empty; do
    n=$(( n + 1 ))
    _pkc_raw_bundle "$t/$row.kitpack" "$row" || { _fixture_die "case_pack_reader_refuses_hostile_members: the $row bundle was not built"; }
    sh "$kp" unpack "$t/$row.kitpack" "$t/out-$row" >/dev/null 2>&1 && cf "($row) the pack was unpacked"
    [ "$(_pkc_nfiles "$t/out-$row")" -eq 0 ] || cf "($row) files were written for a refused pack"
  done

  _pkc_fixture "$t/src" || _fixture_die "case_pack_reader_refuses_hostile_members: the fixture was not written"
  sh "$kp" build "$t/src" "$t/good.kitpack" demo 1700000000 >/dev/null 2>&1 || _fixture_die "case_pack_reader_refuses_hostile_members: the control pack was not built"
  local size; size="$(wc -c < "$t/good.kitpack" | tr -d ' ')"
  head -c $(( size - 7 )) "$t/good.kitpack" > "$t/truncated.kitpack"
  cp "$t/good.kitpack" "$t/flipped.kitpack"
  printf '\377' | dd of="$t/flipped.kitpack" bs=1 seek=$(( size - 60 )) conv=notrunc 2>/dev/null
  printf 'this is not a bundle\n' > "$t/notabundle.kitpack"
  for name in truncated flipped notabundle; do
    n=$(( n + 1 ))
    out="$(sh "$kp" unpack "$t/$name.kitpack" "$t/out-$name" 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || cf "($name) a damaged pack was unpacked"
    case "$out" in *"not a whole kitpack"*) ;; *) cf "($name) the refusal does not say the pack is not a whole kitpack: $(printf '%s' "$out" | head -2 | tr '\n' '|')" ;; esac
    [ "$(_pkc_nfiles "$t/out-$name")" -eq 0 ] || cf "($name) files were written for a damaged pack"
  done

  # Positive controls: the same shape with a legal nested path and a legal flat one is written.
  _pkc_raw_bundle "$t/ok-nested.kitpack" entry 100644 "good/a.txt" && _pkc_raw_bundle "$t/ok-flat.kitpack" entry 100755 "flat" || _fixture_die "case_pack_reader_refuses_hostile_members: the control bundles were not built"
  sh "$kp" unpack "$t/ok-nested.kitpack" "$t/out-ok-nested" >/dev/null 2>&1 && [ "$(_pkc_nfiles "$t/out-ok-nested")" -eq 2 ] || cf "(control) a nested legal member was not written"
  sh "$kp" unpack "$t/ok-flat.kitpack" "$t/out-ok-flat" >/dev/null 2>&1 && [ -x "$t/out-ok-flat/flat" ] || cf "(control) a flat executable member was not written"

  # The path rules on their own: a fixed answer for each row.
  local p ok
  for p in 'a' 'a/b.txt' 'x/.gitignore' 'x/.github/y' 'Mixed-Case_1.md' 'at@sign+plus=eq,comma:colon.txt' 'a-b/c'; do
    ( . "$kp" >/dev/null 2>&1; _pk_path_ok "$p" ) || cf "(path) '$p' is refused, and it is legal"
  done
  for p in '' '/abs' 'a//b' 'a/' '.' '..' './a' 'a/.' '../a' 'a/..' 'a/../b' 'a/./b' 'a b' '-a' 'a/-b' '.git' '.git/hooks/x' '.GIT/config' 'sub/.git/config' 'sub/.Git' 'a"b' 'a*b' 'caf'$'\303\251'; do
    ok=0; ( . "$kp" >/dev/null 2>&1; _pk_path_ok "$p" ) && ok=1
    [ "$ok" -eq 0 ] || cf "(path) '$p' is allowed, and it is outside the format"
  done

  finish "$n hostile packs (a symlink, a gitlink, a space, a leading dash, a quote, .git at three depths and in capitals, .., a second ref, a ref outside refs/kit, a parent commit, an empty tree, a truncated pack, a flipped byte, a non-bundle) are each refused with nothing written and, where git does not refuse first, the member named; a nested and a flat legal member are written; the path rules answer a fixed table on their own"
  rm -rf "$t"
}

# =============================================================================
# CASE — UNPACK NEVER OVERWRITES, AND NEVER WRITES THROUGH A LINK.
# A member that exists refuses the whole unpack before a byte is written; a symlink on the way
# to a member refuses it and nothing is written through the link; an existing empty directory
# takes every member; --missing leaves what is there and writes the rest.
# =============================================================================
case_pack_reader_refuses_to_overwrite() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" t before out rc
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: there is no reader to drive"; finish "unpack never overwrites and never writes through a link"; return; }
  t="$(mktemp -d)" || _fixture_die "case_pack_reader_refuses_to_overwrite: no scratch directory"
  _pkc_fixture "$t/src" || _fixture_die "case_pack_reader_refuses_to_overwrite: the fixture was not written"
  sh "$kp" build "$t/src" "$t/p.kitpack" demo 1700000000 >/dev/null 2>&1 || _fixture_die "case_pack_reader_refuses_to_overwrite: the pack was not built"

  mkdir -p "$t/d1/deep/a/b/c"; printf 'mine\n' > "$t/d1/deep/a/b/c/d.txt"
  before="$(_pkc_nfiles "$t/d1")"
  out="$(sh "$kp" unpack "$t/p.kitpack" "$t/d1" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(a) unpack over an existing member exited 0"
  case "$out" in *"deep/a/b/c/d.txt"*) ;; *) cf "(a) the refusal does not name the member: $(printf '%s' "$out" | head -2 | tr '\n' '|')" ;; esac
  [ "$(_pkc_nfiles "$t/d1")" -eq "$before" ] || cf "(a) files were written before the refusal ($before before, $(_pkc_nfiles "$t/d1") after)"
  [ "$(cat "$t/d1/deep/a/b/c/d.txt")" = mine ] || cf "(a) the existing member was overwritten"

  mkdir -p "$t/outside" "$t/d2"; ln -s "$t/outside" "$t/d2/deep"
  out="$(sh "$kp" unpack "$t/p.kitpack" "$t/d2" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || cf "(b) unpack through a symlink exited 0"
  [ "$(_pkc_nfiles "$t/outside")" -eq 0 ] || cf "(b) files were written through the symlink: $(find "$t/outside" -type f | head -3 | tr '\n' ' ')"
  [ "$(_pkc_nfiles "$t/d2")" -eq 0 ] || cf "(b) files were written beside a refused link"

  mkdir "$t/d3"; ln -s "$t/outside" "$t/d4"
  sh "$kp" unpack "$t/p.kitpack" "$t/d4" >/dev/null 2>&1 && cf "(c) unpack into a symlinked destination exited 0"
  [ "$(_pkc_nfiles "$t/outside")" -eq 0 ] || cf "(c) files were written through the destination link"

  sh "$kp" unpack "$t/p.kitpack" "$t/d3" >/dev/null 2>&1 && _pkc_same_tree "$t/src" "$t/d3" || cf "(d) unpack into an existing empty directory failed or changed a file"

  mkdir -p "$t/d5/deep/a/b/c"; printf 'mine\n' > "$t/d5/deep/a/b/c/d.txt"
  out="$(sh "$kp" unpack --missing "$t/p.kitpack" "$t/d5" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || cf "(e) unpack --missing exited $rc: $(printf '%s' "$out" | head -2 | tr '\n' '|')"
  [ "$(cat "$t/d5/deep/a/b/c/d.txt")" = mine ] || cf "(e) --missing overwrote the member that was there"
  [ "$(_pkc_nfiles "$t/d5")" -eq 12 ] || cf "(e) --missing left $(_pkc_nfiles "$t/d5") files, want 12"
  case "$out" in *"kept deep/a/b/c/d.txt"*) ;; *) cf "(e) --missing did not say it kept the member that was there" ;; esac

  mkdir -p "$t/d6/deep"; mkdir "$t/d6/deep/a" ; printf 'x' > "$t/d6/deep/a/b"
  sh "$kp" unpack --missing "$t/p.kitpack" "$t/d6" >/dev/null 2>&1 && cf "(f) --missing wrote over a file where a directory must go"

  finish "unpack refuses, before writing a byte, a member that exists (named), a symlink on the way (nothing written through it) and a symlinked destination; an existing empty directory takes all twelve members; --missing keeps the member that is there, says so, and writes the other eleven"
  rm -rf "$t"
}

# =============================================================================
# CASE — THE READER RUNS ON THE FLOOR: git AND A POSIX SHELL, AND NOTHING ELSE.
# verify, ls, cat, unpack and build run with a PATH that holds exactly the utilities listed here
# (and, if the machine has it, dash), and give the same bytes as with the machine's own PATH.
# The control: none of the archivers or interpreters resolves on that PATH.
# =============================================================================
case_pack_reader_runs_on_the_floor() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" t u p farm w sh_ out
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: there is no reader to drive"; finish "the reader runs with only git and the floor's utilities on PATH"; return; }
  t="$(mktemp -d)" || _fixture_die "case_pack_reader_runs_on_the_floor: no scratch directory"
  farm="$t/farm"; mkdir "$farm"
  for u in cat chmod cmp diff dirname find git head mkdir mktemp rm sed sh sort tr wc dash; do
    p="$(_pkc_which "$u" || true)"
    if [ -n "$p" ]; then ln -s "$p" "$farm/$u"
    elif [ "$u" != dash ]; then _fixture_die "case_pack_reader_runs_on_the_floor: '$u' is not on this machine's PATH"; fi
  done
  _pkc_fixture "$t/src" || _fixture_die "case_pack_reader_runs_on_the_floor: the fixture was not written"

  for w in tar gzip gunzip unzip zip cpio bzip2 xz perl python python3 node ruby; do
    [ ! -e "$farm/$w" ] || _fixture_die "case_pack_reader_runs_on_the_floor: the utility list holds '$w'"
    out="$(env -i PATH="$farm" sh -c "command -v $w" 2>/dev/null || true)"
    [ -z "$out" ] || cf "(control) '$w' resolves on the restricted PATH ($out), so it proves nothing about the reader"
  done

  sh "$kp" build "$t/src" "$t/ref.kitpack" demo 1700000000 >/dev/null 2>&1 || _fixture_die "case_pack_reader_runs_on_the_floor: the reference pack was not built"
  sh "$kp" unpack "$t/ref.kitpack" "$t/ref-out" >/dev/null 2>&1 || _fixture_die "case_pack_reader_runs_on_the_floor: the reference unpack failed"

  for sh_ in sh dash; do
    [ -e "$farm/$sh_" ] || continue
    out="$t/$sh_"; mkdir "$out"
    env -i PATH="$farm" "$sh_" "$kp" build "$t/src" "$out/b.kitpack" demo 1700000000 >/dev/null 2>&1 && cmp -s "$t/ref.kitpack" "$out/b.kitpack" || cf "($sh_) build on the floor failed or gave other bytes"
    [ "$(env -i PATH="$farm" "$sh_" "$kp" verify "$t/ref.kitpack" 2>&1)" = "ok: 12 members" ] || cf "($sh_) verify on the floor did not print 'ok: 12 members'"
    [ "$(env -i PATH="$farm" "$sh_" "$kp" ls "$t/ref.kitpack" 2>&1 | wc -l | tr -d ' ')" -eq 12 ] || cf "($sh_) ls on the floor did not list 12 members"
    env -i PATH="$farm" "$sh_" "$kp" cat "$t/ref.kitpack" nul.bin 2>/dev/null | cmp -s - "$t/src/nul.bin" || cf "($sh_) cat on the floor gave other bytes for nul.bin"
    env -i PATH="$farm" "$sh_" "$kp" unpack "$t/ref.kitpack" "$out/u" >/dev/null 2>&1 && _pkc_same_tree "$t/ref-out" "$out/u" || cf "($sh_) unpack on the floor failed or differs from the unpack on the machine's PATH"
  done

  finish "build, verify, ls, cat and unpack run under a PATH holding only cat chmod cmp diff dirname find git head mkdir mktemp rm sed sh sort tr wc (and dash where there is one) and give the same bytes as the machine's own PATH; none of tar, gzip, gunzip, unzip, zip, cpio, bzip2, xz, perl, python, python3, node or ruby resolves there"
  rm -rf "$t"
}

# _pkc_floor_scan <root> — every command-position use of an archiver in the programs a tree ships:
# the manifest's shell programs (less the harness, the modules and the one optional program that
# publishes a tarball), then every member of every pack under <root>/packs that is a shell program.
# One "<where>: <line>" per hit. _pkc_pack_programs is the pack read, a function so a case can take it away.
_pkc_archivers() { printf '%s\n' tar gzip gunzip unzip zip cpio bzip2 xz; }
_pkc_exempt_program() { case "$1" in scripts/test/*|modules/*|scripts/release.sh) return 0 ;; esac; return 1; }   # return-class: predicate
_pkc_pack_programs() {  # <root> <scratch> — extracts each shell program inside a pack to <scratch>; prints "<pack>:<member>\t<file>"
  local root="$1" scr="$2" pack m f i=0 tab kp="$REAL_SCRIPTS/lib/kitpack.sh"
  tab="$(printf '\t')"
  for pack in "$root"/packs/*.kitpack; do
    [ -f "$pack" ] || continue
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      i=$(( i + 1 )); f="$scr/m$i"
      sh "$kp" cat "$pack" "$m" > "$f" 2>/dev/null || continue
      case "$(head -1 "$f")" in '#!'*sh) printf '%s:%s%s%s\n' "${pack##*/}" "$m" "$tab" "$f" ;; esac
    done <<EOF_PKC_LS
$(sh "$kp" ls "$pack" 2>/dev/null | sed 's/^[0-9]* //')
EOF_PKC_LS
  done
}
_pkc_floor_scan() {  # <root>
  local root="$1" scr rel f w hits n=0 tab
  tab="$(printf '\t')"
  scr="$(mktemp -d)" || return 1
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    _pkc_exempt_program "$rel" && continue
    f="$root/$rel"; [ -f "$f" ] || continue
    case "$(head -1 "$f" 2>/dev/null)" in '#!'*sh) ;; *) continue ;; esac
    for w in $(_pkc_archivers); do
      hits="$(_floor_hits "$w" "$root" "$f")"
      [ -z "$hits" ] || printf '%s\n' "$hits" | sed "s|^|$rel:|"
    done
  done <<EOF_PKC_MAN
$(grep -v '^#' "$root/process/KIT-MANIFEST" | awk '{print $2}')
EOF_PKC_MAN
  while IFS="$tab" read -r rel f; do
    [ -n "$rel" ] || continue
    _pkc_exempt_program "${rel#*:}" && continue
    for w in $(_pkc_archivers); do
      hits="$(_floor_hits "$w" "$scr" "$f")"
      [ -z "$hits" ] || printf '%s\n' "$hits" | sed "s|^|$rel:|"
    done
  done <<EOF_PKC_PK
$(_pkc_pack_programs "$root" "$scr")
EOF_PKC_PK
  rm -rf "$scr"
  return 0
}

# =============================================================================
# CASE — NO PROGRAM THE KIT SHIPS, LOOSE OR PACKED, REACHES FOR AN ARCHIVER.
# A pack's members are no manifest rows, so a census that walks the manifest never sees them.
# The control plants an archiver call in a loose program and in a pack member and finds both;
# with the pack read taken away the planted member goes unseen, which is the silent shrink.
# The one named exemption is the optional release program, which publishes a tarball.
# =============================================================================
case_pack_programs_stay_on_the_floor() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" man="$REAL_REPO_ROOT/process/KIT-MANIFEST" t got want w1 w2 hits npk=0 pack
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: there is no reader to drive"; finish "no shipped program, loose or packed, invokes an archiver"; return; }
  [ -f "$man" ] || _fixture_die "case_pack_programs_stay_on_the_floor: process/KIT-MANIFEST is absent, which the startup guard should already have refused."
  t="$(mktemp -d)" || _fixture_die "case_pack_programs_stay_on_the_floor: no scratch directory"
  w1="t""ar"; w2="un""zip"   # built from parts: this file's own text is part of the harness population

  # THE CONTROL: a tree with a manifest, one loose program that calls an archiver, one clean, and a pack holding the same two.
  mkdir -p "$t/c/process" "$t/c/scripts" "$t/c/packsrc/scripts" "$t/c/packs"
  printf '#!/bin/sh\n%s xf x.tgz\n' "$w1" > "$t/c/scripts/loose.sh"
  printf '#!/bin/sh\necho clean\n' > "$t/c/scripts/clean.sh"
  printf '#!/bin/sh\n# %s is only mentioned\nout=$(%s -o x.zip)\n' "$w1" "$w2" > "$t/c/packsrc/scripts/inpack.sh"
  printf '#!/bin/sh\necho clean\n' > "$t/c/packsrc/scripts/clean-inpack.sh"
  printf 'aa  scripts/loose.sh  KIT  -\naa  scripts/clean.sh  KIT  -\n' > "$t/c/process/KIT-MANIFEST"
  sh "$kp" build "$t/c/packsrc" "$t/c/packs/p.kitpack" p 1700000000 >/dev/null 2>&1 || _fixture_die "case_pack_programs_stay_on_the_floor: the control pack was not built"
  got="$(_pkc_floor_scan "$t/c" | sed 's/: .*//' | sort | tr '\n' ' ')"
  want="p.kitpack:scripts/inpack.sh:3 scripts/loose.sh:2 "
  [ "$got" = "$want" ] || cf "(instrument) the scan read its planted control as [$got], want [$want]; every verdict below is untrustworthy"
  got="$(_pkc_pack_programs() { :; }; _pkc_floor_scan "$t/c" | sed 's/: .*//' | sort | tr '\n' ' ')"
  [ "$got" = "scripts/loose.sh:2 " ] || cf "(ablation) with the pack read taken away the control read [$got], want only the loose program: the member in the pack is what the pack read finds"

  # THE TREE.
  hits="$(_pkc_floor_scan "$REAL_REPO_ROOT")"
  [ -z "$hits" ] || cf "a shipped program invokes an archiver, which is past the kit's floor (git and a POSIX shell): $(printf '%s' "$hits" | head -3 | tr '\n' '|')"
  # The exemption must still be needed: a program that stopped using the archiver should lose its row.
  hits=""; for w1 in $(_pkc_archivers); do hits="$hits$(_floor_hits "$w1" "$REAL_REPO_ROOT" "$REAL_REPO_ROOT/scripts/release.sh")"; done
  [ -n "$hits" ] || cf "scripts/release.sh no longer calls an archiver, so its exemption here is stale"
  for pack in "$REAL_REPO_ROOT"/packs/*.kitpack; do [ -f "$pack" ] && npk=$(( npk + 1 )); done

  finish "no shell program the manifest names (less the harness, the modules and scripts/release.sh, which publishes a tarball and still does) and none of the $npk pack(s) in this tree invokes tar, gzip, gunzip, unzip, zip, cpio, bzip2 or xz; the control finds an archiver planted in a loose program and in a pack member, and with the pack read taken away misses the one in the pack"
  rm -rf "$t"
}

# =============================================================================
# CASE — A ROOT .gitattributes CANNOT CHANGE A PACK'S BYTES.
# In a scratch repository whose root attributes force CRLF on every text file, a pack under
# packs/ is committed and cloned: with the shipped packs/.gitattributes it comes back intact.
# The control: without that file the same clone changes the bytes, so the probe can see a loss.
# =============================================================================
case_pack_survives_the_adopters_git_attributes() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" attr dir t r names
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: there is no reader to drive"; finish "a pack survives a root .gitattributes that forces CRLF"; return; }
  names="$(_pkc_names)"; dir="${names%% *}"
  attr="$REAL_REPO_ROOT/$dir/.gitattributes"
  [ -f "$attr" ] || { cf "$dir/.gitattributes is not shipped: a root attribute line such as '* text eol=crlf' would rewrite every pack in a clone"; finish "a pack survives a root .gitattributes that forces CRLF"; return; }
  t="$(mktemp -d)" || _fixture_die "case_pack_survives_the_adopters_git_attributes: no scratch directory"
  _pkc_fixture "$t/src" || _fixture_die "case_pack_survives_the_adopters_git_attributes: the fixture was not written"
  sh "$kp" build "$t/src" "$t/fix.kitpack" demo 1700000000 >/dev/null 2>&1 || _fixture_die "case_pack_survives_the_adopters_git_attributes: the pack was not built"

  for r in with without; do
    mkdir -p "$t/$r/$dir"
    ( cd "$t/$r" && git init -q . && git config user.email t@example.invalid && git config user.name t && git config commit.gpgsign false ) >/dev/null 2>&1 || _fixture_die "case_pack_survives_the_adopters_git_attributes: git init failed"
    printf '* text eol=crlf\n' > "$t/$r/.gitattributes"
    cp "$t/fix.kitpack" "$t/$r/$dir/fix.kitpack"
    [ "$r" = with ] && cp "$attr" "$t/$r/$dir/.gitattributes"
    ( cd "$t/$r" && git add -A && git commit -q -m fixture && git clone -q . "$t/$r-clone" ) >/dev/null 2>&1 || _fixture_die "case_pack_survives_the_adopters_git_attributes: the scratch commit and clone failed"
  done
  cmp -s "$t/fix.kitpack" "$t/with-clone/$dir/fix.kitpack" || cf "(a) with the shipped $dir/.gitattributes the pack's bytes changed in a clone"
  cmp -s "$t/fix.kitpack" "$t/without-clone/$dir/fix.kitpack" && cf "(control) without $dir/.gitattributes the bytes did not change either: this git does not rewrite the pack here, so the case proves nothing about the shipped file"
  sh "$kp" verify "$t/with-clone/$dir/fix.kitpack" >/dev/null 2>&1 || cf "(b) the cloned pack no longer verifies"

  finish "in a repository whose root .gitattributes forces CRLF, a pack committed beside the shipped $dir/.gitattributes comes back from a clone byte for byte and verifies; without that file the same clone changes it"
  rm -rf "$t"
}

# _pkc_named_outside <root> <ere>… — the shipped text files under <root> that match any <ere>, less the files that may:
# the pack interface itself and the records that list files. One path per line.
_pkc_named_outside() {
  local root="$1" rel f n; shift
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in
      scripts/test/*|scripts/lib/kitpack.sh|scripts/pack.sh|process/contracts/pack.md|process/MODULES.md|process/EXTRACTION.md) continue ;;
      process/KIT-MANIFEST|process/KIT-RELEASE-NOTES.md|process/KIT-RELEASE-HISTORY.md|*.kitpack) continue ;;
    esac
    f="$root/$rel"; [ -f "$f" ] || continue
    for n in "$@"; do
      if grep -sIE -e "$n" "$f" >/dev/null 2>&1; then printf '%s\n' "$rel"; break; fi
    done
  done <<EOF_PKC_NAMED
$(grep -v '^#' "$root/process/KIT-MANIFEST" | awk '{print $2}')
EOF_PKC_NAMED
}

# =============================================================================
# CASE — THE PACK DIRECTORY AND EXTENSION ARE NAMED ONCE.
# The reader holds them in one assignment each; process/MODULES.md names the directory for a
# reader of the kit; no other shipped file spells either, except the pack interface itself
# (scripts/pack.sh, its contract), the lists of files and the harness.
# =============================================================================
case_packs_dir_is_named_once() {
  cf_reset
  local kp="$REAL_SCRIPTS/lib/kitpack.sh" names dir ext man="$REAL_REPO_ROOT/process/KIT-MANIFEST" t got rel n
  [ -f "$kp" ] || { cf "scripts/lib/kitpack.sh is absent: the directory and the extension are named nowhere"; finish "the pack directory and extension are named once"; return; }
  [ -f "$man" ] || _fixture_die "case_packs_dir_is_named_once: process/KIT-MANIFEST is absent, which the startup guard should already have refused."
  names="$(_pkc_names)"; dir="${names%% *}"; ext="${names#* }"; ext="${ext%% *}"
  [ -n "$dir" ] && [ -n "$ext" ] || { cf "the reader names no directory or no extension (KIT_PACK_DIR='$dir', KIT_PACK_EXT='$ext')"; finish "the pack directory and extension are named once"; return; }
  [ "$(grep -c '^KIT_PACK_DIR=' "$kp")" -eq 1 ] && [ "$(grep -c '^KIT_PACK_EXT=' "$kp")" -eq 1 ] || cf "(a) the reader assigns KIT_PACK_DIR or KIT_PACK_EXT other than once"

  [ -f "$REAL_REPO_ROOT/process/MODULES.md" ] || { cf "process/MODULES.md is absent"; finish "the pack directory and extension are named once"; return; }
  grep -qF "$dir/" "$REAL_REPO_ROOT/process/MODULES.md" || cf "(b) process/MODULES.md does not name $dir/"

  got="$(_pkc_named_outside "$REAL_REPO_ROOT" "(^|[^A-Za-z0-9_])$dir/" "\\.$ext")"
  [ -z "$got" ] || cf "(c) shipped file(s) outside the pack interface spell the pack directory or extension: $(printf '%s' "$got" | head -5 | tr '\n' ' ')"
  # Programs name neither as a literal either: they ask the reader. Every shipped shell program but the reader and the harness.
  n=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in scripts/test/*|scripts/lib/kitpack.sh) continue ;; esac
    [ -f "$REAL_REPO_ROOT/$rel" ] || continue
    case "$(head -1 "$REAL_REPO_ROOT/$rel")" in '#!'*sh) ;; *) continue ;; esac
    n=$(( n + 1 ))
    grep -nE "(KIT_PACK_DIR|KIT_PACK_EXT)=|=\"?$dir\"?([[:space:]]|\$)|\\.$ext\"" "$REAL_REPO_ROOT/$rel" 2>/dev/null | grep -v '^[0-9]*:[[:space:]]*#' >/dev/null && cf "(d) $rel assigns the pack directory or extension itself instead of asking the reader"
  done <<EOF_PKC_PROGS
$(grep -v '^#' "$man" | awk '{print $2}')
EOF_PKC_PROGS
  [ "$n" -gt 0 ] || cf "(instrument) not one shipped shell program was read"

  # THE CONTROL: a doc outside the allowed set that names the directory is found, and one that does not is not.
  t="$(mktemp -d)" || _fixture_die "case_packs_dir_is_named_once: no scratch directory"
  mkdir -p "$t/c/process" "$t/c/docs"
  printf 'aa  docs/names.md  KIT  -\naa  docs/silent.md  KIT  -\naa  process/MODULES.md  KIT  -\n' > "$t/c/process/KIT-MANIFEST"
  printf 'see %s/ for them\n' "$dir" > "$t/c/docs/names.md"; printf 'nothing here\n' > "$t/c/docs/silent.md"; printf 'names %s/ too\n' "$dir" > "$t/c/process/MODULES.md"
  got="$(_pkc_named_outside "$t/c" "(^|[^A-Za-z0-9_])$dir/" "\\.$ext")"
  [ "$got" = "docs/names.md" ] || cf "(instrument) the scan read its planted control as [$(printf '%s' "$got" | tr '\n' ' ')], want only docs/names.md"
  rm -rf "$t"

  finish "the reader assigns the pack directory and extension once each, process/MODULES.md names the directory, no other shipped file outside the pack interface, the file lists and the harness spells either, and none of $n shipped shell programs assigns them itself; a planted doc that names the directory is found"
}
