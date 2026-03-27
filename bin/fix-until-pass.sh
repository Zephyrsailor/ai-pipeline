#!/usr/bin/env bash
set -euo pipefail

# Fix-Until-Pass Loop (autoresearch pattern)

REPO="${REPO:-.}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TRIAGE_CONTEXT=$(cat)
fix_plan=$(echo "$TRIAGE_CONTEXT" | jq -r '.fix_plan // .summary // "Fix the reported bug"' 2>/dev/null || echo "Fix the reported bug")

START_TIME=$(date +%s)
attempt=0
tests_passed=false
test_output=""

while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
  attempt=$((attempt + 1))
  echo "=== Fix attempt $attempt/$MAX_ATTEMPTS ===" >&2

  if [ "$attempt" -eq 1 ]; then
    fix_input="$fix_plan"
  else
    fix_input="Previous fix attempt $((attempt-1)) failed. Test output:

$(echo "$test_output" | head -50)

Try a different approach. Fix plan: $fix_plan"
  fi

  cd "$REPO" && echo "$fix_input" \
  | claude -p \
    --system-prompt "$(cat "$SCRIPT_DIR/prompts/developer.md")" \
    --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
    2>/dev/null || true

  echo "=== Running tests (attempt $attempt) ===" >&2
  if test_output=$(REPO="$REPO" "$SCRIPT_DIR/bin/test.sh" <<< "$TRIAGE_CONTEXT" 2>&1); then
    tests_passed=true
    echo "=== Tests PASSED at attempt $attempt ===" >&2
    break
  else
    echo "=== Tests FAILED at attempt $attempt ===" >&2
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

jq -n \
  --argjson passed "$tests_passed" \
  --argjson attempts "$attempt" \
  --argjson max "$MAX_ATTEMPTS" \
  --argjson dur "$DURATION" \
  '{tests_passed: $passed, attempts: $attempts, max_attempts: $max, duration_seconds: $dur}'
