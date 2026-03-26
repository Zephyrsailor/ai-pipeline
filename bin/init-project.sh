#!/usr/bin/env bash
# 初始化新项目：创建目录结构 + state.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"

SLUG="${SLUG:-}"
if [ -z "$SLUG" ]; then
  echo '{"error": "SLUG is required"}' >&2
  exit 1
fi

project_dir=$(pipeline_create_project "$SLUG")
echo "{\"project\": \"$SLUG\", \"dir\": \"$project_dir\", \"status\": \"created\"}"
