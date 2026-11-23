# KIT-CLASS: MIXED — self-test harness, portability cases. See process/EXTRACTION.md.
# =============================================================================
# scripts/test/cases/portability.sh — sourced by scripts/test/run.sh, never run on its own.
# One class: a shipped program means something different on another platform than on the one it was
# written on. A bash 3.2 pattern range that matches capitals under a UTF-8 locale, a checkout whose
# line endings a git setting rewrites, and an awk that reads `{4}` as the text `{4}`.
# =============================================================================

# _pt_utf8_locale — prints the name of an installed UTF-8 locale with a collation (en_US first), or nothing.
_pt_utf8_locale() {
  local l
  for l in en_US.UTF-8 en_GB.UTF-8 C.UTF-8; do
    locale -a 2>/dev/null | grep -x "$l" >/dev/null && { printf '%s' "$l"; return 0; }
  done
  return 1
}

# =============================================================================
# CASE — THE LOWERCASE-NAME VALIDATORS REFUSE A CAPITAL UNDER A UTF-8 LOCALE. Under bash 3.2 with a UTF-8
# locale `case A in [a-z])` matches, so a name or an id spelled with a capital passed each validator. The
# shipped self-test was red on stock macOS for that reason alone. A name is lowercase letters, digits and
# `-`, starting with a letter; each predicate is run in a fresh shell under the locale.
# Rows: a lowercase name is accepted and a capital anywhere is refused, for the module-name predicate, the
# marker-block predicate and the rule-id check in kit_refuse, and a placeholder test that begins at a capital is not one.
# =============================================================================
case_the_lowercase_name_validators_refuse_a_capital_under_a_utf_8_locale() {
  cf_reset
  local L="the module-name, marker-block and rule-id validators accept a lowercase name and refuse a capital anywhere in it, and a placeholder that begins at a capital is not one, each in a fresh shell under an installed UTF-8 locale"
  local loc; loc="$(_pt_utf8_locale)" || { skp "$L" "no en_US, en_GB or C UTF-8 locale is installed (locale -a lists none), so the shell below could not run under one"; return; }
  local lib="$REAL_SCRIPTS/lib" out rc n
  for n in Foo fOO foo-Bar a-B; do
    rc=0; out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/modules.sh" 2>/dev/null; _kit_mod_name_ok "$2" && echo ACCEPTED' _ "$lib" "$n" 2>&1)" || rc=$?
    [[ "$out" != *ACCEPTED* ]] || cf "(a) _kit_mod_name_ok accepted '$n' under $loc"
    rc=0; out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/marker-block.sh" 2>/dev/null; _kit_mb_valid "$2" && echo ACCEPTED' _ "$lib" "$n" 2>&1)" || rc=$?
    [[ "$out" != *ACCEPTED* ]] || cf "(b) _kit_mb_valid accepted '$n' under $loc"
    rc=0; out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/refuse.sh" 2>/dev/null; kit_refuse 1 "$2" "Error: x" "Next: y"' _ "$lib" "$n" 2>&1)" || rc=$?
    [[ "$out" == *"not kebab-case"* ]] || cf "(d) kit_refuse took the rule id '$n' under $loc: $(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)"
  done
  # (c) the placeholder test starts at the first letter: <Foo> is not a placeholder, <foo> is.
  for n in Foo FOO Zed; do
    out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/pm-field.sh" 2>/dev/null; kit_pm_blank "<$2>" && echo BLANK' _ "$lib" "$n" 2>&1)"
    [[ "$out" != *BLANK* ]] || cf "(c) kit_pm_blank read '<$n>' as a placeholder under $loc"
  done
  # (e) controls: a lowercase name is accepted by each, so a predicate that refuses everything fails here.
  out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/modules.sh" 2>/dev/null; _kit_mod_name_ok foo-2 && echo ACCEPTED' _ "$lib" 2>&1)"
  [[ "$out" == *ACCEPTED* ]] || cf "(e) control: _kit_mod_name_ok refused 'foo-2' under $loc"
  out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/marker-block.sh" 2>/dev/null; _kit_mb_valid foo-2 && echo ACCEPTED' _ "$lib" 2>&1)"
  [[ "$out" == *ACCEPTED* ]] || cf "(e) control: _kit_mb_valid refused 'foo-2' under $loc"
  out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/pm-field.sh" 2>/dev/null; kit_pm_blank "<foo>" && echo BLANK' _ "$lib" 2>&1)"
  [[ "$out" == *BLANK* ]] || cf "(e) control: kit_pm_blank did not read '<foo>' as a placeholder under $loc"
  out="$(LC_ALL="$loc" LANG="$loc" bash -c '. "$1/refuse.sh" 2>/dev/null; kit_refuse 1 foo-bar "Error: x" "Next: y"' _ "$lib" 2>&1)"
  [[ "$out" != *"not kebab-case"* ]] || cf "(e) control: kit_refuse refused the rule id 'foo-bar' under $loc"
  finish "$L"
}

