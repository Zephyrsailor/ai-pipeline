# AI Pipeline

用自然语言管理一支 AI 研发团队 — 从需求到上线，全流程自动协作，人只需要把关关键节点。

## 愿景

软件研发不应该从招人开始。

告诉 AI "做一个番茄钟小程序"，它自动组建产品经理、架构师、开发、测试、发布五个角色，按标准 SDLC 流程协作把东西做出来。代码走正规 Git + PR 流程，人始终把关质量。

**路径：** 先为自己省事 → 内部打磨到 production-grade → 对外商业化服务企业。

## 核心设计思想

### 1. LLM 不控制流程，流程控制 LLM

LLM 擅长创作，不擅长决策。让确定性状态机（Lobster）编排阶段流转，LLM 只负责在每个阶段内做创造性工作。这不是 "AI 自主决定下一步" 的 Agent 系统，而是 "流程引擎驱动 AI 干活" 的生产工具。

### 2. 文件是信息载体，不是对话

Agent 之间不传对话记录，传结构化产物文件（PRD、技术设计、任务清单）。这跟真实团队用 Jira + Confluence + Slack 的模式一样 — 文档是交接媒介，对话是各角色自己的。

### 3. 通道无关

Pipeline 核心逻辑不绑定 Discord。今天用 Discord 做前端，明天可以换 Telegram、Web UI 或 CLI，不需要改任何 AI 的工作逻辑。通道通过 Adapter 接入，Adapter 只做两件事：收消息、发通知。

### 4. 生产标准，不是 Demo

AI 写的代码不会直接上线 — 自动建仓库、建分支、提 Draft PR、等人审批。每一步都有 approval gate，每一次 handoff 都有 Git commit 记录。从第一天起就按商业产品标准设计。

## 架构

```
用户（Discord / Telegram / CLI）
  ↓
Channel Adapter（收消息 → 标准请求 / Pipeline 通知 → 格式化发送）
  ↓
Lobster 状态机（确定性编排，approval gate 管阶段转换）
  ↓
OpenClaw Agent 网关（调度 AI Agent 执行具体工作）
  ↓
AI Agent（PM / Architect / Dev / Reviewer / QA / Release）
  ↓
产物文件（docs/prd.md → docs/tech-design.md → src/ → docs/test-report.md → docs/release-notes.md）
  ↓
Git + PR 工作流（分支 → Draft PR → Review → Merge）
```

### SDLC 阶段映射

| 阶段 | AI Agent | 输入 | 输出 |
|------|----------|------|------|
| 需求分析 | PM Agent | 原始需求 | PRD（用户故事 + 验收标准）|
| 技术设计 | Architect Agent | PRD | 技术设计文档 + 任务拆分 |
| 开发 | Dev Agent | 设计文档 + 任务 | 代码 + PR |
| 代码审查 | Review Agent | PR | 审查意见 |
| 测试 | QA Agent | 代码 + 验收标准 | 测试报告 |
| 发布 | Release Agent | 测试通过的代码 | Release Notes |

### 技术栈

