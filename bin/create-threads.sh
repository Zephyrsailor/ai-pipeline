#!/usr/bin/env bash
# 为项目在所有 Discord 频道创建 Thread，并把 thread ID 存入 state.json
# Usage: SLUG=my-project ./bin/create-threads.sh
# Requires: DISCORD_BOT_TOKEN (from .env or environment)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"

# 加载 .env
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a; source "$SCRIPT_DIR/.env"; set +a
fi

SLUG="${SLUG:?SLUG required}"
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:?DISCORD_BOT_TOKEN required}"

CHANNELS_FILE="$SCRIPT_DIR/config/channels.json"
DISCORD_API="https://discord.com/api/v10"

# 要创建 Thread 的频道列表（跳过 dashboard，它是只读看板）
TARGET_CHANNELS=("product" "design" "dev" "qa" "bugs" "release")

created=0
skipped=0

for ch_name in "${TARGET_CHANNELS[@]}"; do
  channel_id=$(jq -r ".discord.\"$ch_name\"" "$CHANNELS_FILE")
  if [ -z "$channel_id" ] || [ "$channel_id" = "null" ]; then
    echo "[create-threads] channel '$ch_name' not found in channels.json, skipping" >&2
    continue
  fi

  # 检查是否已有 thread
  existing=$(pipeline_get_thread "$SLUG" "$ch_name")
  if [ -n "$existing" ]; then
    echo "[create-threads] $ch_name: thread already exists ($existing), skipping" >&2
    skipped=$((skipped + 1))
    continue
  fi

  # 创建 Discord public thread（type 11）
  # 需要先发一条消息作为 thread starter
  starter_response=$(curl -sf -X POST "$DISCORD_API/channels/$channel_id/messages" \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"📁 **[$SLUG]** 项目讨论区已创建\"}" 2>&1) || {
    echo "[create-threads] failed to send starter message to $ch_name ($channel_id)" >&2
    continue
  }

  message_id=$(echo "$starter_response" | jq -r '.id // empty')
  if [ -z "$message_id" ]; then
    echo "[create-threads] no message_id from starter in $ch_name: $starter_response" >&2
    continue
  fi

  # 从消息创建 thread
  thread_response=$(curl -sf -X POST "$DISCORD_API/channels/$channel_id/messages/$message_id/threads" \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$SLUG\", \"auto_archive_duration\": 10080}" 2>&1) || {
    echo "[create-threads] failed to create thread in $ch_name" >&2
    continue
  }

  thread_id=$(echo "$thread_response" | jq -r '.id // empty')
  if [ -z "$thread_id" ]; then
    echo "[create-threads] no thread_id from $ch_name: $thread_response" >&2
    continue
  fi

  # 保存到 state.json
  pipeline_set_thread "$SLUG" "$ch_name" "$thread_id"
  echo "[create-threads] $ch_name: thread created ($thread_id)" >&2
  created=$((created + 1))
done

# 输出结果
jq -n \
  --arg slug "$SLUG" \
  --argjson created "$created" \
  --argjson skipped "$skipped" \
  --argjson threads "$(jq '.threads' "$PROJECTS_DIR/$SLUG/.pipeline/state.json")" \
  '{slug: $slug, threads_created: $created, threads_skipped: $skipped, threads: $threads}'
