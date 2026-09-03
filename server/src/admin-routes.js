import express from 'express';
import { db } from './db.js';
import { authRequired, adminRequired } from './auth.js';
import {
  getRemoteConfig,
  setConfigValue,
  auditAdmin,
} from './config.js';


const ALLOWED_TRANSPORTS = new Set(['tcp', 'udp']);

function normalizeObject(value, field) {
  if (value === undefined || value === null || value === '') return {};
  if (typeof value === 'object' && !Array.isArray(value)) return value;
  throw Object.assign(new Error(`invalid_${field}`), { statusCode: 400 });
}

function normalizeDeviceModelInput(body, { partial = false } = {}) {
  const out = {};

  const textFields = [
    ['brand', 80],
    ['model', 120],
    ['displayName', 180],
    ['thumbnailAsset', 500],
    ['protocol', 80],
    ['notes', 4000],
  ];

  for (const [key, max] of textFields) {
    if (body?.[key] !== undefined) {
      const value = String(body[key] ?? '').trim();
      out[key] = value ? value.slice(0, max) : null;
    } else if (!partial && ['brand', 'model', 'displayName', 'protocol'].includes(key)) {
      throw Object.assign(new Error(`missing_${key}`), { statusCode: 400 });
    }
  }

  if (body?.serverPort !== undefined || !partial) {
    const port = Number(body?.serverPort);
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw Object.assign(new Error('invalid_server_port'), { statusCode: 400 });
    }
    out.serverPort = port;
  }

  if (body?.transport !== undefined || !partial) {
    const transport = String(body?.transport || 'tcp').toLowerCase();
    if (!ALLOWED_TRANSPORTS.has(transport)) {
      throw Object.assign(new Error('invalid_transport'), { statusCode: 400 });
    }
    out.transport = transport;
  }

  if (body?.capabilities !== undefined || !partial) {
    out.capabilities = normalizeObject(body?.capabilities, 'capabilities');
  }

  if (body?.commandProfile !== undefined || !partial) {
    out.commandProfile = normalizeObject(body?.commandProfile, 'command_profile');
  }

  if (body?.setupProfile !== undefined || !partial) {
    out.setupProfile = normalizeObject(body?.setupProfile, 'setup_profile');
  }

  if (body?.isActive !== undefined) out.isActive = Boolean(body.isActive);
  if (body?.isVerified !== undefined) out.isVerified = Boolean(body.isVerified);

  return out;
}

export const adminRouter = express.Router();
adminRouter.use(authRequired, adminRequired);

adminRouter.get('/overview', async (req, res, next) => {
  try {
    const [users, activeSubs, devices, organizations, openTickets, paid, expiring] = await Promise.all([
      db.query(`SELECT COUNT(*)::int AS count FROM users WHERE role='user'`),
      db.query(`
        SELECT COUNT(DISTINCT user_id)::int AS count
        FROM subscriptions
        WHERE status='active' AND ends_at > NOW()
      `),
      db.query(`SELECT COUNT(*)::int AS count FROM user_devices WHERE is_active=TRUE`),
      db.query(`SELECT COUNT(*)::int AS count FROM organizations WHERE status='active'`),
      db.query(`SELECT COUNT(*)::int AS count FROM support_tickets WHERE status IN ('open','pending')`),
      db.query(`
        SELECT COALESCE(SUM(amount_toman),0)::bigint AS total
        FROM membership_payments WHERE status='paid'
      `),
      db.query(`
        SELECT COUNT(DISTINCT user_id)::int AS count
        FROM subscriptions
        WHERE status='active'
          AND ends_at > NOW()
          AND ends_at <= NOW() + INTERVAL '30 days'
      `),
    ]);

    res.json({
      users: users.rows[0].count,
      activeSubscriptions: activeSubs.rows[0].count,
      devices: devices.rows[0].count,
      organizations: organizations.rows[0].count,
      openSupportTickets: openTickets.rows[0].count,
      totalPaidToman: Number(paid.rows[0].total || 0),
      expiringWithin30Days: expiring.rows[0].count,
    });
  } catch (e) {
    next(e);
  }
});

