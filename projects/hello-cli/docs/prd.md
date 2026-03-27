# PRD v0.2｜hello-cli（最简 Node.js 命令行工具）

## 1. 项目概述

- **项目名**：hello-cli
- **目标**：在本地命令行通过可选参数输入名字并输出问候语。
- **目标用户**：开发者本人（本地使用）。
- **技术约束**：Node.js + JavaScript（MVP 默认 JS）。
- **范围约束**：只做单功能，不做发布与扩展能力。

## 2. 需求定义

- 命令：`hello-cli <name>`
- 当提供 `name` 时输出：`Hello, <name>`
- 当未提供 `name` 时输出：`Hello World`

示例：
- `hello-cli 张三` → `Hello, 张三`
- `hello-cli` → `Hello World`

## 3. 用户故事

- 作为用户，我想在命令行输入（或不输入）名字并立即看到问候语，以便快速验证 CLI 可用。

## 4. 功能范围（MoSCoW）

### Must
- 支持命令格式：`hello-cli [name]`
- 有名字时输出：`Hello, <name>`
- 无名字时输出：`Hello World`
- 本地命令行可运行

### Won’t（本期不做）
- 交互式输入
- `-h/--help` 帮助菜单
- 参数校验增强
- npm 发布/全局安装流程
- 配置文件、日志、测试框架

## 5. 验收标准（Acceptance Criteria）

1. 执行 `hello-cli 张三`，输出严格为：`Hello, 张三`
2. 执行 `hello-cli`，输出严格为：`Hello World`
3. 任意名字参数（如 `hello-cli Alice`）输出：`Hello, Alice`
4. 命令执行为即时输出（无明显等待）

## 6. 技术边界（MVP）

- 单文件实现即可（例如 `bin/hello.js`）
- 使用 Node.js 原生参数读取（`process.argv`）
- 不依赖外部服务，不需要网络
