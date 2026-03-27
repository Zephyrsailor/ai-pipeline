#!/usr/bin/env bash
set -euo pipefail

# Metrics Logger — 每次 pipeline 运行结束时记录指标
# 同时在 #dashboard Thread 发送摘要通知

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/lib/pipeline.sh"
source "$SCRIPT_DIR/lib/notify.sh"

METRICS_FILE="${METRICS_FILE:-$SCRIPT_DIR/data/metrics.tsv}"
REQUEST_ID="${REQUEST_ID:-unknown}"
WORKFLOW="${WORKFLOW:-unknown}"

# Read context from stdin (upstream results)
CONTEXT=$(cat 2>/dev/null || echo '{}')

# Initialize TSV if missing
if [ ! -f "$METRICS_FILE" ]; then
  mkdir -p "$(dirname "$METRICS_FILE")"
  printf "timestamp\trequest_id\tworkflow\tstatus\tduration_s\treview_rounds\ttest_attempts\thuman_interventions\n" > "$METRICS_FILE"
fi

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
review_rounds="${REVIEW_ROUNDS:-$(echo "$CONTEXT" | jq -r '.rounds // 0' 2>/dev/null || echo 0)}"
test_attempts="${TEST_ATTEMPTS:-$(echo "$CONTEXT" | jq -r '.attempts // 0' 2>/dev/null || echo 0)}"
duration=$(echo "$CONTEXT" | jq -r '.duration_seconds // 0' 2>/dev/null || echo 0)

# Determine status
passed=$(echo "$CONTEXT" | jq -r '.tests_passed // .review_passed // .deployed // false' 2>/dev/null || echo "false")
if [ "$passed" = "true" ]; then
  status="success"
else
  status="failure"
fi

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t0\n" \
  "$timestamp" "$REQUEST_ID" "$WORKFLOW" "$status" "$duration" "$review_rounds" "$test_attempts" \
  >> "$METRICS_FILE"

# 获取项目 state 信息，计算总耗时
total_duration="N/A"
state_file="$PROJECTS_DIR/$REQUEST_ID/.pipeline/state.json"
if [ -f "$state_file" ]; then
  created_at=$(jq -r '.created_at // empty' "$state_file")
  if [ -n "$created_at" ]; then
    start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" +%s 2>/dev/null || echo "")
    if [ -n "$start_epoch" ]; then
      now_epoch=$(date +%s)
      elapsed=$(( (now_epoch - start_epoch) / 60 ))
      total_duration="${elapsed}min"
    fi
  fi
fi

# 通知 #dashboard 频道（如有 Thread）
if [ "$status" = "success" ]; then
  status_text="✅ 成功"
else
  status_text="❌ 失败"
fi

dashboard_msg="📊 **[$REQUEST_ID]** 流水线执行完毕：$status_text

- 代码审查：${review_rounds} 轮
- 测试尝试：${test_attempts} 次
- 总耗时：$total_duration

数据已记录到 \`data/metrics.tsv\`"

# dashboard 没有 Thread 就发到频道
CHANNELS_FILE="$SCRIPT_DIR/config/channels.json"
dashboard_thread=$(pipeline_get_thread "$REQUEST_ID" "dashboard" 2>/dev/null || echo "")
dashboard_channel=$(jq -r '.discord.dashboard' "$CHANNELS_FILE" 2>/dev/null || echo "")

if [ -n "$dashboard_thread" ]; then
  THREAD_ID="$dashboard_thread" MESSAGE="$dashboard_msg" "$SCRIPT_DIR/bin/notify-channel.sh" 2>/dev/null || true
elif [ -n "$dashboard_channel" ]; then
  CHANNEL_ID="$dashboard_channel" MESSAGE="$dashboard_msg" "$SCRIPT_DIR/bin/notify-channel.sh" 2>/dev/null || true
fi

# 输出 JSON
jq -n \
  --arg ts "$timestamp" \
  --arg rid "$REQUEST_ID" \
  --arg wf "$WORKFLOW" \
  --arg st "$status" \
  --argjson rr "$review_rounds" \
  --argjson ta "$test_attempts" \
  --arg dur "$total_duration" \
  '{timestamp: $ts, request_id: $rid, workflow: $wf, status: $st, review_rounds: $rr, test_attempts: $ta, total_duration: $dur}'
