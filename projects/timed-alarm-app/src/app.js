import { createAlarm, validTime, validRepeatRule, shouldTrigger, applyTriggered } from './core.js';
import { loadAlarms, saveAlarms } from './storage.js';

const form = document.querySelector('#alarm-form');
const timeInput = document.querySelector('#time');
const repeatInput = document.querySelector('#repeatRule');
const listEl = document.querySelector('#alarm-list');
const dialog = document.querySelector('#ring-dialog');
const ringText = document.querySelector('#ring-text');
const stopBtn = document.querySelector('#stop-ringing');

let alarms = loadAlarms();
let editingId = null;
let ringingAlarmId = null;
let audio = null;

function warmupAudio() {
  if (!audio) {
    audio = new Audio('data:audio/wav;base64,UklGRhQAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAZGF0YQAAAAA=');
    audio.loop = true;
  }
}

function persist() {
  saveAlarms(alarms);
}

function render() {
  listEl.innerHTML = '';
  for (const a of alarms) {
    const li = document.createElement('li');
    li.className = 'alarm-item';
    li.dataset.id = a.id;
    li.innerHTML = `
      <strong>${a.time} / ${a.repeatRule} / ${a.enabled ? '启用' : '停用'}</strong>
      <button data-action="toggle">${a.enabled ? '停用' : '启用'}</button>
      <button data-action="edit">编辑</button>
      <button data-action="delete">删除</button>
    `;
    listEl.appendChild(li);
  }
}

function resetForm() {
  editingId = null;
  form.reset();
}

form.addEventListener('submit', (e) => {
  e.preventDefault();
  const time = timeInput.value;
  const repeatRule = repeatInput.value;

  if (!validTime(time) || !validRepeatRule(repeatRule)) {
    alert('请输入有效时间与重复规则');
    return;
  }

  if (editingId) {
    alarms = alarms.map((a) =>
      a.id === editingId ? { ...a, time, repeatRule, updatedAt: Date.now() } : a,
    );
  } else {
    alarms = [...alarms, createAlarm({ time, repeatRule })];
  }

  persist();
  render();
  resetForm();
});

listEl.addEventListener('click', (e) => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const id = btn.closest('.alarm-item')?.dataset.id;
  if (!id) return;

  if (btn.dataset.action === 'delete') {
    alarms = alarms.filter((a) => a.id !== id);
  }

  if (btn.dataset.action === 'toggle') {
    alarms = alarms.map((a) =>
      a.id === id ? { ...a, enabled: !a.enabled, updatedAt: Date.now() } : a,
    );
  }

  if (btn.dataset.action === 'edit') {
    const target = alarms.find((a) => a.id === id);
    if (!target) return;
    editingId = id;
    timeInput.value = target.time;
    repeatInput.value = target.repeatRule;
    return;
  }

  persist();
  render();
});

function stopRinging() {
  ringingAlarmId = null;
  if (audio) {
    audio.pause();
    audio.currentTime = 0;
  }
  if (dialog.open) dialog.close();
}

stopBtn.addEventListener('click', stopRinging);

function triggerAlarm(alarm) {
  ringingAlarmId = alarm.id;
  ringText.textContent = `${alarm.time} (${alarm.repeatRule})`;
  if (!dialog.open) dialog.showModal();
  warmupAudio();
  audio.play().catch(() => {
    ringText.textContent += '（浏览器阻止了自动播放）';
  });
}

function tick(now = new Date()) {
  let changed = false;
  alarms = alarms.map((a) => {
    if (!shouldTrigger(a, now)) return a;
    triggerAlarm(a);
    changed = true;
    return applyTriggered(a, now);
  });
  if (changed) {
    persist();
    render();
  }
}

setInterval(() => tick(new Date()), 1000);

document.body.addEventListener('click', warmupAudio, { once: true });

render();

export const __test__ = { tick, stopRinging, getAlarms: () => alarms, setAlarms: (next) => (alarms = next), getRingingId: () => ringingAlarmId };
