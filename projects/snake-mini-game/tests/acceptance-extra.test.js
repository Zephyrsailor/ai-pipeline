import test from 'node:test';
import assert from 'node:assert/strict';
import { createInitialState, gameTick } from '../src/core.js';

test('AC-01: 运行状态下 gameTick 会推动蛇自动前进', () => {
  const s = createInitialState();
  s.gameState = 'running';
  s.food = { x: 0, y: 0 }; // 保证本 tick 不吃食物

  const headBefore = { ...s.snake[0] };
  const lenBefore = s.snake.length;
  const scoreBefore = s.score;

  gameTick(s);

  assert.equal(s.snake[0].x, headBefore.x + 1);
  assert.equal(s.snake[0].y, headBefore.y);
  assert.equal(s.snake.length, lenBefore);
  assert.equal(s.score, scoreBefore);
});

test('AC-05: 重新开始可重置关键状态（分数/状态/蛇长）', () => {
  const s = createInitialState();
  s.gameState = 'over';
  s.score = 7;
  s.snake = [{ x: 1, y: 1 }];

  const restarted = createInitialState();
  assert.equal(restarted.gameState, 'ready');
  assert.equal(restarted.score, 0);
  assert.equal(restarted.snake.length, 3);
  assert.deepEqual(restarted.direction, { x: 1, y: 0 });
});

test('AC-01 补充：非 running 状态下 tick 不应推进', () => {
  const s = createInitialState(); // ready
  const before = JSON.stringify(s);
  gameTick(s);
  assert.equal(JSON.stringify(s), before);
});
