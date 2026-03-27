#!/usr/bin/env bash
# Pipeline Core — 项目管理和 handoff 工具函数
# 不依赖任何具体通道（Discord/TG/CLI），只操作文件和 Git

set -euo pipefail

PIPELINE_ROOT="${PIPELINE_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECTS_DIR="${PIPELINE_ROOT}/projects"

# ============================================================
# 项目管理
# ============================================================

# 创建新项目
# Usage: pipeline_create_project <slug>
pipeline_create_project() {
  local slug="$1"
  local project_dir="$PROJECTS_DIR/$slug"

  if [ -d "$project_dir" ]; then
    echo "Project $slug already exists" >&2
    return 1
  fi

  mkdir -p "$project_dir"/{.pipeline/handoffs,docs,src,tests}

  cat > "$project_dir/.pipeline/state.json" << EOF
{
  "project": "$slug",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_phase": "requirements",
  "threads": {},
  "phases": {
    "requirements": {"status": "in_progress"},
    "design": {"status": "pending"},
    "development": {"status": "pending"},
    "testing": {"status": "pending"},
    "release": {"status": "pending"}
  }
}
EOF

  echo "$project_dir"
}

# 获取项目当前阶段
# Usage: pipeline_current_phase <slug>
pipeline_current_phase() {
  local slug="$1"
  jq -r '.current_phase' "$PROJECTS_DIR/$slug/.pipeline/state.json"
}

# ============================================================
# 产物保存
# ============================================================

# 保存阶段产物文件
# Usage: pipeline_save_artifact <slug> <phase> <filename> < content
pipeline_save_artifact() {
  local slug="$1"
  local phase="$2"
  local filename="$3"
  local project_dir="$PROJECTS_DIR/$slug"

  cat > "$project_dir/docs/$filename"

  # 更新 state.json
  local tmp=$(mktemp)
  jq --arg phase "$phase" --arg artifact "docs/$filename" \
    '.phases[$phase].artifact = $artifact' \
    "$project_dir/.pipeline/state.json" > "$tmp"
  mv "$tmp" "$project_dir/.pipeline/state.json"
}

# ============================================================
# Handoff — 阶段移交
# ============================================================

# 阶段映射
PHASE_ORDER=("requirements" "design" "development" "testing" "release")
PHASE_NUMBER=("01" "02" "03" "04" "05")
PHASE_AGENT=("pm" "architect" "developer" "qa" "release")
PHASE_ARTIFACT=("prd.md" "tech-design.md" "tasks.md" "test-report.md" "release-notes.md")

# 获取阶段序号
_phase_index() {
  local phase="$1"
  for i in "${!PHASE_ORDER[@]}"; do
    if [ "${PHASE_ORDER[$i]}" = "$phase" ]; then
      echo "$i"
      return
    fi
  done
  echo "-1"
}

# 完成当前阶段并移交到下一阶段
# Usage: pipeline_handoff <slug> <summary> <user_id> <user_name> <channel>
pipeline_handoff() {
  local slug="$1"
  local summary="$2"
  local user_id="$3"
  local user_name="$4"
  local channel="$5"
  local project_dir="$PROJECTS_DIR/$slug"
  local state_file="$project_dir/.pipeline/state.json"

  local current_phase=$(jq -r '.current_phase' "$state_file")
  local idx=$(_phase_index "$current_phase")
  local next_idx=$((idx + 1))

  if [ "$next_idx" -ge "${#PHASE_ORDER[@]}" ]; then
    echo '{"error": "already at final phase"}' >&2
    return 1
  fi

  local next_phase="${PHASE_ORDER[$next_idx]}"
  local handoff_num="${PHASE_NUMBER[$idx]}"
  local artifact="${PHASE_ARTIFACT[$idx]}"
  local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # 生成 handoff JSON
  local handoff_file="$project_dir/.pipeline/handoffs/${handoff_num}-${current_phase}.json"
  cat > "$handoff_file" << EOF
{
  "id": "${handoff_num}-${current_phase}",
  "from_phase": "$current_phase",
  "to_phase": "$next_phase",
  "artifact": "docs/$artifact",
  "summary": $(echo "$summary" | jq -Rs .),
  "requested_by": {"id": "$user_id", "name": "$user_name", "channel": "$channel"},
  "approved_by": {"id": "$user_id", "name": "$user_name", "channel": "$channel"},
  "created_at": "$now"
}
EOF

  # 更新 state.json
  local tmp=$(mktemp)
  jq --arg current "$current_phase" --arg next "$next_phase" --arg now "$now" \
    --arg user_id "$user_id" --arg user_name "$user_name" --arg channel "$channel" \
    '.phases[$current].status = "completed" |
     .phases[$current].completed_at = $now |
     .phases[$current].approved_by = {"id": $user_id, "name": $user_name, "channel": $channel} |
     .phases[$next].status = "in_progress" |
     .phases[$next].started_at = $now |
     .current_phase = $next' \
    "$state_file" > "$tmp"
  mv "$tmp" "$state_file"

  # Git commit
  (
    cd "$PIPELINE_ROOT"
    git add "projects/$slug/" 2>/dev/null || true
    git commit -m "${current_phase}(${slug}): ${summary}" \
      --author="${PHASE_AGENT[$idx]^} Agent <${PHASE_AGENT[$idx]}-agent@ai-pipeline.bot>" \
      2>/dev/null || true
  )

  # 输出移交通知（通道无关的结构化数据，adapter 负责格式化）
  cat "$handoff_file"
}

# ============================================================
# Thread 管理
# ============================================================

# 获取项目在某个频道的 thread ID
# Usage: pipeline_get_thread <slug> <channel_name>
pipeline_get_thread() {
  local slug="$1"
  local channel_name="$2"
  jq -r ".threads.\"$channel_name\" // empty" "$PROJECTS_DIR/$slug/.pipeline/state.json"
}

# 设置项目在某个频道的 thread ID
# Usage: pipeline_set_thread <slug> <channel_name> <thread_id>
pipeline_set_thread() {
  local slug="$1"
  local channel_name="$2"
  local thread_id="$3"
  local state_file="$PROJECTS_DIR/$slug/.pipeline/state.json"
  local tmp=$(mktemp)
  jq --arg ch "$channel_name" --arg tid "$thread_id" \
    '.threads[$ch] = $tid' "$state_file" > "$tmp"
  mv "$tmp" "$state_file"
}

# 获取某阶段对应的频道名
# Usage: pipeline_phase_channel <phase>
pipeline_phase_channel() {
  local phase="$1"
  case "$phase" in
    requirements) echo "product" ;;
    design)       echo "design" ;;
    development)  echo "dev" ;;
    testing)      echo "qa" ;;
    release)      echo "release" ;;
    *)            echo "" ;;
  esac
}

# ============================================================
# 查询
# ============================================================

# 获取项目状态摘要
# Usage: pipeline_status <slug>
pipeline_status() {
  local slug="$1"
  cat "$PROJECTS_DIR/$slug/.pipeline/state.json"
}

# 列出所有项目
# Usage: pipeline_list_projects
pipeline_list_projects() {
  if [ ! -d "$PROJECTS_DIR" ]; then
    echo '[]'
    return
  fi
  ls -d "$PROJECTS_DIR"/*/ 2>/dev/null | while read dir; do
    local s=$(basename "$dir")
    local phase=$(jq -r '.current_phase' "$dir/.pipeline/state.json" 2>/dev/null || echo "unknown")
    echo "$s	$phase"
  done | jq -Rs 'split("\n") | map(select(length > 0) | split("\t") | {"project": .[0], "phase": .[1]})'
}
