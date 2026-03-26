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

# 保存产物文件：如果文件已有内容则跳过（agent 可能已直接写入），否则从 stdin 读取
artifact_path="$PROJECTS_DIR/$SLUG/docs/$artifact_file"
if [ -f "$artifact_path" ] && [ "$(wc -c < "$artifact_path")" -gt 10 ]; then
  echo "[save-and-handoff] artifact already has content, skipping stdin" >&2
else
  pipeline_save_artifact "$SLUG" "$current_phase" "$artifact_file"
fi

# 执行 handoff
handoff_result=$(pipeline_handoff "$SLUG" "$SUMMARY" "$USER_ID" "$USER_NAME" "$CHANNEL")

echo "$handoff_result"
