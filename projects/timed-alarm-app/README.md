# Timed Alarm App

一个纯前端定时闹钟应用（24 小时制），支持一次性与重复闹钟（每日/工作日），并提供到点声音提醒。

## 功能

- 新增闹钟（时间 + 重复规则）
- 编辑、删除、启停闹钟
- 调度器每秒检查到点触发
- 到点弹窗 + 声音提醒，可手动停止
- localStorage 持久化，刷新后恢复

## 安装与运行

```bash
cd /Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/timed-alarm-app
npm install
```

本项目是纯静态前端，直接打开页面即可：

```bash
open /Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/timed-alarm-app/index.html
```

## 测试

```bash
npm test
```

## 重复规则说明

- `once`：一次性，到点后自动停用
- `daily`：每天触发一次
- `weekdays`：仅周一到周五触发一次

## 目录结构

- `index.html`：页面结构
- `styles.css`：样式
- `src/core.js`：闹钟规则与触发判断
- `src/storage.js`：本地存储封装
- `src/app.js`：UI、调度与提醒主流程
- `tests/`：核心规则与存储测试