# =============================================================================
# CASE — A CHECKOUT THROUGH core.autocrlf=true STILL RUNS EVERY SHIPPED SHELL PROGRAM. No `.gitattributes`
# shipped, so a clone with `core.autocrlf=true` (Git for Windows' default) wrote CRLF into every script,
# `#!/usr/bin/env bash` became `bash\r`, and `./scripts/kit-init.sh --help` died with `env: bash\r: No such
# file or directory`. The shipped `.gitattributes` pins them to LF.
# Rows: with the shipped file the clone holds no carriage return in setup.sh, a script, or a hook, and
# `scripts/kit-init.sh --help` runs; without it (control) the clone does hold CRLF, so the fixture bites.
# =============================================================================
case_a_checkout_through_autocrlf_runs_every_shipped_shell_program() {
  cf_reset
  local L="a clone made with core.autocrlf=true holds no carriage return in setup.sh, a script or a hook and runs scripts/kit-init.sh --help, because the shipped .gitattributes pins them to LF; without it the clone does hold CRLF"
  local attr="$REAL_REPO_ROOT/.gitattributes"
  if [ ! -f "$attr" ]; then bad "$L" "no .gitattributes ships at the project root ($attr)"; return; fi
  local d src crlf one; d="$(mktemp -d)" || _fixture_die "${FUNCNAME[0]}: mktemp failed"
  local with="$d/with" without="$d/without" f n
  _pt_make() {  # <dir> <1 to include .gitattributes>
    mkdir -p "$1"
    ( cd "$REAL_REPO_ROOT" && tar cf - --exclude=scripts/test --exclude=scripts/hygiene setup.sh scripts consumers/hooks ) | ( cd "$1" && tar xf - )
    [ "$2" = 1 ] && cp "$attr" "$1/.gitattributes"
    ( cd "$1" && git init -q . && git config user.email t@example.invalid && git config user.name t && git add -A && git commit -q -m fixture )
  }
  _pt_make "$with" 1; _pt_make "$without" 0
  git -c core.autocrlf=true clone -q "$with" "$d/clone-with" 2>/dev/null || _fixture_die "${FUNCNAME[0]}: the clone with .gitattributes failed"
  git -c core.autocrlf=true clone -q "$without" "$d/clone-without" 2>/dev/null || _fixture_die "${FUNCNAME[0]}: the clone without .gitattributes failed"
  # (a) with the file: no carriage return in setup.sh, in one script, or in a hook (LC_ALL=C: the bytes, not the locale).
  for f in setup.sh scripts/kit-init.sh scripts/githooks/commit-msg; do
    [ -f "$d/clone-with/$f" ] || continue
    n="$(LC_ALL=C grep -c "$(printf '\r')" "$d/clone-with/$f" || true)"
    [ "${n:-0}" -eq 0 ] || cf "(a) the autocrlf clone with .gitattributes holds $n carriage-return line(s) in $f"
  done
  # (b) and it runs.
  one="$( cd "$d/clone-with" && chmod +x scripts/kit-init.sh && ./scripts/kit-init.sh --help 2>&1 )" || cf "(b) scripts/kit-init.sh --help exited nonzero in the autocrlf clone: $(printf '%s' "$one" | head -2 | tr '\n' '|' | cut -c1-200)"
  [[ "$one" != *'bash\r'* && "$one" != *'No such file or directory'* ]] || cf "(b) scripts/kit-init.sh --help was refused by the interpreter line: $(printf '%s' "$one" | head -2 | tr '\n' '|' | cut -c1-200)"
  # (c) control: without the file the same clone holds CRLF in setup.sh.
  crlf="$(LC_ALL=C grep -c "$(printf '\r')" "$d/clone-without/setup.sh" || true)"
  [ "${crlf:-0}" -gt 0 ] || cf "(c) control: the autocrlf clone WITHOUT .gitattributes holds no CRLF, so this fixture cannot tell the file from its absence (git config or platform?)"
  rm -rf "${d:?}"
  finish "$L"
}

