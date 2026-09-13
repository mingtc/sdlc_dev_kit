#!/usr/bin/env bash
# Bisection script to find which test creates unwanted files/state
# Usage: TEST_CMD=<your single-file test command> ./find-polluter.sh <file_or_dir_to_check> <test_pattern>
# Example: TEST_CMD="npm test --" ./find-polluter.sh '.git' './src/**/*.test.ts'
#   NOTE THE LEADING './'. `find .` emits paths that begin './', and -path matches the WHOLE
#   emitted path — so a pattern without it matches nothing. This example omitted it.
#   THE SCRIPT NOW REFUSES on an empty match rather than reporting success over zero files
#   (changes/316). It used to print "Found 1 test files" and a clean tick, because
#   `echo "$EMPTY" | wc -l` is 1 — an empty capture reads as one line. The kit forbids that
#   shape in terms: skills/refactor-audit/SKILL.md says "0 findings over 0 files" and
#   "0 findings over 28 files" are different results.
# TEST_CMD is REQUIRED and has no default: the script refuses rather than guess your runner.

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <file_to_check> <test_pattern>"
  echo "Example: $0 '.git' './src/**/*.test.ts'   # the leading ./ is required — see header"
  exit 1
fi

POLLUTION_CHECK="$1"
TEST_PATTERN="$2"
# The runner is a knob, not an assumption: export TEST_CMD to match your stack
# (e.g. TEST_CMD="npm test --", TEST_CMD="cargo test", TEST_CMD="go test").
TEST_CMD="${TEST_CMD:?set it to the single-file test command for this stack, e.g. npm test --}"

echo "🔍 Searching for test that creates: $POLLUTION_CHECK"
echo "Test pattern: $TEST_PATTERN"
echo ""

# Get list of test files
TEST_FILES=$(find . -path "$TEST_PATTERN" | sort)
# COUNT FROM THE PRODUCER, NOT FROM A VARIABLE HOLDING ITS OUTPUT. `echo "$X" | wc -l` returns
# 1 for an empty X, because echo of an empty string emits one newline — so zero matches read as
# one file and the run reported clean over nothing (changes/316, changes/292's widening).
TOTAL=$(printf '%s' "$TEST_FILES" | grep -c '' || true)
if [ "${TOTAL:-0}" -eq 0 ]; then
  echo "no test files matched $TEST_PATTERN — refusing to report clean over zero files" >&2
  echo "  the leading './' is required, and -path matches the WHOLE emitted path — see the header" >&2
  exit 2
fi

echo "Found $TOTAL test files"
echo ""

COUNT=0
for TEST_FILE in $TEST_FILES; do
  COUNT=$((COUNT + 1))

  # Skip if pollution already exists
  if [ -e "$POLLUTION_CHECK" ]; then
    echo "⚠️  Pollution already exists before test $COUNT/$TOTAL"
    echo "   Skipping: $TEST_FILE"
    continue
  fi

  echo "[$COUNT/$TOTAL] Testing: $TEST_FILE"

  # Run the test
  $TEST_CMD "$TEST_FILE" > /dev/null 2>&1 || true

  # Check if pollution appeared
  if [ -e "$POLLUTION_CHECK" ]; then
    echo ""
    echo "🎯 FOUND POLLUTER!"
    echo "   Test: $TEST_FILE"
    echo "   Created: $POLLUTION_CHECK"
    echo ""
    echo "Pollution details:"
    ls -la "$POLLUTION_CHECK"
    echo ""
    echo "To investigate:"
    echo "  $TEST_CMD $TEST_FILE    # Run just this test"
    echo "  cat $TEST_FILE         # Review test code"
    exit 1
  fi
done

echo ""
echo "✅ No polluter found - all tests clean!"
exit 0
