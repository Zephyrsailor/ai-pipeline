# 技术设计文档：Timed Alarm Web

- 项目：`timed-alarm-app`
- PRD：`/Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/timed-alarm-app/docs/prd.md`
- 目标：实现个人可用的 Web 定时闹钟 MVP（24 小时制）

---

## 1. 设计目标

围绕 PRD Must 范围，交付以下能力：
1. 一次性闹钟 + 重复闹钟（每日/工作日）
2. 闹钟管理（新增、编辑、删除、启停）
3. 到点声音提醒 + 手动停止
4. localStorage 持久化（刷新后恢复）

---

## 2. 总体架构

采用纯前端单页架构：
- **UI 层**：闹钟表单、闹钟列表、提醒弹层
- **状态层**：统一 store 管理 alarms 与 UI 状态
- **领域层**：调度器（到点检测）、重复规则计算、触发去重
- **基础设施层**：localStorage、Audio API

数据流：
1. 用户操作 UI -> 触发 action
2. store 更新状态 -> 持久化到 localStorage
3. 调度器每秒检查可触发闹钟
4. 触发后播放声音并展示停止按钮

---

## 3. 数据模型

```ts
type RepeatRule = 'once' | 'daily' | 'weekdays';

interface Alarm {
  id: string;
  time: string;           // HH:mm
  repeatRule: RepeatRule;
  enabled: boolean;
  lastTriggeredDate?: string; // YYYY-MM-DD，用于同日去重
  createdAt: number;
  updatedAt: number;
}

interface AppState {
  alarms: Alarm[];
  ringingAlarmId: string | null;
}
```

说明：
- `lastTriggeredDate` 用于防止同一天重复触发（尤其是 daily/weekdays）。
- `time` 固定 24 小时制 `HH:mm`。

---

## 4. 核心模块设计

1. **AlarmForm**
   - 新增/编辑闹钟
   - 输入校验（HH:mm、repeatRule）

2. **AlarmList**
   - 展示字段：时间、类型、重复规则、状态
   - 操作：编辑、删除、启停

3. **SchedulerService**
   - 1 秒 tick（`setInterval`）
   - 判断当前时间是否命中闹钟
   - 检查重复规则与 `enabled`

4. **ReminderService**
   - 播放音频、显示提醒层
   - 停止按钮控制音频停止

5. **StorageService**
   - `loadAlarms()` / `saveAlarms()`
   - 应用启动恢复数据

---

## 5. 关键规则与算法

## 5.1 到点触发判定
当满足以下条件则触发：
- `enabled = true`
- 当前时间 `HH:mm` 等于闹钟时间
- 重复规则匹配当天：
  - `once`：仅未触发过时触发
  - `daily`：每天可触发一次
  - `weekdays`：周一到周五可触发一次
- 当日未触发（`lastTriggeredDate !== today`）

## 5.2 一次性闹钟处理
- 触发后自动置为 `enabled=false`（避免再次触发）

## 5.3 重复闹钟处理
- 触发后仅更新 `lastTriggeredDate=today`，保持 `enabled=true`

---

## 6. 本地存储设计

- Key：`timedAlarmApp.alarms`
- 存储内容：`Alarm[]`
- 时机：每次新增/编辑/删除/启停/触发状态变化后保存
- 启动：读取并做结构校验，不合法则回退空数组

---

## 7. 验收映射

- AC1（新增一次性与重复）-> AlarmForm + 数据模型
- AC2（编辑/删除/启停）-> AlarmList + Store
- AC3（到点声音提醒）-> SchedulerService + ReminderService
- AC4（停用不触发）-> SchedulerService 过滤 enabled
- AC5（刷新保持一致）-> StorageService
- AC6（24 小时制）-> UI 输入与显示统一 HH:mm

---

## 8. 风险与缓解

1. **浏览器后台节流导致延迟**
   - 缓解：采用每秒检查 + 时间命中窗口容差（可选 0~2 秒）
2. **音频自动播放限制**
   - 缓解：首次交互后预热音频；失败时提示用户允许声音
3. **重复触发问题**
   - 缓解：使用 `lastTriggeredDate` 去重

---

## 9. 扩展预留

- Snooze（贪睡）
- 系统通知（Notification API）
- 自定义铃声
- 更复杂重复规则（每周自定义）
