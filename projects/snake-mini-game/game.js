import {
  GRID_SIZE,
  CELL_SIZE,
  SPEED_MS,
  createInitialState,
  setNextDirection,
  spawnFood,
  gameTick,
} from './src/core.js';

const canvas = document.querySelector('#board');
const ctx = canvas.getContext('2d');
const scoreEl = document.querySelector('#score');
const statusEl = document.querySelector('#status');
const restartBtn = document.querySelector('#restart-btn');

let state = createInitialState();
let timer = null;

function initGame() {
  state = createInitialState();
  state.food = spawnFood(state.snake);
  state.gameState = 'running';
  startLoop();
  syncUI();
  render();
}

function startLoop() {
  stopLoop();
  timer = setInterval(() => {
    gameTick(state);
    if (state.gameState === 'over') stopLoop();
    syncUI();
    render();
  }, SPEED_MS);
}

function stopLoop() {
  if (timer) clearInterval(timer);
  timer = null;
}

function drawCell(x, y, color) {
  ctx.fillStyle = color;
  ctx.fillRect(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE);
  ctx.strokeStyle = '#1f2b50';
  ctx.strokeRect(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE);
}

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  for (let y = 0; y < GRID_SIZE; y++) {
    for (let x = 0; x < GRID_SIZE; x++) {
      drawCell(x, y, '#0a0f1e');
    }
  }

  drawCell(state.food.x, state.food.y, '#ff5d73');
  state.snake.forEach((s, i) => drawCell(s.x, s.y, i === 0 ? '#9ef01a' : '#70e000'));
}

function syncUI() {
  scoreEl.textContent = String(state.score);
  statusEl.textContent = state.gameState === 'running' ? 'Running' : state.gameState === 'over' ? 'Game Over' : 'Ready';
}

document.addEventListener('keydown', (e) => {
  if (e.code === 'Space') {
    if (state.gameState === 'ready' || state.gameState === 'over') initGame();
    return;
  }

  if (state.gameState !== 'running') return;

  if (e.key === 'ArrowUp') setNextDirection(state, 0, -1);
  if (e.key === 'ArrowDown') setNextDirection(state, 0, 1);
  if (e.key === 'ArrowLeft') setNextDirection(state, -1, 0);
  if (e.key === 'ArrowRight') setNextDirection(state, 1, 0);
});

restartBtn.addEventListener('click', initGame);

syncUI();
render();
