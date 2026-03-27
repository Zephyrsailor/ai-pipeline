#!/usr/bin/env bash
set -euo pipefail

# Developer Agent: read task list from stdin, implement all tasks

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"

TASKS=$(cat)

START_TIME=$(date +%s)

echo "=== [develop] Starting implementation for request: $REQUEST_ID ===" >&2

# 提取任务数
task_count=$(echo "$TASKS" | jq -r '.total_tasks // 0' 2>/dev/null || echo "?")
notify_dev_start "$REQUEST_ID" "$task_count"

cd "$REPO"
DEV_OUTPUT=$(echo "Implement the following tasks. Work through them in order.

Task List:
$TASKS

After implementing each task:
1. Verify the code compiles/runs without errors
2. Commit with a descriptive message: type(scope): description
3. Move to the next task

After all tasks are complete, output a JSON summary of what was done." \
| claude -p \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/developer.md")" \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  2>/dev/null) || DEV_OUTPUT=""

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=== [develop] Implementation complete (${DURATION}s) ===" >&2

# 提取开发摘要
files_created=$(echo "$DEV_OUTPUT" | jq -r '.files_created | length' 2>/dev/null || echo "?")
tests_status=$(echo "$DEV_OUTPUT" | jq -r '.tests_status // "unknown"' 2>/dev/null || echo "unknown")
notify_dev_done "$REQUEST_ID" "$DURATION" "- 创建文件：${files_created} 个
- 测试状态：${tests_status}
- 总耗时：${DURATION}s"

jq -n \
  --arg rid "$REQUEST_ID" \
  --argjson dur "$DURATION" \
  '{request_id: $rid, phase: "development", duration_seconds: $dur, status: "completed"}'
