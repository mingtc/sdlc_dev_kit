#!/usr/bin/env bash
# Bisection script to find which test creates unwanted files/state
# Usage, FROM THE PROJECT ROOT (it searches, and checks the path, relative to where it runs):
#   TEST_CMD=<your single-file test command> .claude/skills/systematic-debugging/find-polluter.sh <path_that_should_not_exist> <test_pattern>
# Example: TEST_CMD="npm test --" .claude/skills/systematic-debugging/find-polluter.sh 'packages/core/.git' './src/*.test.ts'
#   NOTE THE LEADING './'. `find .` emits paths that begin './', and -path matches the WHOLE
#   emitted path — so a pattern without it matches nothing. In -path, `*` also crosses `/`, so
#   './src/*.test.ts' already covers nested directories ('./src/**/*.test.ts' would skip src/ itself).
# The path must not exist when the run starts, and the script refuses on zero matched test files:
#   either way a "clean" would be a verdict over tests that never ran.
# TEST_CMD is REQUIRED and has no default: the script refuses rather than guess your runner.

set -e

if [ $# -ne 2 ]; then
  echo "Usage (from the project root): $0 <path_that_should_not_exist> <test_pattern>"
  echo "Example: $0 'packages/core/.git' './src/*.test.ts'   # the leading ./ is required — see header"
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
# one file and the run reported clean over nothing.
TOTAL=$(printf '%s' "$TEST_FILES" | grep -c '' || true)
if [ "${TOTAL:-0}" -eq 0 ]; then
  echo "no test files matched $TEST_PATTERN — refusing to report clean over zero files" >&2
  echo "  it searches $(pwd) — run it from the project root. The leading './' is required, and" >&2
  echo "  -path matches the WHOLE emitted path — see the header" >&2
  exit 2
fi

# A path that already exists cannot be traced to a test: refuse rather than skip every test and
# still report clean. (After each test the check below exits on pollution, so this is the only
# point at which it can already be there.)
if [ -e "$POLLUTION_CHECK" ]; then
  echo "$POLLUTION_CHECK already exists before any test ran — remove it, or name a path that should not exist" >&2
  exit 2
fi

echo "Found $TOTAL test files"
echo ""

# One path per LINE, never per word: a path with a space is one test, not fragments that never run.
COUNT=0
while IFS= read -r TEST_FILE; do
  COUNT=$((COUNT + 1))

  echo "[$COUNT/$TOTAL] Testing: $TEST_FILE"

  # Run the test
  # stdin is the path list; a test that reads stdin must not swallow it.
  $TEST_CMD "$TEST_FILE" > /dev/null 2>&1 </dev/null || true

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
    echo "  $TEST_CMD $(printf '%q' "$TEST_FILE")    # Run just this test"
    echo "  cat $(printf '%q' "$TEST_FILE")         # Review test code"
    exit 1
  fi
done <<TEST_FILES_EOF
$TEST_FILES
TEST_FILES_EOF

echo ""
echo "✅ No polluter found - all tests clean!"
exit 0
