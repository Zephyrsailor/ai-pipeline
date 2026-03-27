#!/usr/bin/env bash
set -euo pipefail

# PM Agent: analyze raw requirement, output structured PRD

REPO="${REPO:-.}"
REQUIREMENT="${REQUIREMENT:-}"
PROJECT_NAME="${PROJECT_NAME:-untitled}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"
source "$SCRIPT_DIR/lib/extract-json.sh"

echo "=== [requirements] Starting PRD generation for: $PROJECT_NAME ===" >&2

# 通知：PM 开始工作
notify_pm_start "$PROJECT_NAME" "$REQUIREMENT"

RAW_OUTPUT=$(cd "$REPO" && echo "Analyze the following requirement for the project '$PROJECT_NAME'.

Raw requirement from stakeholder:
$REQUIREMENT

Explore the existing codebase to understand context, then produce a complete PRD.
Output ONLY a valid JSON object matching the format specified in your instructions. No markdown wrapping." \
| claude -p \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/pm.md")" \
  2>/dev/null) || RAW_OUTPUT="{\"error\": \"PM agent failed\", \"request_id\": \"$REQUEST_ID\"}"

# 提取纯 JSON
PRD_JSON=$(echo "$RAW_OUTPUT" | extract_json)
echo "$PRD_JSON"

# 提取摘要发到 Thread
story_count=$(echo "$PRD_JSON" | jq -r '.user_stories | length' 2>/dev/null || echo "0")
ac_count=$(echo "$PRD_JSON" | jq -r '.acceptance_criteria | length' 2>/dev/null || echo "0")
prd_summary=$(echo "$PRD_JSON" | jq -r '.summary // empty' 2>/dev/null || echo "")
[ -z "$prd_summary" ] && prd_summary="需求分析完成"

notify_pm_done "$PROJECT_NAME" "- 项目摘要：$prd_summary
- 用户故事：${story_count} 个
- 验收标准：${ac_count} 条"

echo "=== [requirements] PRD generation complete ===" >&2
