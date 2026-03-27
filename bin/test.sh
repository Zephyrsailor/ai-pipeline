#!/usr/bin/env bash
set -euo pipefail

# QA Agent: verify implementation against acceptance criteria

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"

CONTEXT=$(cat)

START_TIME=$(date +%s)

echo "=== [test] Starting QA verification for request: $REQUEST_ID ===" >&2
notify_qa_start "$REQUEST_ID"

TEST_OUTPUT=$(cd "$REPO" && echo "Verify the implementation against the following requirements/context:

$CONTEXT

Steps:
1. Read the acceptance criteria from the context above
2. Detect and run the project's existing test suite
3. Write additional test cases for any uncovered acceptance criteria
4. Run all tests and report results
5. Check for edge cases and regression issues

Output ONLY a valid JSON object matching the format specified in your instructions." \
| claude -p \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/qa.md")" \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  2>/dev/null) || TEST_OUTPUT="{\"all_passed\": false, \"error\": \"QA agent failed\", \"request_id\": \"$REQUEST_ID\"}"

echo "$TEST_OUTPUT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# 提取测试结果摘要
total_tests=$(echo "$TEST_OUTPUT" | jq -r '.total_tests // .tests_run // "?"' 2>/dev/null || echo "?")
passed=$(echo "$TEST_OUTPUT" | jq -r '.all_passed // false' 2>/dev/null || echo "false")
if [ "$passed" = "true" ]; then
  result_msg="全部通过 ✅（共 $total_tests 个测试）"
else
  failed_list=$(echo "$TEST_OUTPUT" | jq -r '.failed_tests[]? // empty' 2>/dev/null || echo "")
  result_msg="存在失败 ❌（$total_tests 个测试）
$failed_list"
fi

notify_qa_done "$REQUEST_ID" "$DURATION" "$result_msg"

echo "=== [test] QA verification complete (${DURATION}s) ===" >&2