adminRouter.get('/users', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    const limit = Math.min(200, Math.max(1, Number(req.query.limit || 50)));
    const offset = Math.max(0, Number(req.query.offset || 0));

    const params = [];
    let where = `u.role='user'`;

    if (q) {
      params.push(`%${q}%`);
      where += ` AND (
        u.phone ILIKE $${params.length}
        OR EXISTS (
          SELECT 1 FROM user_devices d
          WHERE d.user_id=u.id AND (
            d.imei ILIKE $${params.length}
            OR COALESCE(d.tracker_sim_phone,'') ILIKE $${params.length}
            OR COALESCE(d.vehicle_name,'') ILIKE $${params.length}
          )
        )
      )`;
    }

    params.push(limit);
    const limitIndex = params.length;
    params.push(offset);
    const offsetIndex = params.length;

    const { rows } = await db.query(
      `
      SELECT
        u.id,
        u.phone AS login_phone,
        u.status,
        u.phone_verified,
        u.created_at,
        sub.ends_at AS subscription_ends_at,
        CASE
          WHEN sub.ends_at IS NULL THEN NULL
          ELSE GREATEST(0, CEIL(EXTRACT(EPOCH FROM (sub.ends_at - NOW())) / 86400.0))::int
        END AS days_remaining,
        pay.amount_toman AS last_paid_amount_toman,
        pay.paid_at AS last_paid_at,
        COALESCE(
          jsonb_agg(
            DISTINCT jsonb_build_object(
              'id', d.id,
              'imei', d.imei,
              'trackerSimPhone', d.tracker_sim_phone,
              'vehicleName', d.vehicle_name,
              'vehicleType', d.vehicle_type,
              'vehicleIcon', d.vehicle_icon,
              'active', d.is_active
            )
          ) FILTER (WHERE d.id IS NOT NULL),
          '[]'::jsonb
        ) AS devices
      FROM users u
      LEFT JOIN LATERAL (
        SELECT ends_at
        FROM subscriptions
        WHERE user_id=u.id AND status='active'
        ORDER BY ends_at DESC LIMIT 1
      ) sub ON TRUE
      LEFT JOIN LATERAL (
        SELECT amount_toman,paid_at
        FROM membership_payments
        WHERE user_id=u.id AND status='paid'
        ORDER BY paid_at DESC NULLS LAST, id DESC LIMIT 1
      ) pay ON TRUE
      LEFT JOIN user_devices d ON d.user_id=u.id
      WHERE ${where}
      GROUP BY
        u.id,u.phone,u.status,u.phone_verified,u.created_at,
        sub.ends_at,pay.amount_toman,pay.paid_at
      ORDER BY u.created_at DESC
      LIMIT $${limitIndex} OFFSET $${offsetIndex}
      `,
      params
    );

    res.json(rows);
  } catch (e) {
    next(e);
  }
});

adminRouter.get('/users/:id', async (req, res, next) => {
  try {
    const userId = Number(req.params.id);

    const [user, devices, subs, payments] = await Promise.all([
      db.query(
        `SELECT id,phone,status,phone_verified,created_at,updated_at
         FROM users WHERE id=$1 AND role='user'`,
        [userId]
      ),
      db.query(
        `SELECT id,traccar_device_id,imei,tracker_sim_phone,
                vehicle_name,vehicle_type,vehicle_icon,is_active,
                created_at,updated_at
         FROM user_devices WHERE user_id=$1 ORDER BY id`,
        [userId]
      ),
      db.query(
        `SELECT id,starts_at,ends_at,status,note,created_at
         FROM subscriptions WHERE user_id=$1
         ORDER BY ends_at DESC LIMIT 50`,
        [userId]
      ),
      db.query(
        `SELECT id,amount_toman,provider,status,provider_reference,
                created_at,paid_at
         FROM membership_payments WHERE user_id=$1
         ORDER BY created_at DESC LIMIT 100`,
        [userId]
      ),
    ]);

    if (!user.rows[0]) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    res.json({
      user: user.rows[0],
      devices: devices.rows,
      subscriptions: subs.rows,
      payments: payments.rows,
    });
  } catch (e) {
    next(e);
  }
});

adminRouter.patch('/users/:id/status', async (req, res, next) => {
  try {
    const userId = Number(req.params.id);
    const status = String(req.body?.status || '');

    if (!['active', 'suspended'].includes(status)) {
      return res.status(400).json({ error: 'invalid_status' });
    }

    const { rows } = await db.query(
      `UPDATE users SET status=$1,updated_at=NOW()
       WHERE id=$2 AND role='user'
       RETURNING id,phone,status`,
      [status, userId]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: 'user.status_changed',
      targetType: 'user',
      targetId: userId,
      details: { status },
    });

    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});

