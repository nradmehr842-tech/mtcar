import { db } from './db.js';
import { traccar } from './traccar.js';
import { startFreeTrialForDevice } from './free-trial.js';

function timeOf(position) {
  const raw =
    position?.serverTime ||
    position?.deviceTime ||
    position?.fixTime ||
    null;

  if (!raw) return 0;
  const ms = new Date(raw).getTime();
  return Number.isFinite(ms) ? ms : 0;
}

export function startDeviceOnlineMonitor({
  intervalMs = 60_000,
  onlineWindowMs = 5 * 60_000,
} = {}) {
  let running = false;

  async function tick() {
    if (running) return;
    running = true;

    try {
      const positions = await traccar.positions();
      const recent = new Set(
        positions
          .filter(p => {
            const ts = timeOf(p);
            return ts > 0 && Date.now() - ts <= onlineWindowMs;
          })
          .map(p => Number(p.deviceId))
      );

      if (!recent.size) return;

      const { rows } = await db.query(
        `SELECT id,traccar_device_id
         FROM user_devices
         WHERE is_active=TRUE
           AND traccar_device_id IS NOT NULL`
      );

      for (const device of rows) {
        if (!recent.has(Number(device.traccar_device_id))) continue;

        await db.query(
          `UPDATE user_devices
           SET first_online_at=COALESCE(first_online_at,NOW()),
               last_online_at=NOW(),
               updated_at=NOW()
           WHERE id=$1`,
          [device.id]
        );

        await startFreeTrialForDevice(device.id);
      }
    } catch (e) {
      console.error('MTcar online monitor:', e.message);
    } finally {
      running = false;
    }
  }

  tick();
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();

  return () => clearInterval(timer);
}
