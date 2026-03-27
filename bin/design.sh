#!/usr/bin/env bash
set -euo pipefail

# Architect Agent: read PRD from stdin, output Technical Design Document

REPO="${REPO:-.}"
REQUEST_ID="${REQUEST_ID:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"
source "$SCRIPT_DIR/lib/extract-json.sh"

PRD=$(cat)

echo "=== [design] Starting technical design for request: $REQUEST_ID ===" >&2
notify_architect_start "$REQUEST_ID"

RAW_OUTPUT=$(cd "$REPO" && echo "You are given the following Product Requirements Document (PRD). Analyze it and produce a comprehensive Technical Design Document.

PRD:
$PRD

Output ONLY a valid JSON object matching the format specified in your instructions. No markdown wrapping." \
| claude -p \
  --system-prompt "$(cat "$SCRIPT_DIR/prompts/architect.md")" \
  2>/dev/null) || RAW_OUTPUT="{\"error\": \"architect agent failed\", \"request_id\": \"$REQUEST_ID\"}"

DESIGN_JSON=$(echo "$RAW_OUTPUT" | extract_json)
echo "$DESIGN_JSON"

# 提取摘要
comp_count=$(echo "$DESIGN_JSON" | jq -r '.components | length' 2>/dev/null || echo "0")
effort=$(echo "$DESIGN_JSON" | jq -r '.estimated_effort // "未知"' 2>/dev/null || echo "未知")
decisions=$(echo "$DESIGN_JSON" | jq -r '[.tech_decisions[]?.decision] | join("、")' 2>/dev/null || echo "")
notify_architect_done "$REQUEST_ID" "- 模块数：${comp_count} 个
- 预估工作量：${effort}
- 关键决策：${decisions:-无}"

echo "=== [design] Technical design complete ===" >&2
