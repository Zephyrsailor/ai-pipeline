# Snake Mini Game

一个纯前端、离线可玩的贪吃蛇小游戏（MVP）。

## 功能

- 20x20 网格棋盘（Canvas 渲染）
- 蛇自动移动
- 方向键控制，禁止直接反向
- 食物随机生成（避开蛇身）
- 吃食物增长并加分（每个食物 +1）
- 撞墙/撞自己 Game Over
- 空格键或按钮可重开

## 安装

```bash
cd /Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/snake-mini-game
npm install
```

## 运行测试

```bash
npm test
```

## 启动游戏

本项目为纯静态页面，可直接打开：

```bash
open /Users/zephyr/Desktop/lab/deep-research/ai-pipeline/projects/snake-mini-game/index.html
```

## 操作说明

- `↑` / `↓` / `←` / `→`：控制方向
- `Space`：在 Ready/Game Over 状态下开始或重开
- 点击“重新开始”按钮：立即重开

## 项目结构

- `index.html`：页面结构
- `style.css`：样式
- `game.js`：游戏主循环、输入、渲染
- `src/core.js`：核心规则逻辑
- `tests/core.test.js`：核心规则测试
- `docs/`：PRD、技术设计与任务拆分
