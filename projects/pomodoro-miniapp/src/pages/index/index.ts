import { BREAK_SEC, FOCUS_SEC } from '../../core/timer-constants';
import type { Mode, Status } from '../../core/timer-types';

interface PageData {
  mode: Mode;
  status: Status;
  stageText: string;
  countdownText: string;
  focusTotalMin: number;
  focusPomodoroCount: number;
}

const MODE_LABEL: Record<Mode, string> = {
  focus: '专注中',
  break: '休息中',
};

Page({
  data: {
    mode: 'focus',
    status: 'idle',
    stageText: MODE_LABEL.focus,
    countdownText: formatPlaceholder(FOCUS_SEC),
    focusTotalMin: 0,
    focusPomodoroCount: 0,
  } as PageData,

  onLoad() {
    this.syncStageView();
  },

  syncStageView() {
    const { mode } = this.data;
    const placeholderSec = mode === 'focus' ? FOCUS_SEC : BREAK_SEC;

    this.setData({
      stageText: MODE_LABEL[mode],
      countdownText: formatPlaceholder(placeholderSec),
    });
  },
});

function formatPlaceholder(totalSec: number): string {
  const min = Math.floor(totalSec / 60)
    .toString()
    .padStart(2, '0');
  const sec = (totalSec % 60).toString().padStart(2, '0');
  return `${min}:${sec}`;
}
