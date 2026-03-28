import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createInitialState,
  isReverseDirection,
  setNextDirection,
  spawnFood,
  isCollision,
  gameTick,
  GRID_SIZE,
} from '../src/core.js';

test('initial state 正确', () => {
  const s = createInitialState();
  assert.equal(s.snake.length, 3);
  assert.equal(s.score, 0);
  assert.equal(s.gameState, 'ready');
});

test('反向输入被禁止', () => {
  const s = createInitialState();
  const before = { ...s.nextDirection };
  setNextDirection(s, -1, 0);
  assert.deepEqual(s.nextDirection, before);
  assert.equal(isReverseDirection({ x: 1, y: 0 }, { x: -1, y: 0 }), true);
});

test('spawnFood 不会出现在蛇身上', () => {
  const snake = [{ x: 0, y: 0 }, { x: 1, y: 0 }];
  const seq = [0, 0, 0.8, 0.8];
  let i = 0;
  const food = spawnFood(snake, () => seq[i++]);
  assert.equal(food.x, Math.floor(0.8 * GRID_SIZE));
  assert.equal(food.y, Math.floor(0.8 * GRID_SIZE));
});

test('墙体与自身碰撞检测', () => {
  assert.equal(isCollision({ x: -1, y: 0 }, []), true);
  assert.equal(isCollision({ x: 0, y: 0 }, [{ x: 0, y: 0 }]), true);
  assert.equal(isCollision({ x: 1, y: 1 }, [{ x: 0, y: 0 }]), false);
});

test('吃到食物会增长并加分', () => {
  const s = createInitialState();
  s.gameState = 'running';
  s.food = { x: 11, y: 10 };
  gameTick(s, () => 0.95);
  assert.equal(s.score, 1);
  assert.equal(s.snake.length, 4);
});

test('碰撞后游戏结束', () => {
  const s = createInitialState();
  s.gameState = 'running';
  s.snake = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }];
  s.direction = { x: -1, y: 0 };
  s.nextDirection = { x: -1, y: 0 };
  gameTick(s);
  assert.equal(s.gameState, 'over');
});
