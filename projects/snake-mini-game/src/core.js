export const GRID_SIZE = 20;
export const CELL_SIZE = 20;
export const SPEED_MS = 150;

export function createInitialState() {
  return {
    snake: [
      { x: 10, y: 10 },
      { x: 9, y: 10 },
      { x: 8, y: 10 },
    ],
    direction: { x: 1, y: 0 },
    nextDirection: { x: 1, y: 0 },
    food: { x: 15, y: 10 },
    score: 0,
    gameState: 'ready',
  };
}

export function pointsEqual(a, b) {
  return a.x === b.x && a.y === b.y;
}

export function isReverseDirection(current, next) {
  return current.x + next.x === 0 && current.y + next.y === 0;
}

export function setNextDirection(state, dx, dy) {
  const next = { x: dx, y: dy };
  if (isReverseDirection(state.direction, next)) return state.nextDirection;
  state.nextDirection = next;
  return next;
}

export function spawnFood(snake, random = Math.random) {
  while (true) {
    const food = {
      x: Math.floor(random() * GRID_SIZE),
      y: Math.floor(random() * GRID_SIZE),
    };
    if (!snake.some((s) => pointsEqual(s, food))) return food;
  }
}

export function isCollision(point, snake) {
  const hitWall = point.x < 0 || point.x >= GRID_SIZE || point.y < 0 || point.y >= GRID_SIZE;
  if (hitWall) return true;
  return snake.some((p) => pointsEqual(p, point));
}

export function gameTick(state, random = Math.random) {
  if (state.gameState !== 'running') return state;

  state.direction = { ...state.nextDirection };
  const head = state.snake[0];
  const newHead = { x: head.x + state.direction.x, y: head.y + state.direction.y };

  const bodyWithoutTail = state.snake.slice(0, -1);
  if (isCollision(newHead, bodyWithoutTail)) {
    state.gameState = 'over';
    return state;
  }

  state.snake.unshift(newHead);

  if (pointsEqual(newHead, state.food)) {
    state.score += 1;
    state.food = spawnFood(state.snake, random);
  } else {
    state.snake.pop();
  }

  return state;
}
