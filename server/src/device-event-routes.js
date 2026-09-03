import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired } from './auth.js';

export const deviceEventRouter = express.Router();

async function userCanAccessDevice(userId, deviceId) {
  const { rows } = await db.query(
    `SELECT d.id
     FROM user_devices d
     WHERE d.id=$1 AND (
       d.user_id=$2 OR d.organization_id IN (
         SELECT organization_id
         FROM organization_members
         WHERE user_id=$2 AND is_active=TRUE
       )
     )
     LIMIT 1`,
    [deviceId, userId]
  );
  return Boolean(rows[0]);
}

deviceEventRouter.get(
  '/devices/:id/events',
  authRequired,
  activeUserRequired,
  async (req, res, next) => {
    try {
      const deviceId = Number(req.params.id);
      const limit = Math.max(1, Math.min(100, Number(req.query.limit || 50)));
      if (!Number.isInteger(deviceId) || deviceId <= 0) {
        return res.status(400).json({ error: 'invalid_device_id' });
      }
      if (!(await userCanAccessDevice(req.auth.sub, deviceId))) {
        return res.status(404).json({ error: 'device_not_found' });
      }

      const { rows } = await db.query(
        `SELECT id,event_type,severity,title,message,source,event_time,attributes
         FROM device_events
         WHERE device_id=$1
         ORDER BY event_time DESC
         LIMIT $2`,
        [deviceId, limit]
      );
      res.json(rows);
    } catch (e) {
      next(e);
    }
  }
);

deviceEventRouter.post('/internal/device-event', async (req, res, next) => {
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

    const eventType = String(req.body?.eventType || 'generic').slice(0, 80);
    const severity = ['info','success','warning','critical'].includes(req.body?.severity)
      ? req.body.severity
      : 'info';
    const title = String(req.body?.title || eventType).slice(0, 180);
    const message = req.body?.message == null ? null : String(req.body.message).slice(0, 4000);
    const source = String(req.body?.source || 'integration').slice(0, 40);
    const eventTime = req.body?.eventTime ? new Date(req.body.eventTime) : new Date();
    const attributes = req.body?.attributes && typeof req.body.attributes === 'object'
      ? req.body.attributes
      : {};

    const { rows } = await db.query(
      `INSERT INTO device_events(
         device_id,event_type,severity,title,message,source,event_time,attributes
       ) VALUES($1,$2,$3,$4,$5,$6,$7,$8::jsonb)
       RETURNING *`,
      [
        deviceId,
        eventType,
        severity,
        title,
        message,
        source,
        Number.isNaN(eventTime.getTime()) ? new Date() : eventTime,
        JSON.stringify(attributes),
      ]
    );

    res.status(201).json(rows[0]);
  } catch (e) {
    next(e);
  }
});
