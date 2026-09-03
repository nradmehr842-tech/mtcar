import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { traccar } from './traccar.js';
import { canStopEngine } from './security.js';
import { getMapProviderConfig } from './map-provider.js';
import { initDb, db } from './db.js';
import { seedMt120AndMigrateCatalog } from './seed-mt120.js';
import { accountRouter } from './account-routes.js';
import { adminRouter } from './admin-routes.js';
import { bootstrapRouter } from './bootstrap-routes.js';
import { organizationRouter } from './organization-routes.js';
import { supportRouter, adminSupportRouter } from './support-routes.js';
import { simRouter } from './sim-routes.js';
import { deviceModelsRouter } from './device-model-routes.js';
import { deviceOnboardingRouter } from './device-onboarding-routes.js';
import { deviceEventRouter } from './device-event-routes.js';
import { startDeviceOnlineMonitor } from './device-online-monitor.js';
import { preferencesRouter } from './preferences-routes.js';
import { deviceOnlineRouter } from './device-online-routes.js';
import { authRequired, subscriptionRequired } from './auth.js';

const app = express();
app.use(cors());
app.use(express.json());
app.use('/api', accountRouter);
app.use('/api', bootstrapRouter);
app.use('/api/admin', adminRouter);
app.use('/api', organizationRouter);
app.use('/api', supportRouter);
app.use('/api/admin', adminSupportRouter);
app.use('/api', simRouter);
app.use('/api', deviceModelsRouter);
app.use('/api', deviceOnboardingRouter);
app.use('/api', deviceEventRouter);
app.use('/api', preferencesRouter);
app.use(deviceOnlineRouter);


async function ownedDevice(userId, deviceId) {
  const { rows } = await db.query(
    `SELECT d.id,d.traccar_device_id
     FROM user_devices d
     WHERE d.id=$1 AND d.is_active=TRUE AND (
       d.user_id=$2 OR
       d.organization_id IN (
         SELECT organization_id
         FROM organization_members
         WHERE user_id=$2 AND is_active=TRUE
       )
     )
     LIMIT 1`,
    [deviceId, userId]
  );
  return rows[0] || null;
}


app.get('/health', (_req, res) => res.json({ ok: true, service: 'mtcar-production-v21' }));

app.get('/api/config/map', (_req, res) => res.json(getMapProviderConfig()));

app.get('/api/devices', authRequired, subscriptionRequired, async (req, res, next) => {
  try {
    const allowed = await db.query(
      `SELECT id,traccar_device_id
       FROM user_devices
       WHERE is_active=TRUE AND (
         user_id=$1 OR
         organization_id IN (
           SELECT organization_id
           FROM organization_members
           WHERE user_id=$1 AND is_active=TRUE
         )
       )`,
      [req.auth.sub]
    );

    const allowedByTraccar = new Map(
      allowed.rows
        .filter(x => x.traccar_device_id != null)
        .map(x => [Number(x.traccar_device_id), Number(x.id)])
    );

    const [devices, positions] = await Promise.all([
      traccar.devices(),
      traccar.positions(),
    ]);

    const byDevice = new Map(positions.map(p => [Number(p.deviceId), p]));

    res.json(
      devices
        .filter(d => allowedByTraccar.has(Number(d.id)))
        .map(d => ({
          ...d,
          mtcarDeviceId: allowedByTraccar.get(Number(d.id)),
          position: byDevice.get(Number(d.id)) || null,
        }))
    );
  } catch (e) {
    next(e);
  }
});

app.get('/api/devices/:id/position', authRequired, subscriptionRequired, async (req, res, next) => {
  try {
    const device = await ownedDevice(req.auth.sub, req.params.id);
    if (!device) return res.status(404).json({ error: 'device_not_found' });
    res.json(await traccar.position(device.traccar_device_id));
  } catch (e) {
    next(e);
  }
});

app.get('/api/devices/:id/route', authRequired, subscriptionRequired, async (req, res, next) => {
  try {
    const device = await ownedDevice(req.auth.sub, req.params.id);
    if (!device) return res.status(404).json({ error: 'device_not_found' });

    const { from, to } = req.query;
    if (!from || !to) {
      return res.status(400).json({ error: 'from_and_to_required' });
    }

    res.json(
      await traccar.reportRoute(device.traccar_device_id, from, to)
    );
  } catch (e) {
    next(e);
  }
});

app.post('/api/devices/:id/engine-stop', authRequired, subscriptionRequired, async (req, res, next) => {
  try {
    const device = await ownedDevice(req.auth.sub, req.params.id);
    if (!device) return res.status(404).json({ error: 'device_not_found' });

    const position = await traccar.position(device.traccar_device_id);
    const gate = canStopEngine(position);

    if (!gate.allowed) {
      return res.status(409).json({
        error: 'unsafe_speed',
        message: 'Engine stop blocked by server safety gate.',
        ...gate,
      });
    }

    const result = await traccar.sendCommand(
      device.traccar_device_id,
      'engineStop'
    );

    res.json({ ok: true, gate, result });
  } catch (e) {
    next(e);
  }
});

app.post('/api/devices/:id/engine-resume', authRequired, subscriptionRequired, async (req, res, next) => {
  try {
    const device = await ownedDevice(req.auth.sub, req.params.id);
    if (!device) return res.status(404).json({ error: 'device_not_found' });

    const result = await traccar.sendCommand(
      device.traccar_device_id,
      'engineResume'
    );

    res.json({ ok: true, result });
  } catch (e) {
    next(e);
  }
});


app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'server_error', message: err.message });
});

await initDb();
const defaultDeviceModel = await seedMt120AndMigrateCatalog();
console.log(`MTcar default device model ready: ${defaultDeviceModel.display_name}`);
startDeviceOnlineMonitor();

app.listen(Number(process.env.PORT || 8080), '0.0.0.0', () => {
  console.log(`MTcar API listening on :${process.env.PORT || 8080}`);
});
