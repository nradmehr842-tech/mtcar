import express from 'express';
import { db } from './db.js';
import { startFreeTrialForDevice } from './free-trial.js';

export const deviceOnlineRouter = express.Router();

/**
 * Internal event hook.
 * Expected to be called by the MTcar/Traccar integration after a device is
 * confirmed ONLINE, not merely registered.
 *
 * Header:
 *   x-mtcar-internal-token: <INTERNAL_EVENT_TOKEN>
 */
deviceOnlineRouter.post('/internal/device-online', async (req, res, next) => {
  try {
    const expected = process.env.INTERNAL_EVENT_TOKEN;
    const supplied = req.get('x-mtcar-internal-token');

    if (!expected || !supplied || supplied !== expected) {
      return res.status(403).json({ error: 'forbidden' });
    }

    const deviceId = Number(req.body?.deviceId);
    if (!Number.isInteger(deviceId) || deviceId <= 0) {
      return res.status(400).json({ error: 'invalid_device_id' });
    }

    // Record first/last online timestamps when columns exist.
    try {
      await db.query(
        `UPDATE user_devices
         SET last_online_at=NOW(),
             first_online_at=COALESCE(first_online_at,NOW()),
             updated_at=NOW()
         WHERE id=$1`,
        [deviceId]
      );
    } catch (_) {
      // Older DBs may not have these columns until migration below has run.
    }

    const trial = await startFreeTrialForDevice(deviceId);
    res.json({ ok: true, trial });
  } catch (e) {
    next(e);
  }
});
