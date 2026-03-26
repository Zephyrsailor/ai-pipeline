#!/usr/bin/env bash
# 保存阶段产物 + 执行 handoff
# 从 stdin 读取产物内容，保存到文件，触发移交
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"

SLUG="${SLUG:?SLUG required}"
SUMMARY="${SUMMARY:?SUMMARY required}"
USER_ID="${USER_ID:-unknown}"
USER_NAME="${USER_NAME:-unknown}"
CHANNEL="${CHANNEL:-cli}"

# 读取当前阶段信息
current_phase=$(pipeline_current_phase "$SLUG")
idx=$(_phase_index "$current_phase")
artifact_file="${PHASE_ARTIFACT[$idx]}"

# 从 stdin 读取内容，保存为产物文件
pipeline_save_artifact "$SLUG" "$current_phase" "$artifact_file"

# 执行 handoff
handoff_result=$(pipeline_handoff "$SLUG" "$SUMMARY" "$USER_ID" "$USER_NAME" "$CHANNEL")

echo "$handoff_result"
