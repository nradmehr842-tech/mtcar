import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired } from './auth.js';
import { buildProvisioningPlan } from './device-provisioning.js';

export const deviceModelsRouter = express.Router();

/**
 * Active catalog for authenticated users.
 * The mobile/web apps fetch this list from the server, so models added by the
 * admin become visible without a new APK release.
 */
deviceModelsRouter.get(
  '/device-models',
  authRequired,
  activeUserRequired,
  async (_req, res, next) => {
    try {
      const { rows } = await db.query(
        `SELECT id,brand,model,display_name,thumbnail_asset,
                protocol,server_port,transport,capabilities,
                setup_profile,is_verified,notes
         FROM device_models
         WHERE is_active=TRUE
         ORDER BY brand,display_name`
      );
      res.json(rows);
    } catch (e) {
      next(e);
    }
  }
);

deviceModelsRouter.patch(
  '/devices/:id/model',
  authRequired,
  activeUserRequired,
  async (req, res, next) => {
    try {
      const deviceId = Number(req.params.id);
      const modelId = Number(req.body?.deviceModelId);

      if (!Number.isInteger(modelId) || modelId <= 0) {
        return res.status(400).json({ error: 'invalid_device_model' });
      }

      const access = await db.query(
        `SELECT d.id
         FROM user_devices d
         WHERE d.id=$1 AND (
           d.user_id=$2 OR
           d.organization_id IN (
             SELECT organization_id
             FROM organization_members
             WHERE user_id=$2 AND is_active=TRUE
           )
         )`,
        [deviceId, req.auth.sub]
      );

      if (!access.rowCount) {
        return res.status(403).json({ error: 'device_access_denied' });
      }

      const model = await db.query(
        `SELECT id,brand,model,display_name,thumbnail_asset,
                protocol,server_port,transport,capabilities,
                setup_profile,is_verified,notes
         FROM device_models
         WHERE id=$1 AND is_active=TRUE`,
        [modelId]
      );

      if (!model.rows[0]) {
        return res.status(404).json({ error: 'device_model_not_found' });
      }

      await db.query(
        `UPDATE user_devices
         SET device_model_id=$1,
             protocol_override=NULL,
             server_port_override=NULL,
             updated_at=NOW()
         WHERE id=$2`,
        [modelId, deviceId]
      );

      res.json({
        deviceId,
        model: model.rows[0],
      });
    } catch (e) {
      next(e);
    }
  }
);

deviceModelsRouter.get(
  '/devices/:id/profile',
  authRequired,
  activeUserRequired,
  async (req, res, next) => {
    try {
      const deviceId = Number(req.params.id);

      const { rows } = await db.query(
        `SELECT
           d.id,d.imei,d.tracker_sim_phone,d.tracker_sim_operator,
           d.protocol_override,d.server_port_override,
           m.id AS model_id,m.brand,m.model,m.display_name,m.thumbnail_asset,
           COALESCE(d.protocol_override,m.protocol) AS protocol,
           COALESCE(d.server_port_override,m.server_port) AS server_port,
           m.transport,m.capabilities,m.command_profile,m.setup_profile,
           m.is_verified,m.notes
         FROM user_devices d
         LEFT JOIN device_models m ON m.id=d.device_model_id
         WHERE d.id=$1 AND (
           d.user_id=$2 OR
           d.organization_id IN (
             SELECT organization_id
             FROM organization_members
             WHERE user_id=$2 AND is_active=TRUE
           )
         )
         LIMIT 1`,
        [deviceId, req.auth.sub]
      );

      if (!rows[0]) {
        return res.status(404).json({ error: 'device_not_found' });
      }

      res.json(rows[0]);
    } catch (e) {
      next(e);
    }
  }
);

deviceModelsRouter.post(
  '/device-models/:id/provisioning-plan',
  authRequired,
  activeUserRequired,
  async (req, res, next) => {
    try {
      const modelId = Number(req.params.id);

      const { rows } = await db.query(
        `SELECT id,brand,model,display_name,protocol,server_port,transport,
                command_profile,setup_profile,is_verified
         FROM device_models
         WHERE id=$1 AND is_active=TRUE
         LIMIT 1`,
        [modelId]
      );

      const row = rows[0];
      if (!row) {
        return res.status(404).json({ error: 'device_model_not_found' });
      }

      const plan = buildProvisioningPlan(row, {
        trackerPassword: req.body?.trackerPassword,
        apn: req.body?.apn,
        gprsUser: req.body?.gprsUser,
        gprsPassword: req.body?.gprsPassword,
        serverHost: process.env.TRACKER_PUBLIC_HOST,
      });

      res.json({
        model: {
          id: row.id,
          brand: row.brand,
          model: row.model,
          displayName: row.display_name,
          protocol: row.protocol,
          serverPort: row.server_port,
          transport: row.transport,
          verified: row.is_verified,
        },
        plan,
      });
    } catch (e) {
      next(e);
    }
  }
);
