export const REPEAT_RULES = ['once', 'daily', 'weekdays'];

export function validTime(v) {
  return /^([01]\d|2[0-3]):([0-5]\d)$/.test(v);
}

export function validRepeatRule(v) {
  return REPEAT_RULES.includes(v);
}

export function createAlarm({ time, repeatRule }) {
  if (!validTime(time)) throw new Error('invalid time');
  if (!validRepeatRule(repeatRule)) throw new Error('invalid repeatRule');
  const now = Date.now();
  return {
    id: globalThis.crypto?.randomUUID?.() ?? `alarm-${now}-${Math.random().toString(16).slice(2)}`,
    time,
    repeatRule,
    enabled: true,
    lastTriggeredDate: '',
    createdAt: now,
    updatedAt: now,
  };
}

export function shouldRunOnDate(repeatRule, day) {
  if (repeatRule === 'daily') return true;
  if (repeatRule === 'weekdays') return day >= 1 && day <= 5;
  return true;
}

export function toDateKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

export function shouldTrigger(alarm, now = new Date()) {
  if (!alarm.enabled) return false;
  const hhmm = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  if (alarm.time !== hhmm) return false;

  const today = toDateKey(now);
  if (alarm.lastTriggeredDate === today) return false;
  if (!shouldRunOnDate(alarm.repeatRule, now.getDay())) return false;
  return true;
}

export function applyTriggered(alarm, now = new Date()) {
  const today = toDateKey(now);
  if (alarm.repeatRule === 'once') return { ...alarm, enabled: false, lastTriggeredDate: today, updatedAt: Date.now() };
  return { ...alarm, lastTriggeredDate: today, updatedAt: Date.now() };
}
