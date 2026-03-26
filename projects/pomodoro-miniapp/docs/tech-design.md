# pomodoro-miniapp 技术设计文档 v1

## 1. 文档信息

- 项目：pomodoro-miniapp
- 版本：v1.0（MVP）
- 依据：`docs/prd.md`（PRD v0.1）
- 目标周期：1 周
- 团队规模：1 人

---

## 2. 设计目标与范围

### 2.1 目标

在微信小程序内实现稳定可用的番茄钟 MVP，满足：

1. 25/5 自动循环计时（focus/break）
2. 开始/暂停/继续/结束/重置
3. 今日统计（专注总分钟、完成番茄数）
4. 前后台切换后计时状态恢复
5. 无网络可用（本地化）

### 2.2 范围边界

本期仅实现「计时 + 统计」，不做：

- 社交排行
- 白噪音/音乐
- 任务清单
- 云同步/多端同步
- 打卡社区

---

## 3. 技术选型

- 平台：微信小程序
- 语言：TypeScript
- 架构：纯前端本地架构（无后端）
- 存储：`wx.setStorageSync` / `wx.getStorageSync`
- 提醒：`wx.showToast` + 可选 `wx.vibrateShort`

### 3.1 选型理由

1. PRD 明确无同步需求，本地存储即可满足 MVP。
2. 1 人 1 周交付，去后端可降低复杂度与不确定性。
3. 计时准确性核心在状态机与时间戳校准，前端可独立实现。

---

## 4. 系统架构

采用模块化单体（小程序端内聚）：

1. `TimerEngine`：计时状态机与阶段切换
2. `StateRepository`：状态持久化与恢复
3. `StatsService`：统计口径实现
4. `ReminderService`：阶段完成提醒
5. `TelemetryService`：轻量埋点

```text
UI(Page)
  -> TimerController
    -> TimerEngine
    -> StateRepository (Storage)
    -> StatsService
    -> ReminderService
    -> TelemetryService
```

---

## 5. 核心数据模型

### 5.1 Storage Keys

- `timer_state_v1`
- `daily_stats_v1`

### 5.2 timer_state_v1

```ts
interface TimerStateV1 {
  mode: 'focus' | 'break';
  status: 'idle' | 'running' | 'paused';
  durationSec: number;      // 当前阶段总时长
  remainingSec: number;     // 当前剩余秒数
  startedAt: number | null; // running开始时间戳(ms)
  pausedAt: number | null;  // paused时间戳(ms)
  accumulatedPausedMs: number; // 当前阶段累计暂停时长
  cycleId: string;          // 本轮唯一标识，用于幂等保护
}
```

### 5.3 daily_stats_v1

```ts
interface DailyStatsV1 {
  date: string; // YYYY-MM-DD
  focusPomodoroCount: number;
  focusTotalMin: number; // = focusPomodoroCount * 25
}
```

---

## 6. 状态机设计

### 6.1 基础常量

- `FOCUS_SEC = 25 * 60`
- `BREAK_SEC = 5 * 60`

### 6.2 状态转移

- `idle -> start -> running(focus)`
- `running -> pause -> paused`
- `paused -> resume -> running`
- `running|paused -> end -> idle`
- `running(focus, remaining=0) -> running(break)` 并触发 `focus_complete`
- `running(break, remaining=0) -> running(focus)` 并触发 `break_complete`
- `running|paused -> reset -> 当前mode初始时长`

### 6.3 业务规则

1. 仅完整完成 focus 阶段（25 分钟）时，番茄数 +1。
2. 用户手动 `end` 当前轮，不计入番茄数。
3. `focusTotalMin = focusPomodoroCount * 25`，不按零散秒数累加。

### 6.4 计时准确性策略

采用「时间戳重算」而非单纯 interval 扣秒：

```text
elapsed = now - startedAt - accumulatedPausedMs
remaining = durationSec - floor(elapsed / 1000)
```

- 每秒刷新 UI（前台可见时）
- `onShow` 时立即重算并恢复状态
- 防止后台挂起造成的误差积累

---

## 7. 页面与交互

### 7.1 页面结构

MVP 仅首页：

- 当前阶段：专注/休息
- 倒计时：`mm:ss`
- 按钮：开始、暂停、继续、结束、重置
- 今日统计卡片：专注分钟、番茄数

### 7.2 按钮可见性

- `idle`：开始
- `running`：暂停、结束、重置
- `paused`：继续、结束、重置

### 7.3 阶段切换提醒

- focus 结束：toast（如“专注完成，休息开始”）
- break 结束：toast（如“休息结束，下一轮专注开始”）
- 可选震动反馈（Could）

---

## 8. 稳定性与异常处理

1. **幂等保护**：同一 `cycleId` 的完成事件仅记一次，防止重复加番茄。
2. **跨天重置**：每次进入页面先检查日期；非当天则重置 `daily_stats_v1`。
3. **状态守卫**：非法转移（如 idle 下 resume）直接拒绝并记录日志。
4. **防抖**：按钮操作 300ms 防抖，避免连点引发竞态。

---

## 9. 埋点设计（轻量）

事件：

- `timer_start`
- `timer_pause`
- `timer_resume`
- `focus_complete`
- `break_complete`

MVP阶段先本地日志/console，后续可接入分析平台。

---

## 10. 代码结构建议

```text
miniprogram/
  pages/
    index/
      index.ts
      index.wxml
      index.wxss
  core/
    timer-engine.ts
    timer-types.ts
    timer-constants.ts
  services/
    storage-service.ts
    stats-service.ts
    reminder-service.ts
    telemetry-service.ts
  utils/
    time.ts
    date.ts
```

---

## 11. 验收映射（对应 PRD）

1. **计时准确性**：每秒递减，25/5 默认值准确，切换正确。
2. **状态控制**：暂停/继续/结束/重置符合预期。
3. **统计口径**：完整 focus 才 +1；总分钟=番茄数*25。
4. **稳定性**：前后台恢复准确；离线可用。

---

## 12. 后续可扩展（非本期）

- 个性化时长配置（如 50/10）
- 7 天趋势统计
- 云同步与账号体系
- 学习任务绑定与完成率分析
