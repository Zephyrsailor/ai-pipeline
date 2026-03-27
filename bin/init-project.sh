#!/usr/bin/env bash
# 初始化新项目：创建目录结构 + state.json + Discord Threads
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"

SLUG="${SLUG:-}"
if [ -z "$SLUG" ]; then
  echo '{"error": "SLUG is required"}' >&2
  exit 1
fi

project_dir=$(pipeline_create_project "$SLUG")

# 自动创建 Discord Threads（如有 bot token）
threads_result="{}"
if [ -n "${DISCORD_BOT_TOKEN:-}" ] || [ -f "$SCRIPT_DIR/.env" ]; then
  threads_result=$(SLUG="$SLUG" "$SCRIPT_DIR/bin/create-threads.sh" 2>/dev/null) || threads_result="{}"
  echo "[init-project] Discord threads created for $SLUG" >&2
fi

# 输出结果
jq -n \
  --arg slug "$SLUG" \
  --arg dir "$project_dir" \
  --argjson threads "$threads_result" \
  '{project: $slug, dir: $dir, status: "created", threads: $threads}'