adminRouter.post('/users/:id/subscription/adjust', async (req, res, next) => {
  try {
    const userId = Number(req.params.id);
    const days = Number(req.body?.days || 0);
    const note = String(req.body?.note || '').slice(0, 500);

    if (!Number.isInteger(days) || days === 0 || Math.abs(days) > 3650) {
      return res.status(400).json({ error: 'invalid_days' });
    }

    const userExists = await db.query(
      `SELECT id FROM users WHERE id=$1 AND role='user'`,
      [userId]
    );
    if (!userExists.rowCount) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    const current = await db.query(
      `SELECT ends_at FROM subscriptions
       WHERE user_id=$1 AND status='active'
       ORDER BY ends_at DESC LIMIT 1`,
      [userId]
    );

    let start = new Date();
    let end = current.rows[0]?.ends_at
      ? new Date(current.rows[0].ends_at)
      : new Date();

    if (end < start) {
      end = new Date(start);
    }

    end = new Date(end.getTime() + days * 86400000);

    const { rows } = await db.query(
      `INSERT INTO subscriptions(user_id,starts_at,ends_at,status,note)
       VALUES($1,$2,$3,'active',$4)
       RETURNING id,starts_at,ends_at,status,note`,
      [userId, start, end, note || `Admin adjustment: ${days} days`]
    );

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: 'subscription.adjusted',
      targetType: 'user',
      targetId: userId,
      details: { days, note, endsAt: end },
    });

    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});

adminRouter.get('/payments', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         p.id,p.amount_toman,p.provider,p.status,
         p.provider_reference,p.created_at,p.paid_at,
         u.id AS user_id,u.phone AS login_phone
       FROM membership_payments p
       JOIN users u ON u.id=p.user_id
       ORDER BY p.created_at DESC
       LIMIT 500`
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

adminRouter.get('/devices', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         d.id,d.imei,d.tracker_sim_phone,d.vehicle_name,
         d.vehicle_type,d.vehicle_icon,d.is_active,d.traccar_device_id,
         u.id AS user_id,u.phone AS login_phone
       FROM user_devices d
       JOIN users u ON u.id=d.user_id
       ORDER BY d.created_at DESC
       LIMIT 500`
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

adminRouter.get('/config', async (_req, res, next) => {
  try {
    res.json(await getRemoteConfig());
  } catch (e) {
    next(e);
  }
});

adminRouter.put('/config/:key', async (req, res, next) => {
  try {
    const key = String(req.params.key || '').trim();
    if (!key || key.length > 120) {
      return res.status(400).json({ error: 'invalid_key' });
    }

    const row = await setConfigValue({
      key,
      value: req.body?.value,
      isPublic: Boolean(req.body?.public),
      adminUserId: req.auth.sub,
    });

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: 'config.updated',
      targetType: 'config',
      targetId: key,
      details: {
        value: req.body?.value,
        public: Boolean(req.body?.public),
      },
    });

    res.json(row);
  } catch (e) {
    next(e);
  }
});

adminRouter.get('/audit', async (_req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT id,admin_user_id,action,target_type,target_id,details,created_at
       FROM admin_audit_log
       ORDER BY created_at DESC
       LIMIT 500`
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});


adminRouter.get('/organizations', async (_req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         o.id,o.name,o.legal_name,o.phone,o.status,o.created_at,
         COUNT(DISTINCT d.id)::int AS vehicles,
         COUNT(DISTINCT om.user_id)::int AS members,
         sub.ends_at AS subscription_ends_at,
         CASE
           WHEN sub.ends_at IS NULL THEN NULL
           ELSE GREATEST(0, CEIL(EXTRACT(EPOCH FROM (sub.ends_at - NOW())) / 86400.0))::int
         END AS days_remaining
       FROM organizations o
       LEFT JOIN user_devices d ON d.organization_id=o.id
       LEFT JOIN organization_members om ON om.organization_id=o.id AND om.is_active=TRUE
       LEFT JOIN LATERAL (
         SELECT ends_at
         FROM subscriptions
         WHERE organization_id=o.id AND status='active'
         ORDER BY ends_at DESC LIMIT 1
       ) sub ON TRUE
       GROUP BY o.id,sub.ends_at
       ORDER BY o.created_at DESC
       LIMIT 500`
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});


// -------------------------------------------------------------------
// Device Model Catalog
// -------------------------------------------------------------------

