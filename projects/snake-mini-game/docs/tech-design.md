# 技术设计文档：snake-mini-game

- 项目：`snake-mini-game`
- 仓库：`/Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/snake-mini-game`
- 关联 PRD：`docs/prd.md`
- 技术约束：原生 `HTML + CSS + JavaScript`，无后端

---

## 1. 设计目标

在 1~2 天内交付可稳定游玩的贪吃蛇 MVP，实现：
1. 固定网格画布（20x20）
2. 蛇自动移动与方向控制（禁止直接反向）
3. 食物随机生成与吃食物增长
4. 碰撞检测（墙体/自身）
5. 分数显示、Game Over、快速重开

---

## 2. 总体架构

采用单页应用 + 游戏循环架构：

1. **渲染层（Renderer）**
   - 基于 Canvas 按网格绘制蛇、食物、背景
2. **状态层（State）**
   - 持有蛇体、方向、食物、分数、游戏状态
3. **规则层（Game Logic）**
   - 位移、吃食物、生长、碰撞、结束判定
4. **输入层（Input）**
   - 键盘监听（↑↓←→、空格重开）+ 反向输入保护
5. **控制层（Controller）**
   - 管理 `setInterval(gameTick, speed)` 生命周期

---

## 3. 数据模型

```js
const GRID_SIZE = 20;        // 20x20
const CELL_SIZE = 20;        // 每格像素（可调）
const SPEED_MS = 150;        // MVP 固定速度

state = {
  snake: [                    // 头在数组首位
    { x: 10, y: 10 },
    { x: 9, y: 10 },
    { x: 8, y: 10 }
  ],
  direction: { x: 1, y: 0 },      // 当前方向（初始向右）
  nextDirection: { x: 1, y: 0 },  // 下一 tick 生效方向
  food: { x: 15, y: 10 },
  score: 0,
  gameState: 'ready' // ready | running | over
};
```

说明：
- `direction` 与 `nextDirection` 分离，防止同一 tick 内多次按键导致异常转向。
- 蛇体采用坐标数组，便于头插尾删实现移动。

---

## 4. 核心流程设计

## 4.1 启动/重开流程
1. 初始化状态（蛇长 3、向右、分数 0）。
2. 随机生成食物（不能与蛇重叠）。
3. `gameState=running`，启动定时器。
4. 更新状态文案（游戏中）。

## 4.2 每帧（每 tick）逻辑
1. 应用 `nextDirection` 到 `direction`。
2. 计算新蛇头坐标 `newHead`。
3. 判定是否撞墙或撞自己：
   - 是 -> `gameState=over`，停止定时器，显示 `Game Over`。
4. 若未碰撞，头插入蛇体。
5. 判定是否吃到食物：
   - 吃到：分数 +1，生成新食物，保留蛇尾（实现增长）
   - 未吃到：删除蛇尾（保持长度）
6. 触发重绘（蛇、食物、分数、状态）。

## 4.3 输入处理
- `ArrowUp/Down/Left/Right`：更新 `nextDirection`
- 反向输入保护：
  - 若当前 `direction={1,0}`，禁止 `{-1,0}`
  - 若当前 `direction={0,1}`，禁止 `{0,-1}`
- `Space`：当 `ready/over` 时执行重开

---

## 5. 关键模块划分

建议文件结构（MVP 可单 JS 文件实现，按函数分区）：

```text
index.html
style.css
game.js
```

`game.js` 建议函数：
- `initGame()`：初始化游戏
- `startLoop()` / `stopLoop()`：管理定时器
- `gameTick()`：核心规则循环
- `setDirection(dx, dy)`：方向变更（含反向校验）
- `spawnFood()`：随机食物生成（避开蛇体）
- `isCollision(point)`：墙体+自身碰撞检测
- `render()`：Canvas 绘制与 UI 同步
- `restartGame()`：重开入口

---

## 6. 渲染策略

- Canvas 尺寸：`GRID_SIZE * CELL_SIZE`（如 400x400）
- 每次 tick 全量重绘（MVP 简洁可靠）
- 颜色建议：
  - 背景：深色或浅色纯底
  - 蛇头：高亮色
  - 蛇身：次级色
  - 食物：对比鲜明色（如红）

---

## 7. 风险与缓解

1. **反向输入导致瞬间自撞逻辑异常**
   - 缓解：引入 `nextDirection`，每 tick 只应用一次方向更新。
2. **食物刷到蛇身上**
   - 缓解：生成时循环校验直到落在空格。
3. **重复启动多个定时器**
   - 缓解：`startLoop()` 前先 `stopLoop()`，确保单实例循环。
4. **边界碰撞 off-by-one 错误**
   - 缓解：统一边界条件：`x<0 || x>=GRID_SIZE || y<0 || y>=GRID_SIZE`。

---

## 8. 验收标准映射

- AC1（可开始+自动移动）-> `initGame + startLoop + gameTick`
- AC2（方向控制+禁反向）-> `setDirection`
- AC3（吃食物增长+加分+刷新食物）-> `gameTick + spawnFood`
- AC4（撞墙/撞自己结束）-> `isCollision + stopLoop`
- AC5（重开重置）-> `restartGame`
- AC6（Chrome 稳定）-> 固定 tick + 轻量渲染

---

## 9. 扩展预留（非本期）

- 本地最高分（localStorage）
- 难度曲线（分数越高速度越快）
- 暂停/继续
- 音效/BGM
