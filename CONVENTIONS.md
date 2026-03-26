# Pipeline Conventions

## 1. 目录结构

```
projects/{slug}/
  .pipeline/
    state.json                        # 流水线状态
    handoffs/
      01-requirements.json            # 阶段移交记录
      02-design.json
      ...
  docs/
    prd.md                            # 需求文档 (PM Agent)
    tech-design.md                    # 技术设计 (Architect Agent)
    tasks.md                          # 任务拆分 (Architect Agent)
    test-report.md                    # 测试报告 (QA Agent)
    release-notes.md                  # 发布说明 (Release Agent)
  src/                                # 源代码 (Dev Agent)
  tests/                              # 测试代码 (QA Agent)
```

## 2. 命名规则

- **slug**: 小写字母 + 连字符 (`pet-social`, `bookstore-mvp`)
- **handoff 文件**: `{两位序号}-{阶段名}.json` (`01-requirements.json`)
- **产物文件**: 固定名称 (`prd.md`, `tech-design.md`, `tasks.md`, `test-report.md`, `release-notes.md`)

## 3. Handoff Schema

```json
{
  "id": "01-requirements",
  "from_phase": "requirements",
  "to_phase": "design",
  "artifact": "docs/prd.md",
  "summary": "一句话摘要",
  "requested_by": {
    "id": "user123",
    "name": "Zephyr",
    "channel": "discord"
  },
  "approved_by": {
    "id": "user123",
    "name": "Zephyr",
    "channel": "discord"
  },
  "created_at": "2026-03-26T16:18:00Z"
}
```

所有身份信息使用 `{id, name, channel}` 三元组，不绑定具体通道。

## 4. state.json Schema

```json
{
  "project": "pet-social",
  "created_at": "2026-03-26T16:00:00Z",
  "current_phase": "design",
  "repo_url": "https://github.com/user/ai-pipeline-projects",
  "phases": {
    "requirements": {
      "status": "completed",
      "artifact": "docs/prd.md",
      "started_at": "2026-03-26T16:00:00Z",
      "completed_at": "2026-03-26T16:18:00Z",
      "agent": "pm",
      "approved_by": {"id": "user123", "name": "Zephyr", "channel": "discord"}
    },
    "design": {
      "status": "in_progress",
      "artifact": "docs/tech-design.md",
      "started_at": "2026-03-26T16:20:00Z",
      "agent": "architect"
    },
    "development": {"status": "pending"},
    "testing": {"status": "pending"},
    "release": {"status": "pending"}
  }
}
```

Phase status: `pending` → `in_progress` → `completed` (或 `rejected` → 回退上一阶段)

## 5. 阶段流转规则

```
requirements → design → development → testing → release
```

- 只能前进，不能跳过
- 每个阶段必须 approved 才能进入下一阶段
- 回退：`rejected` 回到上一阶段，重新产出
- 同一项目同一时间只有一个阶段 `in_progress`（无并发冲突）

## 6. Git 提交规则

- **Author**: `{Agent名} <{agent-id}@ai-pipeline.bot>`
- **Commit message**: `{phase}({slug}): 描述`
- **示例**: `requirements(pet-social): 完成 PRD v0.1`
- **Push 冲突处理**: `git pull --rebase && git push`（不同项目写不同目录，文件不冲突）

## 7. 通道抽象

Pipeline Core 不依赖具体通道。通道通过 adapter 接入：

```
Pipeline Core（规约 + Lobster + Git）
    ↓
Channel Adapter（收消息 + 发通知）
    ├── Discord (OpenClaw discord plugin)
    ├── Telegram (OpenClaw telegram plugin)
    ├── Web UI (future)
    └── CLI (future)
```

Adapter 只做两件事：
1. 收：用户消息 → 标准请求
2. 发：Pipeline 通知 → 格式化后发到通道
