#!/usr/bin/env bash
set -euo pipefail

# Test Runner: detect and run the project's test suite
# Outputs JSON with test results

REPO="${REPO:-.}"
cd "$REPO"

# Auto-detect test runner
if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
  TEST_CMD="npm test"
elif [ -f "Makefile" ] && grep -q '^test:' Makefile 2>/dev/null; then
  TEST_CMD="make test"
elif [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] && grep -q 'pytest' pyproject.toml 2>/dev/null; then
  TEST_CMD="pytest --tb=short -q"
elif [ -f "Cargo.toml" ]; then
  TEST_CMD="cargo test"
else
  # Fallback: try common commands
  TEST_CMD="npm test 2>/dev/null || pytest 2>/dev/null || echo 'no test runner detected'"
fi

echo "Running: $TEST_CMD" >&2

# Capture test output
if test_output=$(eval "$TEST_CMD" 2>&1); then
  jq -n \
    --arg cmd "$TEST_CMD" \
    --arg output "$test_output" \
    '{tests_passed: true, test_command: $cmd, output: $output}'
  exit 0
else
  exit_code=$?
  jq -n \
    --arg cmd "$TEST_CMD" \
    --arg output "$test_output" \
    --argjson exit_code "$exit_code" \
    '{tests_passed: false, test_command: $cmd, output: $output, exit_code: $exit_code}'
  exit 1
fi
