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

## 8. 多用户隔离与信息共享

### 设计原则

参照业内标准做法（Jira + Confluence + Slack 模式）：
- **文档是信息传递的载体**：Agent 间不传对话记录，传结构化产物文件
- **通知是触发器**：阶段完成 → 自动推送通知到下一频道
- **对话是各角色自己的**：每个 Thread 内的对话独立，不互相污染

### 项目隔离：Thread per Project

每个项目在每个频道创建独立 Thread，以 slug 命名：

```
#product
  └── 🧵 autoresearch       ← 用户A 的项目
  └── 🧵 office-agent       ← 用户B 的项目

#design
  └── 🧵 autoresearch       ← 同一项目，跨频道关联
  └── 🧵 office-agent

#dev
  └── 🧵 autoresearch
  └── 🧵 office-agent
```

- Thread 名 = 项目 slug = 串联标识
- OpenClaw 为每个 Thread 创建独立 session（`thread-bindings.ts`）
- 不同项目的对话天然隔离，零交叉污染

### 跨频道信息流

```
PM 在 #product/autoresearch Thread 讨论需求
  → 产出 prd.md，存到 projects/autoresearch/docs/
  → Bot 在 #design 自动创建 Thread "autoresearch" 并发通知
  → Architect 在 #design/autoresearch Thread 读 prd.md 做设计
  → 不需要看 PM 的对话过程
```

Agent 通过文件获取上游产出，不通过对话：

| Agent | 可写 | 可读 |
|-------|-----|------|
| PM | prd.md | — |
| Architect | tech-design.md, tasks.md | prd.md |
| Dev | src/, tests/ | prd.md, tech-design.md, tasks.md |
| QA | test-report.md | prd.md, src/, tests/ |
| Release | release-notes.md | 全部 |

### 权限边界（已知限制）

**Discord 能做到的（频道级 / 角色级）：**
- Role 绑定频道权限：Dev 角色只能进 #dev #qa，看不到 #product 的讨论
- Bot 自动创建 Thread + 绑定 session
- Thread 内 session 隔离（OpenClaw 原生支持）

**Discord 做不到的（Thread 级）：**
- Thread 不支持独立权限控制，权限继承自父频道
- 同一频道下的所有 Thread 彼此可见（如 #dev 下的所有项目 Thread 互相可见）
- 即：项目级隔离在 Discord 上无法实现

**影响评估：**
- 小团队（<20人）：不是问题，大家本来就看得到彼此的项目
- 需要项目级隔离时：方案 A — 每个项目用独立频道 + Category 权限覆盖；方案 B — 自建 Web 前端替代 Discord

**结论：MVP 阶段用频道级隔离足够，项目级隔离留给自建前端阶段。**

### 新项目创建流程

```
用户在 #product 发："新项目：{slug}"
  → Bot 自动创建 Thread "{slug}"
  → 初始化 projects/{slug}/ 目录
  → PM Agent 在 Thread 内开始需求讨论
  → 后续阶段自动在对应频道创建同名 Thread
```

### 多项目并发

- 不同项目写不同目录（projects/a/ vs projects/b/），文件不冲突
- 每个项目独立 state.json，状态不干扰
- Git push 竞争：`git pull --rebase && git push`（不同目录无文件冲突）
- 同一项目串行流转（Lobster approval gate 保证），无并发问题
