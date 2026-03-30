import test from 'node:test';
import assert from 'node:assert/strict';
import {
  validTime,
  createAlarm,
  shouldRunOnDate,
  shouldTrigger,
  applyTriggered,
} from '../src/core.js';

test('时间格式校验', () => {
  assert.equal(validTime('09:30'), true);
  assert.equal(validTime('24:00'), false);
});

test('创建闹钟', () => {
  const alarm = createAlarm({ time: '07:30', repeatRule: 'once' });
  assert.equal(alarm.enabled, true);
  assert.equal(alarm.time, '07:30');
});

test('工作日规则', () => {
  assert.equal(shouldRunOnDate('weekdays', 1), true);
  assert.equal(shouldRunOnDate('weekdays', 6), false);
});

test('触发与触发后状态更新', () => {
  const now = new Date('2026-03-30T07:30:00');
  const alarm = createAlarm({ time: '07:30', repeatRule: 'once' });
  assert.equal(shouldTrigger(alarm, now), true);
  const updated = applyTriggered(alarm, now);
  assert.equal(updated.enabled, false);
});
