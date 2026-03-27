# hello-cli 技术设计文档 v1

## 1. 文档信息

- 项目：hello-cli
- 版本：v1.0（MVP）
- 依据：`docs/prd.md`（PRD v0.1）
- 目标：实现最简本地命令行问候工具

---

## 2. 目标与范围

### 2.1 目标

实现命令：

```bash
hello-cli <name>
```

输出固定格式：

```text
Hello, <name>!
```

### 2.2 范围边界（严格遵循 PRD）

本期仅实现：

- 参数读取（第一个位置参数）
- 固定模板输出
- 本地命令行可直接运行

本期不做：

- 交互式输入
- `-h/--help`
- 参数校验增强
- npm 发布与全局安装文档

---

## 3. 技术选型

- 运行时：Node.js
- 语言：JavaScript（CommonJS）
- 依赖：零依赖（不引入三方库）
- 实现规模：单文件

### 3.1 选型理由

1. 最小实现成本，符合“最简命令行工具”目标。
2. 无外部依赖，执行路径短、输出即时。
3. 可读性高，便于后续扩展（如参数校验/帮助菜单）。

---

## 4. 架构与执行流程

### 4.1 文件结构

```text
hello-cli/
  ├─ package.json
  └─ index.js
```

### 4.2 执行流程

1. 用户执行：`hello-cli 张三`
2. Node 启动 `index.js`
3. 读取 `process.argv[2]` 为 `name`
4. 输出 `Hello, ${name}!`
5. 进程结束

---

## 5. 关键实现设计

### 5.1 package.json

关键字段：

- `name`: `hello-cli`
- `bin`: `{ "hello-cli": "./index.js" }`

用于将命令名 `hello-cli` 映射到入口脚本。

### 5.2 index.js

关键点：

1. 第一行 shebang：`#!/usr/bin/env node`
2. 读取第一个参数：`const name = process.argv[2]`
3. 固定格式输出：`console.log(`Hello, ${name}!`)`

---

## 6. 非功能说明

- 性能：仅同步字符串输出，执行应为即时。
- 可靠性：无网络、无 IO 依赖，运行稳定。
- 安全性：无外部输入执行、无文件系统写操作。

---

## 7. 验收映射

对应 PRD 验收项：

1. `hello-cli 张三` 输出 `Hello, 张三!`
2. `hello-cli Alice` 输出 `Hello, Alice!`
3. 输出即时，无明显等待

---

## 8. 风险与应对

### 风险1：本地命令映射未生效

- 现象：执行 `hello-cli` 找不到命令
- 应对：检查 `package.json` 的 `bin` 字段与入口路径

### 风险2：脚本执行权限问题

- 现象：命令存在但无法执行
- 应对：确保 `index.js` 含 shebang 且具备执行权限（必要时 `chmod +x`）

---

## 9. 后续可扩展方向（非本期）

- 参数缺失提示
- `--help` 使用说明
- 多语言问候模板
- npm 包发布
