# 任务拆分文档：timed-alarm-app

- 项目：`timed-alarm-app`
- 仓库：`/Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/timed-alarm-app`
- 目标：完成 Web 定时闹钟 MVP

---

## 1. 任务优先级

## P0（Must）
1. 数据模型与 localStorage
2. 闹钟管理（新增/编辑/删除/启停）
3. 到点检测与提醒声音
4. 重复规则（once / daily / weekdays）
5. 24 小时制输入与显示

## P1（Should）
1. 操作提示与状态文案
2. 边界场景回归测试

---

## 2. 分阶段任务

## 阶段 A：数据与持久化
- [ ] 定义 Alarm 类型与默认状态
- [ ] 实现 `StorageService.load/save`
- [ ] 页面启动恢复闹钟数据

验收：刷新后闹钟列表与状态不丢失（AC5）

## 阶段 B：闹钟管理
- [ ] 新增闹钟（时间、重复规则）
- [ ] 列表展示（时间、规则、状态）
- [ ] 编辑、删除、启停开关

验收：可管理任意闹钟（AC1、AC2）

## 阶段 C：调度与提醒
- [ ] 实现 `Scheduler`（1 秒 tick）
- [ ] 实现规则判定与去重
- [ ] 到点播放音频 + 停止提醒按钮

验收：到点触发提醒，停用不触发（AC3、AC4）

## 阶段 D：规则完善与体验
- [ ] 实现 once/daily/weekdays 规则
- [ ] 统一 24 小时制显示
- [ ] 优化提示文案与错误反馈

验收：规则正确，24 小时制一致（AC6）

## 阶段 E：回归测试
- [ ] 一次性闹钟触发后自动停用
- [ ] daily/weekdays 连续触发正确
- [ ] 编辑/删除后行为正确
- [ ] 刷新恢复正确

验收：AC1~AC6 全量通过

---

## 3. 测试清单

1. 新增 once 闹钟并触发
2. 新增 daily 闹钟并触发
3. weekdays 在周末不触发
4. 停用闹钟不触发
5. 编辑时间后按新时间触发
6. 删除后不再触发
7. 刷新页面数据一致

---

## 4. 风险预案

1. 后台页面节流
- [ ] 增加命中容差与日志定位

2. 音频被浏览器限制
- [ ] 首次交互预热 AudioContext

3. 重复触发
- [ ] 维护 `lastTriggeredDate` 去重

---

## 5. 完成定义（DoD）

- [ ] `docs/tech-design.md` 完成
- [ ] `docs/tasks.md` 完成
- [ ] AC1~AC6 全通过
- [ ] 核心流程稳定可复现
- [ ] 纯前端离线可运行
