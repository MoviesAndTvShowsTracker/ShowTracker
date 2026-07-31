import { useMemo } from 'react';
import { addDays, todayKey, formatDayLabel, formatDuration } from '../../../utils/statsFormat';

const DAYS = 30;
const TRACK_PX = 34;

/** Last 30 days of logging, as a single glanceable line. */
export default function RhythmStrip({ days }) {
  const cells = useMemo(() => {
    const byDate = new Map((days || []).map((d) => [d.date, d]));
    const end = todayKey();
    return Array.from({ length: DAYS }, (_, i) => {
      const key = addDays(end, -(DAYS - 1 - i));
      const entry = byDate.get(key);
      return {
        key,
        minutes: entry?.minutes || 0,
        count: entry ? (entry.episodes || 0) + (entry.films || 0) : 0,
      };
    });
  }, [days]);

  const max = Math.max(...cells.map((c) => c.minutes), 1);

  return (
    <div className="border-b border-border/60">
      <div className="flex items-end gap-[3px]" style={{ height: TRACK_PX }}>
        {cells.map((cell) => (
          <span
            key={cell.key}
            title={
              cell.count
                ? `${formatDayLabel(cell.key)}: ${cell.count} logged · ${formatDuration(cell.minutes)}`
                : `${formatDayLabel(cell.key)}: nothing logged`
            }
            className={`min-w-0 flex-1 rounded-[2px] ${cell.minutes ? 'bg-accent' : 'bg-border'}`}
            style={{
              height: cell.minutes ? Math.max(5, Math.round((cell.minutes / max) * TRACK_PX)) : 3,
            }}
          />
        ))}
      </div>
    </div>
  );
}
