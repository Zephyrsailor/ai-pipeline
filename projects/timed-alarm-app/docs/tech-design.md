# 技术设计文档：timed-alarm-app

- 项目：`timed-alarm-app`
- PRD：`/Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/timed-alarm-app/docs/prd.md`
- 目标：交付纯前端 Web 定时闹钟 MVP（24 小时制）

---

## 1. 设计目标

MVP 必须支持：
1. 一次性闹钟与重复闹钟（daily / weekdays）
2. 闹钟增删改查与启停
3. 到点声音提醒 + 手动停止
4. localStorage 持久化，刷新后可恢复

约束：
- 无后端、无账号、无跨设备同步
- 不做贪睡和系统推送

---

## 2. 架构设计

采用单页前端架构：

1. **UI 层**
   - AlarmForm：新增/编辑
   - AlarmList：展示与操作
   - RingModal：提醒弹层与停止按钮

2. **业务层**
   - AlarmService：闹钟规则与状态更新
   - Scheduler：每秒检测触发

3. **基础层**
   - StorageService：localStorage 读写
   - AudioService：提示音播放与停止

数据流：
- 用户操作 -> Store 更新 -> Storage 持久化
- Scheduler tick -> 命中规则 -> RingModal + Audio 播放

---

## 3. 数据模型

```ts
type RepeatRule = 'once' | 'daily' | 'weekdays';

interface Alarm {
  id: string;
  time: string; // HH:mm
  repeatRule: RepeatRule;
  enabled: boolean;
  lastTriggeredDate: string | null; // YYYY-MM-DD
  createdAt: number;
  updatedAt: number;
}

interface AppState {
  alarms: Alarm[];
  ringingAlarmId: string | null;
}
```

设计要点：
- `lastTriggeredDate` 解决同一天重复触发问题。
- 24 小时制统一使用 `HH:mm`。

---

## 4. 关键逻辑

## 4.1 触发判定
满足以下条件才触发：
- `enabled = true`
- 当前时间匹配 `alarm.time`
- 重复规则匹配当天
- `lastTriggeredDate !== today`

## 4.2 重复规则
- `once`：触发后自动 `enabled=false`
- `daily`：每天可触发一次
- `weekdays`：仅周一到周五可触发

## 4.3 提醒行为
- 触发后播放提示音并显示提醒层
- 用户点击“停止提醒”后停止音频，关闭提醒层

---

## 5. 存储设计

- Key：`timedAlarmApp.alarms`
- 存储内容：`Alarm[]`
- 写入时机：新增/编辑/删除/启停/触发更新后
- 启动时：读取并校验，异常时回退空数组

---

## 6. 验收映射

- AC1：新增一次性与重复闹钟 -> AlarmForm + AlarmService
- AC2：编辑/删除/启停 -> AlarmList + AlarmService
- AC3：到点声音提醒 -> Scheduler + AudioService
- AC4：停用不触发 -> Scheduler 过滤 `enabled`
- AC5：刷新保持一致 -> StorageService
- AC6：24 小时制 -> UI/数据层统一 HH:mm

---

## 7. 风险与应对

1. **浏览器后台节流**：定时检测可能延迟
   - 应对：1 秒 tick + 命中窗口容差（可配置 1~2 秒）
2. **音频自动播放限制**：部分浏览器会拦截
   - 应对：首次用户交互后预热音频上下文
3. **重复触发**：同一分钟重复命中
   - 应对：使用 `lastTriggeredDate` 去重

---

## 8. 扩展预留

- Snooze（贪睡）
- Notification API 系统通知
- 自定义铃声与音量
- 更细粒度重复规则（每周自定义）
