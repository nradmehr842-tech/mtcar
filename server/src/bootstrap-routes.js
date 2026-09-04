import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired } from './auth.js';
import { getRemoteConfig } from './config.js';

export const bootstrapRouter = express.Router();

bootstrapRouter.get('/app/public-config', async (_req, res, next) => {
  try {
    const config = await getRemoteConfig({ publicOnly: true });
    res.set('Cache-Control', 'no-store');
    res.json({
      serverTime: new Date().toISOString(),
      config,
    });
  } catch (e) {
    next(e);
  }
});

bootstrapRouter.get('/app/bootstrap', authRequired, activeUserRequired, async (req, res, next) => {
  try {
    const [user, sub, devices, organizations, support, config] = await Promise.all([
      db.query(
        `SELECT id,username,phone,status,created_at,
                free_trial_started_at,free_trial_ends_at,free_trial_used
         FROM users WHERE id=$1`,
        [req.auth.sub]
      ),
      db.query(
        `SELECT id,starts_at,ends_at,status
         FROM subscriptions
         WHERE user_id=$1
         ORDER BY ends_at DESC LIMIT 1`,
        [req.auth.sub]
      ),
      db.query(
        `SELECT id,traccar_device_id,imei,tracker_sim_phone,
                vehicle_name,vehicle_type,vehicle_icon,is_active,
                organization_id
         FROM user_devices
         WHERE user_id=$1 OR organization_id IN (
           SELECT organization_id FROM organization_members
           WHERE user_id=$1 AND is_active=TRUE
         )
         ORDER BY id`,
        [req.auth.sub]
      ),
      db.query(
        `SELECT o.id,o.name,om.member_role
         FROM organization_members om
         JOIN organizations o ON o.id=om.organization_id
         WHERE om.user_id=$1 AND om.is_active=TRUE AND o.status='active'
         ORDER BY o.name`,
        [req.auth.sub]
      ),
      db.query(
        `SELECT COUNT(*)::int AS count
         FROM support_tickets
         WHERE user_id=$1 AND status IN ('open','pending','answered')`,
        [req.auth.sub]
      ),
      getRemoteConfig({ publicOnly: true }),
    ]);

    const userRow = user.rows[0] || {};
    const subscription = sub.rows[0] || null;
    const daysRemaining = subscription?.ends_at
      ? Math.max(0, Math.ceil(
          (new Date(subscription.ends_at).getTime() - Date.now()) / 86400000
        ))
      : 0;

    res.set('Cache-Control', 'no-store');
    res.json({
      serverTime: new Date().toISOString(),
      user: userRow,
      freeTrial: {
        used: Boolean(userRow.free_trial_used),
        startedAt: userRow.free_trial_started_at || null,
        endsAt: userRow.free_trial_ends_at || null,
        eligible: !userRow.free_trial_used,
      },
      subscription: {
        ...subscription,
        daysRemaining,
        active: Boolean(
          subscription &&
          subscription.status === 'active' &&
          new Date(subscription.ends_at) > new Date()
        ),
        expired: Boolean(
          !subscription ||
          subscription.status !== 'active' ||
          new Date(subscription.ends_at) <= new Date()
        ),
        renewalRequired: Boolean(
          !subscription ||
          subscription.status !== 'active' ||
          new Date(subscription.ends_at) <= new Date()
        ),
        renewalMessage: (
          !subscription ||
          subscription.status !== 'active' ||
          new Date(subscription.ends_at) <= new Date()
        )
          ? 'دوره اعتبار حساب شما به پایان رسیده است. برای شارژ به پنل حساب کاربری خود مراجعه کنید.'
          : null,
      },
      devices: devices.rows,
      organizations: organizations.rows,
      support: {
        activeTickets: support.rows[0].count,
      },
      config,
    });
  } catch (e) {
    next(e);
  }
});
