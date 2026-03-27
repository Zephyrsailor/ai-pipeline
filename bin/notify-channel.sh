#!/usr/bin/env bash
# 跨频道发送通知（通道无关抽象层）
# 支持发到 Channel 或 Thread
# Usage:
#   CHANNEL_ID=xxx MESSAGE="text" ./bin/notify-channel.sh            # 发到频道
#   THREAD_ID=xxx MESSAGE="text" ./bin/notify-channel.sh             # 发到 Thread
#   SLUG=xxx TARGET_CHANNEL=dev MESSAGE="text" ./bin/notify-channel.sh  # 自动查 Thread
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MESSAGE="${MESSAGE:?MESSAGE required}"
CHANNEL_TYPE="${CHANNEL_TYPE:-discord}"

# 加载 .env
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a; source "$SCRIPT_DIR/.env"; set +a
fi

# 优先级：THREAD_ID > (SLUG + TARGET_CHANNEL 自动查询) > CHANNEL_ID
TARGET_ID=""

if [ -n "${THREAD_ID:-}" ]; then
  TARGET_ID="$THREAD_ID"
elif [ -n "${SLUG:-}" ] && [ -n "${TARGET_CHANNEL:-}" ]; then
  source "$SCRIPT_DIR/lib/pipeline.sh"
  TARGET_ID=$(pipeline_get_thread "$SLUG" "$TARGET_CHANNEL")
fi

# 回退到 CHANNEL_ID
if [ -z "$TARGET_ID" ]; then
  TARGET_ID="${CHANNEL_ID:-}"
fi

if [ -z "$TARGET_ID" ]; then
  echo "[notify] no target (need THREAD_ID, SLUG+TARGET_CHANNEL, or CHANNEL_ID)" >&2
  exit 1
fi

# 发送方式：优先 Discord API 直发（更可靠），回退到 OpenClaw
if [ "$CHANNEL_TYPE" = "discord" ] && [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  DISCORD_API="https://discord.com/api/v10"
  curl -sf -X POST "$DISCORD_API/channels/$TARGET_ID/messages" \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(echo "$MESSAGE" | jq -Rs .)}" \
    >/dev/null 2>&1 || echo "[notify] Discord API send failed to $TARGET_ID" >&2
else
  openclaw message send \
    --channel "$CHANNEL_TYPE" \
    --target "$TARGET_ID" \
    -m "$MESSAGE" 2>&1 || echo "[notify] openclaw send failed to $TARGET_ID" >&2
fi