adminRouter.get('/device-models', async (_req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT id,brand,model,display_name,thumbnail_asset,
              protocol,server_port,transport,capabilities,
              command_profile,setup_profile,is_active,is_verified,
              notes,created_at,updated_at
       FROM device_models
       ORDER BY is_active DESC,brand,display_name`
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

adminRouter.post('/device-models', async (req, res, next) => {
  try {
    const input = normalizeDeviceModelInput(req.body);

    const { rows } = await db.query(
      `INSERT INTO device_models(
         brand,model,display_name,thumbnail_asset,
         protocol,server_port,transport,capabilities,
         command_profile,setup_profile,is_active,is_verified,notes
       )
       VALUES(
         $1,$2,$3,$4,$5,$6,$7,
         $8::jsonb,$9::jsonb,$10::jsonb,$11,$12,$13
       )
       RETURNING *`,
      [
        input.brand,
        input.model,
        input.displayName,
        input.thumbnailAsset,
        input.protocol,
        input.serverPort,
        input.transport,
        JSON.stringify(input.capabilities),
        JSON.stringify(input.commandProfile),
        JSON.stringify(input.setupProfile),
        input.isActive ?? true,
        input.isVerified ?? true,
        input.notes,
      ]
    );

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: 'device_model.created',
      targetType: 'device_model',
      targetId: rows[0].id,
      details: {
        brand: rows[0].brand,
        model: rows[0].model,
        protocol: rows[0].protocol,
        port: rows[0].server_port,
      },
    });

    res.status(201).json(rows[0]);
  } catch (e) {
    if (e?.code === '23505') {
      return res.status(409).json({ error: 'device_model_already_exists' });
    }
    if (e?.statusCode === 400) {
      return res.status(400).json({ error: e.message });
    }
    next(e);
  }
});

adminRouter.patch('/device-models/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'invalid_device_model_id' });
    }

    const input = normalizeDeviceModelInput(req.body, { partial: true });

    const current = await db.query(
      `SELECT * FROM device_models WHERE id=$1`,
      [id]
    );

    if (!current.rows[0]) {
      return res.status(404).json({ error: 'device_model_not_found' });
    }

    const old = current.rows[0];

    const nextRow = {
      brand: input.brand ?? old.brand,
      model: input.model ?? old.model,
      displayName: input.displayName ?? old.display_name,
      thumbnailAsset:
        input.thumbnailAsset !== undefined ? input.thumbnailAsset : old.thumbnail_asset,
      protocol: input.protocol ?? old.protocol,
      serverPort: input.serverPort ?? old.server_port,
      transport: input.transport ?? old.transport,
      capabilities: input.capabilities ?? old.capabilities,
      commandProfile: input.commandProfile ?? old.command_profile,
      setupProfile: input.setupProfile ?? old.setup_profile,
      isActive: input.isActive ?? old.is_active,
      isVerified: input.isVerified ?? old.is_verified,
      notes: input.notes !== undefined ? input.notes : old.notes,
    };

    const { rows } = await db.query(
      `UPDATE device_models SET
         brand=$1,
         model=$2,
         display_name=$3,
         thumbnail_asset=$4,
         protocol=$5,
         server_port=$6,
         transport=$7,
         capabilities=$8::jsonb,
         command_profile=$9::jsonb,
         setup_profile=$10::jsonb,
         is_active=$11,
         is_verified=$12,
         notes=$13,
         updated_at=NOW()
       WHERE id=$14
       RETURNING *`,
      [
        nextRow.brand,
        nextRow.model,
        nextRow.displayName,
        nextRow.thumbnailAsset,
        nextRow.protocol,
        nextRow.serverPort,
        nextRow.transport,
        JSON.stringify(nextRow.capabilities || {}),
        JSON.stringify(nextRow.commandProfile || {}),
        JSON.stringify(nextRow.setupProfile || {}),
        nextRow.isActive,
        nextRow.isVerified,
        nextRow.notes,
        id,
      ]
    );

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: 'device_model.updated',
      targetType: 'device_model',
      targetId: id,
      details: {
        brand: rows[0].brand,
        model: rows[0].model,
        protocol: rows[0].protocol,
        port: rows[0].server_port,
        active: rows[0].is_active,
      },
    });

    res.json(rows[0]);
  } catch (e) {
    if (e?.code === '23505') {
      return res.status(409).json({ error: 'device_model_already_exists' });
    }
    if (e?.statusCode === 400) {
      return res.status(400).json({ error: e.message });
    }
    next(e);
  }
});

adminRouter.patch('/device-models/:id/status', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const isActive = Boolean(req.body?.isActive);

    const { rows } = await db.query(
      `UPDATE device_models
       SET is_active=$1,updated_at=NOW()
       WHERE id=$2
       RETURNING id,brand,model,display_name,is_active`,
      [isActive, id]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'device_model_not_found' });
    }

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: isActive ? 'device_model.enabled' : 'device_model.disabled',
      targetType: 'device_model',
      targetId: id,
      details: { isActive },
    });

    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});

adminRouter.delete('/device-models/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);

    const usage = await db.query(
      `SELECT COUNT(*)::int AS count
       FROM user_devices
       WHERE device_model_id=$1`,
      [id]
    );

    if (usage.rows[0].count > 0) {
      return res.status(409).json({
        error: 'device_model_in_use',
        message: 'Disable the model instead of deleting it because devices are using it.',
      });
    }

    const { rows } = await db.query(
      `DELETE FROM device_models
       WHERE id=$1
       RETURNING id,brand,model,display_name`,
      [id]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'device_model_not_found' });
    }

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: 'device_model.deleted',
      targetType: 'device_model',
      targetId: id,
      details: rows[0],
    });

    res.json({ ok: true, deleted: rows[0] });
  } catch (e) {
    next(e);
  }
});
