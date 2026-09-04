import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired } from './auth.js';

export const organizationRouter = express.Router();
organizationRouter.use(authRequired, activeUserRequired);

async function getMembership(userId, organizationId) {
  const { rows } = await db.query(
    `SELECT om.member_role,om.is_active,o.id,o.name,o.status
     FROM organization_members om
     JOIN organizations o ON o.id=om.organization_id
     WHERE om.user_id=$1 AND om.organization_id=$2
     LIMIT 1`,
    [userId, organizationId]
  );
  return rows[0] || null;
}

function allowRole(membership, roles) {
  return membership && membership.is_active && membership.status === 'active' &&
    roles.includes(membership.member_role);
}

organizationRouter.get('/organizations', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT o.id,o.name,o.legal_name,o.phone,o.status,
              om.member_role,om.is_active
       FROM organization_members om
       JOIN organizations o ON o.id=om.organization_id
       WHERE om.user_id=$1
       ORDER BY o.name`,
      [req.auth.sub]
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

organizationRouter.get('/organizations/:id/dashboard', async (req, res, next) => {
  try {
    const orgId = Number(req.params.id);
    const membership = await getMembership(req.auth.sub, orgId);

    if (!membership) {
      return res.status(403).json({ error: 'organization_access_denied' });
    }

    const [devices, members, latestSub, openTickets] = await Promise.all([
      db.query(
        `SELECT id,traccar_device_id,imei,tracker_sim_phone,
                vehicle_name,vehicle_type,vehicle_icon,is_active
         FROM user_devices
         WHERE organization_id=$1
         ORDER BY vehicle_name NULLS LAST,id`,
        [orgId]
      ),
      db.query(
        `SELECT COUNT(*)::int AS count
         FROM organization_members
         WHERE organization_id=$1 AND is_active=TRUE`,
        [orgId]
      ),
      db.query(
        `SELECT starts_at,ends_at,status
         FROM subscriptions
         WHERE organization_id=$1
         ORDER BY ends_at DESC LIMIT 1`,
        [orgId]
      ),
      db.query(
        `SELECT COUNT(*)::int AS count
         FROM support_tickets
         WHERE organization_id=$1 AND status IN ('open','pending')`,
        [orgId]
      ),
    ]);

    res.json({
      organization: {
        id: membership.id,
        name: membership.name,
        role: membership.member_role,
      },
      summary: {
        vehicles: devices.rows.length,
        members: members.rows[0].count,
        openSupportTickets: openTickets.rows[0].count,
      },
      subscription: latestSub.rows[0] || null,
      devices: devices.rows,
    });
  } catch (e) {
    next(e);
  }
});

organizationRouter.get('/organizations/:id/members', async (req, res, next) => {
  try {
    const orgId = Number(req.params.id);
    const membership = await getMembership(req.auth.sub, orgId);

    if (!allowRole(membership, ['owner','manager'])) {
      return res.status(403).json({ error: 'organization_manager_required' });
    }

    const { rows } = await db.query(
      `SELECT
         om.id,om.member_role,om.is_active,om.created_at,
         u.id AS user_id,u.phone,u.status
       FROM organization_members om
       JOIN users u ON u.id=om.user_id
       WHERE om.organization_id=$1
       ORDER BY om.created_at`,
      [orgId]
    );

    res.json(rows);
  } catch (e) {
    next(e);
  }
});

organizationRouter.post('/organizations/:id/members', async (req, res, next) => {
  try {
    const orgId = Number(req.params.id);
    const membership = await getMembership(req.auth.sub, orgId);

    if (!allowRole(membership, ['owner','manager'])) {
      return res.status(403).json({ error: 'organization_manager_required' });
    }

    const username = String(req.body?.username || '').trim().toLowerCase();
    const role = String(req.body?.role || 'viewer');

    if (!['manager','dispatcher','viewer'].includes(role)) {
      return res.status(400).json({ error: 'invalid_member_role' });
    }

    const userResult = await db.query(
      `SELECT id FROM users WHERE LOWER(username)=LOWER($1) AND status='active' LIMIT 1`,
      [username]
    );

    const user = userResult.rows[0];
    if (!user) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    const { rows } = await db.query(
      `INSERT INTO organization_members(
         organization_id,user_id,member_role,is_active
       )
       VALUES($1,$2,$3,TRUE)
       ON CONFLICT(organization_id,user_id)
       DO UPDATE SET member_role=EXCLUDED.member_role,is_active=TRUE
       RETURNING id,organization_id,user_id,member_role,is_active`,
      [orgId, user.id, role]
    );

    res.status(201).json(rows[0]);
  } catch (e) {
    next(e);
  }
});
