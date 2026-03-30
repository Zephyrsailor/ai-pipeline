const KEY = 'timedAlarmApp.alarms';

export function loadAlarms(storage = globalThis.localStorage) {
  try {
    const parsed = JSON.parse(storage.getItem(KEY) || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function saveAlarms(alarms, storage = globalThis.localStorage) {
  storage.setItem(KEY, JSON.stringify(alarms));
}
