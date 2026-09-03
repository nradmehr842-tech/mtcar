import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired } from './auth.js';
import { traccar } from './traccar.js';

export const deviceOnboardingRouter = express.Router();

function normalizeImei(value) {
  return String(value || '').replace(/[^\dA-Za-z_-]/g, '').trim();
}

function normalizePhone(value) {
  return String(value || '').replace(/[^\d+]/g, '').trim();
}

deviceOnboardingRouter.post(
  '/devices',
  authRequired,
  activeUserRequired,
  async (req, res, next) => {
    try {
      const imei = normalizeImei(req.body?.imei);
      const trackerSimPhone = normalizePhone(req.body?.trackerSimPhone);
      const vehicleName = String(req.body?.vehicleName || 'خودروی من').trim().slice(0, 120);
      const vehicleType = ['car', 'motorcycle'].includes(req.body?.vehicleType)
        ? req.body.vehicleType
        : 'car';

      if (!imei || imei.length < 6 || imei.length > 64) {
        return res.status(400).json({ error: 'invalid_imei' });
      }

      const duplicate = await db.query(
        `SELECT id FROM user_devices WHERE imei=$1 LIMIT 1`,
        [imei]
      );
      if (duplicate.rowCount) {
        return res.status(409).json({ error: 'imei_already_registered' });
      }

      let modelId = Number(req.body?.deviceModelId);
      if (!Number.isInteger(modelId) || modelId <= 0) {
        const defaultModel = await db.query(
          `SELECT id FROM device_models
           WHERE brand='MTcar' AND model='MT120' AND is_active=TRUE
           LIMIT 1`
        );
        modelId = defaultModel.rows[0]?.id;
      }

      const model = await db.query(
        `SELECT id,brand,model,display_name,protocol,server_port,transport
         FROM device_models
         WHERE id=$1 AND is_active=TRUE
         LIMIT 1`,
        [modelId]
      );

      if (!model.rows[0]) {
        return res.status(400).json({ error: 'device_model_unavailable' });
      }

      // Traccar registration. If Traccar is temporarily unavailable,
      // do not leave a half-created MTcar device record.
      const traccarDevice = await traccar.createDevice({
        name: vehicleName,
        uniqueId: imei,
      });

      const { rows } = await db.query(
        `INSERT INTO user_devices(
           user_id,device_model_id,traccar_device_id,imei,
           tracker_sim_phone,tracker_sim_operator,
           vehicle_name,vehicle_type,vehicle_icon,is_active
         )
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,TRUE)
         RETURNING *`,
        [
          req.auth.sub,
          modelId,
          traccarDevice.id,
          imei,
          trackerSimPhone || null,
          req.body?.trackerSimOperator || null,
          vehicleName,
          vehicleType,
          vehicleType === 'motorcycle' ? 'motorcycle' : 'car',
        ]
      );

      res.status(201).json({
        device: rows[0],
        model: model.rows[0],
        traccar: {
          id: traccarDevice.id,
          uniqueId: traccarDevice.uniqueId,
        },
      });
    } catch (e) {
      next(e);
    }
  }
);
