# AI Pipeline

OpenClaw + Lobster + Discord 驱动的 AI 研发流水线。

## 技术栈

- **OpenClaw** = Agent 网关 + Discord 通道
- **Lobster** = 确定性工作流引擎（OpenClaw 插件）
- **Discord** = 用户交互界面（频道 + Thread）

## 核心规则

1. **Lobster 控制流程，Agent 只做创作** — 不让 LLM 决定下一步
2. **所有 Agent 通过 OpenClaw 调用** — `openclaw agent -m "..." --agent <id> --json`，不用 `claude -p`，不写 shell 脚本
3. **数据通过文件传递** — Agent 读写 `projects/{slug}/docs/` 下的产物文件（prd.md, tech-design.md 等），不通过 stdout 传 JSON
4. **每个项目一个 Thread** — 消息发到项目 Thread 里，不污染频道主区
5. **Agent 输出人类可读内容** — markdown 格式，不是裸 JSON

## Agent 列表

| ID | 频道 | 产出物 |
|---|---|---|
| p-pm | #product | docs/prd.md |
| p-architect | #design | docs/tech-design.md, docs/tasks.md |
| p-dev | #dev | src/, tests/ |
| p-reviewer | #dev | review comments |
| p-qa | #qa | docs/test-report.md |
| p-release | #release | docs/release-notes.md |
| p-triage | #bugs | triage report |

## 工作流

详见 `workflows/product-dev.lobster` 和 `workflows/bugfix.lobster`。

## 规约

目录结构、命名规则、handoff schema、state.json、Git 规范、Thread 隔离策略 — 全部定义在 `CONVENTIONS.md`。

## 参考

- [ggondim 多 Agent 管道](https://dev.to/ggondim/how-i-built-a-deterministic-multi-agent-dev-pipeline-inside-openclaw-and-contributed-a-missing-4ool)
- `AI研发体系技术雷达_2026-03-25.md`
- OpenClaw docs: `docs/tools/subagents.md`, `docs/concepts/multi-agent.md`
