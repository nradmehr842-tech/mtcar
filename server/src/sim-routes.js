import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired, subscriptionRequired } from './auth.js';
import {
  getSimStatus,
  refreshSimStatus,
  internetPackages,
  buySimProduct,
  purchaseHistory,
} from './sim-service.js';

export const simRouter = express.Router();
simRouter.use(authRequired, activeUserRequired, subscriptionRequired);

async function canAccessDevice(userId, deviceId) {
  const { rows } = await db.query(
    `SELECT d.id
     FROM user_devices d
     WHERE d.id=$1 AND (
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

  return Boolean(rows[0]);
}

simRouter.get('/devices/:id/sim/status', async (req, res, next) => {
  try {
    const deviceId = Number(req.params.id);
    if (!(await canAccessDevice(req.auth.sub, deviceId))) {
      return res.status(403).json({ error: 'device_access_denied' });
    }

    const status = await getSimStatus(deviceId);
    if (!status) return res.status(404).json({ error: 'device_not_found' });

    res.json(status);
  } catch (e) {
    next(e);
  }
});

simRouter.post('/devices/:id/sim/refresh', async (req, res, next) => {
  try {
    const deviceId = Number(req.params.id);
    if (!(await canAccessDevice(req.auth.sub, deviceId))) {
      return res.status(403).json({ error: 'device_access_denied' });
    }

    const status = await refreshSimStatus(deviceId);
    if (!status) return res.status(404).json({ error: 'device_not_found' });

    res.json(status);
  } catch (e) {
    next(e);
  }
});

simRouter.get('/devices/:id/sim/internet-packages', async (req, res, next) => {
  try {
    const deviceId = Number(req.params.id);
    if (!(await canAccessDevice(req.auth.sub, deviceId))) {
      return res.status(403).json({ error: 'device_access_denied' });
    }

    const result = await internetPackages(deviceId);
    if (!result) return res.status(404).json({ error: 'device_not_found' });

    res.json(result);
  } catch (e) {
    next(e);
  }
});

simRouter.post('/devices/:id/sim/topup', async (req, res, next) => {
  try {
    const deviceId = Number(req.params.id);
    if (!(await canAccessDevice(req.auth.sub, deviceId))) {
      return res.status(403).json({ error: 'device_access_denied' });
    }

    const amountRial = Number(req.body?.amountRial || 0);

    if (!Number.isInteger(amountRial) || amountRial < 10000) {
      return res.status(400).json({ error: 'invalid_amount' });
    }

    res.json(await buySimProduct({
      deviceId,
      userId: Number(req.auth.sub),
      type: 'airtime',
      amountRial,
    }));
  } catch (e) {
    next(e);
  }
});

simRouter.post('/devices/:id/sim/buy-package', async (req, res, next) => {
  try {
    const deviceId = Number(req.params.id);
    if (!(await canAccessDevice(req.auth.sub, deviceId))) {
      return res.status(403).json({ error: 'device_access_denied' });
    }

    const packageId = String(req.body?.packageId || '').trim();
    const packageName = String(req.body?.packageName || '').trim().slice(0, 180);

    if (!packageId) {
      return res.status(400).json({ error: 'package_id_required' });
    }

    res.json(await buySimProduct({
      deviceId,
      userId: Number(req.auth.sub),
      type: 'internet',
      packageId,
      packageName,
    }));
  } catch (e) {
    next(e);
  }
});

simRouter.get('/devices/:id/sim/purchases', async (req, res, next) => {
  try {
    const deviceId = Number(req.params.id);
    if (!(await canAccessDevice(req.auth.sub, deviceId))) {
      return res.status(403).json({ error: 'device_access_denied' });
    }

    res.json(await purchaseHistory(deviceId));
  } catch (e) {
    next(e);
  }
});
