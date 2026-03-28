# 任务拆分：snake-mini-game

- 项目：`snake-mini-game`
- 仓库：`/Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/snake-mini-game`
- 目标：1~2 天交付可玩 MVP

---

## 一、优先级清单（MoSCoW）

## Must（必须）
1. 20x20 网格与 Canvas 渲染
2. 蛇自动移动
3. 方向键控制与禁止直接反向
4. 食物随机生成
5. 吃食物增长 + 分数+1
6. 墙体/自身碰撞检测
7. Game Over 显示
8. Restart（按钮或空格）

## Should（应该）
9. 开始提示与状态文案
10. 分数区实时更新

## Could（可选）
11. 最高分（localStorage）

---

## 二、执行计划（1~2天）

## Day 1：核心玩法闭环

### D1-T1 页面与基础结构
- [ ] 搭建 `index.html`：标题、分数区、Canvas、状态区、Restart
- [ ] 搭建 `style.css`：基础布局与可读样式
- [ ] 初始化 `game.js`

**验收**：页面结构完整，画布可显示。

### D1-T2 状态初始化与主循环
- [ ] 定义 `state`（snake/food/direction/score/gameState）
- [ ] 实现 `initGame()`
- [ ] 实现 `startLoop()/stopLoop()` 与 `setInterval(gameTick, 150)`

**验收**：开始后蛇可自动移动。

### D1-T3 键盘控制
- [ ] 接入方向键监听
- [ ] 实现 `setDirection(dx,dy)`
- [ ] 实现“禁止直接反向”规则

**验收**：方向控制正确，无法瞬间反向。

### D1-T4 食物与成长
- [ ] 实现 `spawnFood()`（避开蛇体）
- [ ] 吃食物判定
- [ ] 吃到后：蛇增长、分数+1、刷新食物

**验收**：满足“吃食物即增长+加分”。

### D1-T5 碰撞与结束
- [ ] 实现 `isCollision()`（墙体+自身）
- [ ] 碰撞后进入 `over`，停止循环
- [ ] 状态区显示 `Game Over`

**验收**：撞墙或撞自己立即结束。

---

## Day 2：重开与打磨

### D2-T1 Restart 能力
- [ ] 实现按钮重开
- [ ] 实现空格重开（ready/over 状态）
- [ ] 重开时重置分数、蛇体、方向、食物

**验收**：可快速重开，状态完全重置。

### D2-T2 UI 与可用性优化
- [ ] 完善状态文案（Ready / Running / Game Over）
- [ ] 分数实时显示
- [ ] 操作提示（方向键、空格）

**验收**：信息清晰、上手即玩。

### D2-T3 自测与修复
- [ ] 回归全链路（开始→吃食物→结束→重开）
- [ ] 边界测试（贴墙移动、高速连续按键）
- [ ] Chrome 下性能观察（无明显卡顿）

**验收**：通过 AC1~AC6。

---

## 三、AC 对照矩阵

- AC1 -> D1-T2
- AC2 -> D1-T3
- AC3 -> D1-T4
- AC4 -> D1-T5
- AC5 -> D2-T1
- AC6 -> D2-T3

---

## 四、风险处理任务

1. **反向输入冲突**
- 任务：引入 `nextDirection`，每 tick 应用一次。

2. **食物生成冲突**
- 任务：生成逻辑循环排除蛇体坐标。

3. **多定时器重复运行**
- 任务：重开前统一 stop，再 start。

4. **边界判定错误**
- 任务：统一边界条件并加针对性测试。

---

## 五、完成定义（DoD）

- [ ] `docs/tech-design.md` 完成并可评审
- [ ] `docs/tasks.md` 完成并可执行
- [ ] Must 功能全部通过
- [ ] 支持 Game Over 与重开
- [ ] Chrome 桌面端可稳定运行
- [ ] 无后端依赖，离线可玩
