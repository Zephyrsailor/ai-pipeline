#!/usr/bin/env bash
set -euo pipefail

# QA Agent: read PRD/triage context from stdin, verify implementation against acceptance criteria
# Runs existing tests AND writes new test cases as needed

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

CONTEXT=$(cat)

START_TIME=$(date +%s)

echo "=== [test] Starting QA verification for request: $REQUEST_ID ===" >&2

claude --print \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/qa.md")" \
  --prompt "Verify the implementation in the repo at $REPO against the following requirements/context:

$CONTEXT

Steps:
1. Read the acceptance criteria from the context above
2. Detect and run the project's existing test suite
3. Write additional test cases for any uncovered acceptance criteria
4. Run all tests and report results
5. Check for edge cases and regression issues

Output ONLY a valid JSON object matching the format specified in your instructions." \
  --cwd "$REPO" \
  --output-format json \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  --max-turns 10 \
  2>/dev/null || echo "{\"all_passed\": false, \"error\": \"QA agent failed\", \"request_id\": \"$REQUEST_ID\"}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=== [test] QA verification complete (${DURATION}s) ===" >&2
