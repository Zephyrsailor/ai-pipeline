#!/usr/bin/env bash
# 保存阶段产物 + 执行 handoff + 发跨频道通知
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"

SLUG="${SLUG:?SLUG required}"
SUMMARY="${SUMMARY:?SUMMARY required}"
USER_ID="${USER_ID:-unknown}"
USER_NAME="${USER_NAME:-unknown}"
CHANNEL="${CHANNEL:-cli}"

# 读取当前阶段信息
current_phase=$(pipeline_current_phase "$SLUG")
idx=$(_phase_index "$current_phase")
artifact_file="${PHASE_ARTIFACT[$idx]}"

# 保存产物文件
artifact_path="$PROJECTS_DIR/$SLUG/docs/$artifact_file"
if [ -f "$artifact_path" ] && [ "$(wc -c < "$artifact_path")" -gt 10 ]; then
  echo "[save-and-handoff] artifact already has content, skipping stdin" >&2
else
  pipeline_save_artifact "$SLUG" "$current_phase" "$artifact_file"
fi

# 计算下一阶段（在 handoff 之前）
next_idx=$((idx + 1))
next_phase=""
if [ "$next_idx" -lt "${#PHASE_ORDER[@]}" ]; then
  next_phase="${PHASE_ORDER[$next_idx]}"
fi

# 执行 handoff
handoff_result=$(pipeline_handoff "$SLUG" "$SUMMARY" "$USER_ID" "$USER_NAME" "$CHANNEL")

# 跨频道通知
if [ -n "$next_phase" ]; then
  notify_handoff "$SLUG" "$current_phase" "$next_phase" "$SUMMARY
产物文件：\`docs/$artifact_file\`"
fi

echo "$handoff_result"
