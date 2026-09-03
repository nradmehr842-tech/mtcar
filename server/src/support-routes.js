import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired, adminRequired } from './auth.js';
import { auditAdmin } from './config.js';

export const supportRouter = express.Router();

supportRouter.post('/support/tickets', authRequired, activeUserRequired, async (req, res, next) => {
  try {
    const subject = String(req.body?.subject || '').trim().slice(0, 220);
    const message = String(req.body?.message || '').trim().slice(0, 5000);
    const category = String(req.body?.category || 'general').slice(0, 64);
    const priority = String(req.body?.priority || 'normal').slice(0, 24);
    const organizationId = req.body?.organizationId ? Number(req.body.organizationId) : null;

    if (!subject || !message) {
      return res.status(400).json({ error: 'subject_and_message_required' });
    }

    if (organizationId) {
      const allowed = await db.query(
        `SELECT 1 FROM organization_members
         WHERE organization_id=$1 AND user_id=$2 AND is_active=TRUE`,
        [organizationId, req.auth.sub]
      );
      if (!allowed.rowCount) {
        return res.status(403).json({ error: 'organization_access_denied' });
      }
    }

    const client = await db.connect();
    try {
      await client.query('BEGIN');

      const ticket = await client.query(
        `INSERT INTO support_tickets(
           user_id,organization_id,subject,category,priority,status
         )
         VALUES($1,$2,$3,$4,$5,'open')
         RETURNING *`,
        [
          req.auth.sub,
          organizationId,
          subject,
          category,
          priority,
        ]
      );

      await client.query(
        `INSERT INTO support_messages(
           ticket_id,sender_user_id,sender_role,message
         )
         VALUES($1,$2,'user',$3)`,
        [ticket.rows[0].id, req.auth.sub, message]
      );

      await client.query('COMMIT');
      res.status(201).json(ticket.rows[0]);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch (e) {
    next(e);
  }
});

supportRouter.get('/support/tickets', authRequired, activeUserRequired, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         t.id,t.subject,t.category,t.priority,t.status,
         t.organization_id,t.created_at,t.updated_at,
         (
           SELECT message FROM support_messages sm
           WHERE sm.ticket_id=t.id AND sm.is_internal=FALSE
           ORDER BY sm.created_at DESC LIMIT 1
         ) AS last_message
       FROM support_tickets t
       WHERE t.user_id=$1
       ORDER BY t.updated_at DESC`,
      [req.auth.sub]
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

supportRouter.get('/support/tickets/:id', authRequired, activeUserRequired, async (req, res, next) => {
  try {
    const ticketId = Number(req.params.id);

    const ticket = await db.query(
      `SELECT * FROM support_tickets
       WHERE id=$1 AND user_id=$2 LIMIT 1`,
      [ticketId, req.auth.sub]
    );

    if (!ticket.rows[0]) {
      return res.status(404).json({ error: 'ticket_not_found' });
    }

    const messages = await db.query(
      `SELECT id,sender_role,message,created_at
       FROM support_messages
       WHERE ticket_id=$1 AND is_internal=FALSE
       ORDER BY created_at`,
      [ticketId]
    );

    res.json({
      ticket: ticket.rows[0],
      messages: messages.rows,
    });
  } catch (e) {
    next(e);
  }
});

supportRouter.post('/support/tickets/:id/messages', authRequired, activeUserRequired, async (req, res, next) => {
  try {
    const ticketId = Number(req.params.id);
    const message = String(req.body?.message || '').trim().slice(0, 5000);

    if (!message) {
      return res.status(400).json({ error: 'message_required' });
    }

    const ticket = await db.query(
      `SELECT id,status FROM support_tickets
       WHERE id=$1 AND user_id=$2 LIMIT 1`,
      [ticketId, req.auth.sub]
    );

    if (!ticket.rows[0]) {
      return res.status(404).json({ error: 'ticket_not_found' });
    }

    const { rows } = await db.query(
      `INSERT INTO support_messages(
         ticket_id,sender_user_id,sender_role,message
       )
       VALUES($1,$2,'user',$3)
       RETURNING id,sender_role,message,created_at`,
      [ticketId, req.auth.sub, message]
    );

    await db.query(
      `UPDATE support_tickets
       SET status='open',updated_at=NOW()
       WHERE id=$1`,
      [ticketId]
    );

    res.status(201).json(rows[0]);
  } catch (e) {
    next(e);
  }
});

export const adminSupportRouter = express.Router();
adminSupportRouter.use(authRequired, adminRequired);

adminSupportRouter.get('/support/tickets', async (req, res, next) => {
  try {
    const status = String(req.query.status || '').trim();
    const params = [];
    let where = 'TRUE';

    if (status) {
      params.push(status);
      where += ` AND t.status=$${params.length}`;
    }

    const { rows } = await db.query(
      `SELECT
         t.id,t.subject,t.category,t.priority,t.status,
         t.organization_id,t.created_at,t.updated_at,
         u.phone AS user_phone,
         o.name AS organization_name,
         a.phone AS assigned_admin_phone
       FROM support_tickets t
       JOIN users u ON u.id=t.user_id
       LEFT JOIN organizations o ON o.id=t.organization_id
       LEFT JOIN users a ON a.id=t.assigned_admin_id
       WHERE ${where}
       ORDER BY
         CASE t.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END,
         t.updated_at DESC
       LIMIT 500`,
      params
    );

    res.json(rows);
  } catch (e) {
    next(e);
  }
});

adminSupportRouter.get('/support/tickets/:id', async (req, res, next) => {
  try {
    const ticketId = Number(req.params.id);

    const ticket = await db.query(
      `SELECT
         t.*,u.phone AS user_phone,o.name AS organization_name
       FROM support_tickets t
       JOIN users u ON u.id=t.user_id
       LEFT JOIN organizations o ON o.id=t.organization_id
       WHERE t.id=$1`,
      [ticketId]
    );

    if (!ticket.rows[0]) {
      return res.status(404).json({ error: 'ticket_not_found' });
    }

    const messages = await db.query(
      `SELECT
         sm.id,sm.sender_role,sm.message,sm.is_internal,
         sm.created_at,u.phone AS sender_phone
       FROM support_messages sm
       LEFT JOIN users u ON u.id=sm.sender_user_id
       WHERE sm.ticket_id=$1
       ORDER BY sm.created_at`,
      [ticketId]
    );

    res.json({
      ticket: ticket.rows[0],
      messages: messages.rows,
    });
  } catch (e) {
    next(e);
  }
});

adminSupportRouter.post('/support/tickets/:id/reply', async (req, res, next) => {
  try {
    const ticketId = Number(req.params.id);
    const message = String(req.body?.message || '').trim().slice(0, 5000);
    const internal = Boolean(req.body?.internal);

    if (!message) {
      return res.status(400).json({ error: 'message_required' });
    }

    const ticket = await db.query(
      `SELECT id FROM support_tickets WHERE id=$1`,
      [ticketId]
    );
    if (!ticket.rowCount) {
      return res.status(404).json({ error: 'ticket_not_found' });
    }

    const { rows } = await db.query(
      `INSERT INTO support_messages(
         ticket_id,sender_user_id,sender_role,message,is_internal
       )
       VALUES($1,$2,'admin',$3,$4)
       RETURNING id,sender_role,message,is_internal,created_at`,
      [ticketId, req.auth.sub, message, internal]
    );

    await db.query(
      `UPDATE support_tickets
       SET status=$1,assigned_admin_id=$2,updated_at=NOW()
       WHERE id=$3`,
      [internal ? 'pending' : 'answered', req.auth.sub, ticketId]
    );

    await auditAdmin({
      adminUserId: req.auth.sub,
      action: 'support.replied',
      targetType: 'support_ticket',
      targetId: ticketId,
      details: { internal },
    });

    res.status(201).json(rows[0]);
  } catch (e) {
    next(e);
  }
});

adminSupportRouter.patch('/support/tickets/:id/status', async (req, res, next) => {
  try {
    const ticketId = Number(req.params.id);
    const status = String(req.body?.status || '');

    if (!['open','pending','answered','closed'].includes(status)) {
      return res.status(400).json({ error: 'invalid_status' });
    }

    const { rows } = await db.query(
      `UPDATE support_tickets
       SET status=$1,
           assigned_admin_id=COALESCE(assigned_admin_id,$2),
           updated_at=NOW(),
           closed_at=CASE WHEN $1='closed' THEN NOW() ELSE NULL END
       WHERE id=$3
       RETURNING id,status,updated_at,closed_at`,
      [status, req.auth.sub, ticketId]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'ticket_not_found' });
    }

    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});