- **[Lobster](https://github.com/nicholasgriffintn/lobster)** — 确定性工作流引擎，OpenClaw 插件，负责阶段流转和 approval gate
- **[OpenClaw](https://github.com/nicholasgriffintn/openclaw)** — Agent 网关 + Discord 集成，负责调度 AI Agent 和消息通道
- **Discord** — 用户交互界面（频道按职能划分，Thread 按项目隔离）

## 项目结构

```
ai-pipeline/
├── workflows/           # Lobster 工作流定义
│   ├── product-dev.lobster      # 产品研发主流程
│   ├── bugfix.lobster           # Bug 修复流程
│   └── product-dev-auto.lobster # 自动化版本（减少人工审批）
├── workspaces/          # Agent 工作空间（SOUL.md 定义角色人格和方法论）
│   ├── p-pm/            # 产品经理
│   ├── p-architect/     # 架构师
│   ├── p-dev/           # 开发者
│   ├── p-reviewer/      # 代码审查
│   ├── p-qa/            # 测试
│   ├── p-release/       # 发布
│   ├── p-triage/        # Bug 分诊
│   └── p-pipeline/      # 流水线管理
├── config/              # OpenClaw 配置
├── prompts/             # Agent 提示词模板
├── CONVENTIONS.md       # 全部规约（目录结构、命名、Handoff Schema、Git 规范）
├── AGENTS.md            # Agent 行为规范
└── CLAUDE.md            # 项目说明（供 AI 读取）
```

## 从零开始部署

### Step 1: 安装依赖

```bash
# Node.js >= 22
nvm install 22

# OpenClaw（全局安装）
npm install -g openclaw

# GitHub CLI（用于自动建仓库和 PR）
brew install gh    # macOS
# 或参考 https://cli.github.com/

# 登录 GitHub
gh auth login
```

### Step 2: 创建 Discord Bot 和频道

**创建 Bot：**

1. 前往 [Discord Developer Portal](https://discord.com/developers/applications)，创建 Application
2. Bot 页面 → 点击 "Reset Token" 获取 Bot Token
3. Bot 页面 → 开启 **Message Content Intent**、**Server Members Intent**、**Presence Intent**
4. OAuth2 → URL Generator → 勾选 `bot` + `applications.commands`，权限勾选：
   - Send Messages、Create Public Threads、Send Messages in Threads、Manage Threads、Read Message History、Embed Links
5. 用生成的 URL 邀请 Bot 到你的 Discord Server

**创建频道：**

在 Discord Server 中创建以下频道（建议用 Category 分组）：

```
PRODUCT
  └── #product        ← PM Agent 工作区

ENGINEERING
  ├── #design         ← Architect Agent 工作区
  ├── #dev            ← Dev + Reviewer Agent 工作区
  ├── #qa             ← QA Agent 工作区
  └── #bugs           ← Bug Triage 工作区

OPERATIONS
  ├── #release        ← Release Agent 工作区
  └── #dashboard      ← 审批通知
```

**获取 ID：**

Discord 设置 → 高级 → 开启"开发者模式"，然后右键频道/服务器可以复制 ID。记下：
- Guild ID（服务器 ID）
- 每个频道的 Channel ID

### Step 3: 克隆仓库并配置

```bash
git clone <repo-url> ai-pipeline
cd ai-pipeline
```

**配置环境变量：**

```bash
cp .env.example .env
# 编辑 .env，填入你的 Bot Token：
# DISCORD_BOT_TOKEN=你的Token
```

**配置频道映射：**

编辑 `config/channels.json`，替换为你的 Channel ID：

```json
{
  "discord": {
    "product":   "你的 #product Channel ID",
    "design":    "你的 #design Channel ID",
    "dev":       "你的 #dev Channel ID",
    "qa":        "你的 #qa Channel ID",
    "bugs":      "你的 #bugs Channel ID",
    "release":   "你的 #release Channel ID",
    "dashboard": "你的 #dashboard Channel ID"
  }
}
```

**配置 OpenClaw：**

编辑 `config/openclaw.pipeline.json`，需要替换三类内容：

1. **workspace 路径** — 所有 Agent 的 `workspace` 字段改为你本机的仓库绝对路径
2. **Guild ID** — `bindings` 和 `channels` 中的 `guildId` / Guild key 改为你的服务器 ID
3. **Channel ID** — `bindings` 中的 `channelId` 和 `channels.discord.guilds.*.channels` 改为你的频道 ID

然后合并到 OpenClaw 全局配置：

```bash
# 首次安装 OpenClaw 会生成 ~/.openclaw/openclaw.json
# 把 config/openclaw.pipeline.json 的内容合并进去
# 主要是 agents.list、bindings、channels、plugins 四个字段
```

**配置工作流中的 Guild ID：**

`workflows/*.lobster` 文件中硬编码了 Guild ID（用于自动创建 Thread），搜索替换：

```bash
# 把旧的 Guild ID 替换为你的
grep -r "1486608599839932519" workflows/
# 逐个替换，或用 sed：
sed -i '' 's/1486608599839932519/你的GuildID/g' workflows/*.lobster
```

同理替换 Channel ID（`ct()` 函数中的频道参数）。

### Step 4: 网络要求

Discord API 需要能直连国际网络。建议使用海外服务器部署，或本地开启 TUN 模式代理。

### Step 5: 启动

```bash
# 初始化 OpenClaw（首次）
openclaw setup

# 启动网关
openclaw start

# 检查 Discord 连接状态
tail -f ~/.openclaw/logs/gateway.log
# 看到 "gateway ready" 表示连接成功
```

### Step 6: 验证

在 Discord `#product` 频道发一条消息，Bot 应该会回复（PM Agent 响应）。

如果没反应，检查：
1. `tail ~/.openclaw/logs/gateway.err.log` — 有没有 ECONNRESET（网络问题）
2. Bot 是否在服务器中、是否有频道权限
3. `openclaw.json` 中频道是否配置了 `"allow": true`

---

## 日常使用

### 通过 Discord 启动研发项目

1. 在 `#product` 频道发需求："新项目：todo-app，做一个待办事项应用"
2. PM Agent 在自动创建的 Thread 中与你讨论需求，产出 PRD
3. 人工审批 PRD → Architect Agent 自动开始技术设计
4. 人工审批设计 → Dev Agent 自动建仓库、建分支、写代码、提 PR
5. 人工审批代码 → QA 测试 → Release 发布
6. 全程可在各频道 Thread 中查看进度和产出物

### 通过 CLI 手动触发工作流

```bash
# 产品研发流程
npm run product-dev -- \
  --slug todo-app \
  --requirement "做一个待办事项应用" \
  --repo /path/to/todo-app \
  --product_thread <thread_id>

# Bug 修复流程
npm run bugfix -- \
  --slug todo-app \
  --bug_description "完成按钮点击无响应" \
  --repo /path/to/todo-app
```

## 设计决策

### 为什么不让 AI 自主编排？

AutoGPT 式的 "AI 决定下一步" 在 demo 里很酷，在生产中是灾难。你无法预测它会跳到哪一步、跳过什么、重复什么。确定性状态机保证流程可预测、可审计、可回退。

### 为什么用文件传递而不是 API 调用？

文件天然有版本控制（Git）、可审查（PR diff）、可恢复（checkout 回退）。Agent 之间通过 stdout 传 JSON 看起来高效，但不可审计、不可回退、不可人工介入。

### 为什么每个 Agent 有独立人格？

通用 AI 干所有事 = 什么都做不好。PM Agent 知道怎么写用户故事和验收标准，Architect Agent 知道怎么做技术选型和任务拆分。专业分工让每个环节的产出质量更高。

### 为什么需要 approval gate？

AI 的输出不可 100% 信任。关键节点（需求确认、设计确认、代码合并）必须人工把关。这不是效率损失，是质量保障。

## 规约

目录结构、命名规则、Handoff Schema、state.json 格式、Git 提交规范、Thread 隔离策略 — 全部定义在 [CONVENTIONS.md](./CONVENTIONS.md)。

## License

Private — 内部使用。
