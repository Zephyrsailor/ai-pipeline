#!/usr/bin/env bash
# 跨频道发送通知（通道无关抽象层）
# Usage: CHANNEL_ID=xxx MESSAGE="text" ./bin/notify-channel.sh
set -euo pipefail

CHANNEL_ID="${CHANNEL_ID:?CHANNEL_ID required}"
MESSAGE="${MESSAGE:?MESSAGE required}"
CHANNEL_TYPE="${CHANNEL_TYPE:-discord}"

openclaw message send \
  --channel "$CHANNEL_TYPE" \
  --target "$CHANNEL_ID" \
  -m "$MESSAGE" 2>&1 || echo "[notify] failed to send to $CHANNEL_ID" >&2