# =============================================================================
# CASE — NO AWK PROGRAM IN A SHIPPED SHELL PROGRAM USES AN INTERVAL EXPRESSION. mawk (the default `awk` of
# Debian 11 and 12 and of Ubuntu 20.04 and 22.04) before 1.3.4-20200717 reads `[0-9]{4}` as the text `{4}`
# and never matches a date; a gate then refuses with a route that cannot lead out. `grep -E`, `sed -E`,
# bash `=~` and python read intervals everywhere, so only a program given to `awk` is read: its single-
# quoted text, from the line that names `awk` (or the line it continues) to the closing quote.
# Rows: no shipped shell program carries one (the population is the shipped scripts, consumers and
# modules, found by `find`); and the scan itself finds `{4}` in a one-line and a multi-line program, and
# passes a `grep -E` interval, a `${1}` expansion and a comment line, so a scan that finds nothing fails.
# =============================================================================
_pt_awk_intervals() {  # <file>... — prints file:line: text for each awk-program line holding an interval
  local f
  for f in "$@"; do
    awk '
      function chk(s) { if (s ~ /(^|[^$])\{[0-9]+(,[0-9]*)?\}/) print FILENAME ":" FNR ": " s }
      /^[ \t]*#/ { next }
      { line = $0; ctx = cont; cont = (line ~ /\\[ \t]*$/)
        if (!inprog && !ctx && line !~ /awk/) next
        pos = 0
        if (!inprog && !ctx) { pos = index(line, "awk") + 3 }
        rest = substr(line, pos + 1); n = split(rest, p, "\047")
        for (i = 1; i <= n; i++) { inside = inprog ? (i % 2 == 1) : (i % 2 == 0); if (inside) chk(p[i]) }
        if ((n - 1) % 2 == 1) inprog = !inprog
        if (!inprog && !ctx && line !~ /awk/) cont = 0
        if (!inprog && ctx) cont = (line ~ /\\[ \t]*$/)
      }' "$f"
  done
}
case_no_awk_program_in_a_shipped_shell_program_uses_an_interval_expression() {
  cf_reset
  local L="no awk program in a shipped shell program carries a {n} interval expression, and the scan finds one in a one-line and a multi-line program while passing a grep -E interval, a \${1} expansion and a comment"
  local d hits f n=0; d="$(mktemp -d)" || _fixture_die "${FUNCNAME[0]}: mktemp failed"
  # (a) the scan finds what it should and passes what it should.
  printf '%s\n' "awk '/^[0-9]{4}/ { print }' \"\$1\"" > "$d/one.sh"
  printf '%s\n' "x=\$(awk -v a=1 \\" "    -v b=2 '" "  /^## [0-9]{2}-x/ { n++ }" "  END { print n }' \"\$1\")" > "$d/multi.sh"
  printf '%s\n' "grep -E '^[0-9]{4}' \"\$1\" | awk 'NR<=3 { print }'" "echo \"\${1}\" | awk '{ print }'" "# awk '/[0-9]{4}/'" > "$d/clean.sh"
  [ "$(_pt_awk_intervals "$d/one.sh" | wc -l | tr -d ' ')" -eq 1 ] || cf "(a) the scan did not find the interval in a one-line awk program"
  [ "$(_pt_awk_intervals "$d/multi.sh" | wc -l | tr -d ' ')" -eq 1 ] || cf "(a) the scan did not find the interval in a multi-line awk program started by a continued line"
  [ -z "$(_pt_awk_intervals "$d/clean.sh")" ] || cf "(a) the scan flagged a grep -E interval, a \${1} expansion or a comment: $(_pt_awk_intervals "$d/clean.sh" | head -2 | tr '\n' '|')"
  # (b) the shipped population.
  while IFS= read -r f; do
    [ -n "$f" ] || continue; n=$(( n + 1 ))
    hits="$(_pt_awk_intervals "$f")"
    [ -z "$hits" ] || cf "(b) an awk program holds an interval expression, which mawk reads as text: $(printf '%s' "$hits" | head -2 | cut -c1-200 | tr '\n' '|')"
  done < <( { find "$REAL_REPO_ROOT/scripts" "$REAL_REPO_ROOT/consumers" "$REAL_REPO_ROOT/modules" -name '*.sh' -not -path '*/test/*' 2>/dev/null; [ -f "$REAL_REPO_ROOT/setup.sh" ] && echo "$REAL_REPO_ROOT/setup.sh"; } | sort )
  [ "$n" -gt 5 ] || cf "(b) the scan read only $n shell program(s): the population was not found"
  rm -rf "${d:?}"
  finish "$L"
}
