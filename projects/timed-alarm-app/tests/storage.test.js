import test from 'node:test';
import assert from 'node:assert/strict';
import { loadAlarms, saveAlarms } from '../src/storage.js';

function fakeStorage() {
  const map = new Map();
  return {
    getItem(k) { return map.has(k) ? map.get(k) : null; },
    setItem(k, v) { map.set(k, v); },
  };
}

test('storage save/load', () => {
  const s = fakeStorage();
  const alarms = [{ id: '1', time: '08:00', repeatRule: 'daily', enabled: true }];
  saveAlarms(alarms, s);
  const out = loadAlarms(s);
  assert.equal(out.length, 1);
  assert.equal(out[0].time, '08:00');
});
