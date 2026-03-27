#!/usr/bin/env bash
# 通知工具函数 — Agent 在 Discord Thread 里"说话"
# 语气像真人团队成员，不是系统日志

NOTIFY_SCRIPT_DIR="${NOTIFY_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# 加载 .env
if [ -f "$NOTIFY_SCRIPT_DIR/.env" ]; then
  set -a; source "$NOTIFY_SCRIPT_DIR/.env"; set +a
fi

# 基础：发消息到项目的某个频道 Thread
# Usage: notify_thread <slug> <channel_name> <message>
notify_thread() {
  local slug="$1"
  local channel_name="$2"
  local message="$3"
  SLUG="$slug" TARGET_CHANNEL="$channel_name" MESSAGE="$message" \
    "$NOTIFY_SCRIPT_DIR/bin/notify-channel.sh" 2>/dev/null || true
}

# ============================================================
# 高级通知：Agent 在频道里"汇报工作"
# ============================================================

# PM Agent 汇报
notify_pm_start() {
  local slug="$1"
  local requirement="$2"
  notify_thread "$slug" "product" "📋 收到需求，我来分析一下...

> $requirement

正在撰写产品需求文档（PRD），包括用户故事和验收标准。"
}

notify_pm_done() {
  local slug="$1"
  local prd_summary="$2"
  notify_thread "$slug" "product" "✅ **需求文档已完成**

$prd_summary

文件已保存到 \`docs/prd.md\`，请查看确认后我们进入技术设计阶段。"
}

# Architect Agent 汇报
notify_architect_start() {
  local slug="$1"
  notify_thread "$slug" "design" "🏗️ PRD 已收到，开始做技术设计...

正在分析需求、选择技术方案、设计系统架构。"
}

notify_architect_done() {
  local slug="$1"
  local design_summary="$2"
  notify_thread "$slug" "design" "✅ **技术设计已完成**

$design_summary

文件已保存到 \`docs/tech-design.md\`，请确认后进入开发阶段。"
}

notify_tasks_done() {
  local slug="$1"
  local task_summary="$2"
  notify_thread "$slug" "design" "📝 **任务拆分完成**

$task_summary

任务清单已就绪，可以开始开发。"
}

# Developer Agent 汇报
notify_dev_start() {
  local slug="$1"
  local task_count="$2"
  notify_thread "$slug" "dev" "💻 收到任务清单，共 **${task_count}** 个任务，开始写代码...

按照技术设计方案逐个实现，每完成一个任务会提交代码并更新进度。"
}

notify_dev_progress() {
  local slug="$1"
  local current="$2"
  local total="$3"
  local description="$4"
  notify_thread "$slug" "dev" "⏳ 进度 $current/$total — $description"
}

notify_dev_done() {
  local slug="$1"
  local duration="$2"
  local summary="$3"
  notify_thread "$slug" "dev" "✅ **开发完成** (耗时 ${duration}s)

$summary

代码已提交，等待代码审查。"
}

# Reviewer Agent 汇报
notify_review_start() {
  local slug="$1"
  local max_rounds="$2"
  notify_thread "$slug" "dev" "🔍 开始代码审查（最多 $max_rounds 轮）

正在检查代码质量、安全问题、测试覆盖..."
}

notify_review_round() {
  local slug="$1"
  local round="$2"
  local max="$3"
  local result="$4"  # "approved" or issues description
  if [ "$result" = "approved" ]; then
    notify_thread "$slug" "dev" "✅ **代码审查通过**（第 $round 轮）

代码质量符合标准，可以进入测试阶段。"
  else
    notify_thread "$slug" "dev" "⚠️ 第 $round/$max 轮审查发现问题，正在修复：

$result"
  fi
}

# QA Agent 汇报
notify_qa_start() {
  local slug="$1"
  notify_thread "$slug" "qa" "🧪 收到代码，开始测试...

正在运行已有测试用例，并根据验收标准补充新的测试。"
}

notify_qa_done() {
  local slug="$1"
  local duration="$2"
  local result="$3"
  notify_thread "$slug" "qa" "✅ **测试完成** (耗时 ${duration}s)

$result

请确认后进入发布阶段。"
}

# Release Agent 汇报
notify_release_start() {
  local slug="$1"
  notify_thread "$slug" "release" "🚀 开始准备发布...

正在创建 Pull Request、生成 Release Notes。"
}

notify_release_done() {
  local slug="$1"
  local pr_url="$2"
  notify_thread "$slug" "release" "✅ **发布准备完成**

PR 已创建：$pr_url
Release Notes 已生成。等待最终确认后合并。"
}

# Handoff 通知：当前频道完成 + 下游频道接力
notify_handoff() {
  local slug="$1"
  local from_phase="$2"
  local to_phase="$3"
  local summary="$4"

  local from_channel to_channel
  from_channel=$(pipeline_phase_channel "$from_phase")
  to_channel=$(pipeline_phase_channel "$to_phase")

  # 下游频道接力通知
  if [ -n "$to_channel" ]; then
    local phase_names
    case "$to_phase" in
      design)      phase_names="技术设计" ;;
      development) phase_names="开发" ;;
      testing)     phase_names="测试" ;;
      release)     phase_names="发布" ;;
      *)           phase_names="$to_phase" ;;
    esac
    notify_thread "$slug" "$to_channel" "📨 **[$slug]** 上游已完成，进入 **${phase_names}** 阶段

$summary"
  fi
}

# Dashboard 汇报
notify_dashboard() {
  local slug="$1"
  local status="$2"
  local details="$3"

  local channels_file="$NOTIFY_SCRIPT_DIR/config/channels.json"
  local dashboard_channel
  dashboard_channel=$(jq -r '.discord.dashboard' "$channels_file" 2>/dev/null || echo "")

  if [ -n "$dashboard_channel" ]; then
    CHANNEL_ID="$dashboard_channel" MESSAGE="$details" \
      "$NOTIFY_SCRIPT_DIR/bin/notify-channel.sh" 2>/dev/null || true
  fi
}
