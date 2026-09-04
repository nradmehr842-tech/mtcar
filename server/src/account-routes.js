import express from 'express';
import { db } from './db.js';
import {
  authRequired,
  normalizeUsername,
  validUsername,
  signToken,
  hashPassword,
  verifyPassword,
} from './auth.js';
import {
  annualPriceToman,
  createMembershipPayment,
  verifyMembershipPayment,
} from './membership-payment.js';

export const accountRouter = express.Router();

accountRouter.post('/auth/register', async (req, res, next) => {
  try {
    const username = normalizeUsername(req.body?.username);
    const password = String(req.body?.password || '');
    const confirmPassword = String(req.body?.confirmPassword || '');

    if (!validUsername(username)) {
      return res.status(400).json({ error: 'invalid_username' });
    }
    if (password !== confirmPassword) {
      return res.status(400).json({ error: 'password_confirmation_mismatch' });
    }

    const passwordHash = await hashPassword(password);

    const existing = await db.query(
      `SELECT id FROM users WHERE LOWER(username)=LOWER($1) LIMIT 1`,
      [username]
    );
    if (existing.rowCount) {
      return res.status(409).json({ error: 'username_exists' });
    }

    const { rows } = await db.query(
      `INSERT INTO users(username,password_hash,phone,phone_verified)
       VALUES($1,$2,NULL,FALSE)
       RETURNING id,username,role,status,created_at`,
      [username, passwordHash]
    );

    res.status(201).json({
      token: signToken(rows[0]),
      user: rows[0],
    });
  } catch (e) {
    next(e);
  }
});

accountRouter.post('/auth/login', async (req, res, next) => {
  try {
    const username = normalizeUsername(req.body?.username);
    const { rows } = await db.query(
      `SELECT * FROM users WHERE LOWER(username)=LOWER($1) LIMIT 1`,
      [username]
    );

    const user = rows[0];
    if (!user || !(await verifyPassword(req.body?.password || '', user.password_hash))) {
      return res.status(401).json({ error: 'invalid_credentials' });
    }
    if (user.status !== 'active') {
      return res.status(403).json({ error: 'account_suspended' });
    }

    res.json({
      token: signToken(user),
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        status: user.status,
      },
    });
  } catch (e) {
    next(e);
  }
});

// No SMS/e-mail recovery is enabled in v25. Password changes require an
// authenticated session and the current password.
accountRouter.post('/auth/forgot-password/request', (_req, res) => {
  res.status(501).json({
    error: 'password_recovery_disabled',
    message: 'Contact MTcar support for account recovery.',
  });
});

accountRouter.get('/account', authRequired, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT id,username,phone,created_at
       FROM users WHERE id=$1`,
      [req.auth.sub]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    const sub = await db.query(
      `SELECT starts_at,ends_at,status
       FROM subscriptions
       WHERE user_id=$1 AND status='active'
       ORDER BY ends_at DESC LIMIT 1`,
      [req.auth.sub]
    );

    res.json({
      user: rows[0],
      subscription: sub.rows[0] || null,
    });
  } catch (e) {
    next(e);
  }
});

accountRouter.post('/account/change-password', authRequired, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT password_hash FROM users WHERE id=$1`,
      [req.auth.sub]
    );

    if (!rows[0] || !(await verifyPassword(
      req.body?.currentPassword || '',
      rows[0].password_hash
    ))) {
      return res.status(400).json({ error: 'current_password_incorrect' });
    }

    const hash = await hashPassword(req.body?.newPassword || '');

    await db.query(
      `UPDATE users
       SET password_hash=$1,updated_at=NOW()
       WHERE id=$2`,
      [hash, req.auth.sub]
    );

    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

accountRouter.get('/subscription/plan', async (_req, res, next) => {
  try {
    res.json({
      code: 'annual',
      periodMonths: 12,
      priceToman: await annualPriceToman(),
      title: 'اشتراک سالانه MTcar',
    });
  } catch (e) {
    next(e);
  }
});

accountRouter.get('/subscription/status', authRequired, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT id,starts_at,ends_at,status
       FROM subscriptions
       WHERE user_id=$1
       ORDER BY ends_at DESC LIMIT 1`,
      [req.auth.sub]
    );

    const subscription = rows[0] || null;

    res.json({
      subscription,
      active: Boolean(
        subscription &&
        subscription.status === 'active' &&
        new Date(subscription.ends_at) > new Date()
      ),
      priceToman: await annualPriceToman(),
    });
  } catch (e) {
    next(e);
  }
});

accountRouter.get('/subscription/payments', authRequired, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT id,amount_toman,provider,status,provider_reference,created_at,paid_at
       FROM membership_payments
       WHERE user_id=$1
       ORDER BY created_at DESC
       LIMIT 100`,
      [req.auth.sub]
    );

    res.json(rows);
  } catch (e) {
    next(e);
  }
});

accountRouter.post('/subscription/checkout', authRequired, async (req, res, next) => {
  try {
    const amount = await annualPriceToman();

    const userResult = await db.query(
      `SELECT username,phone FROM users WHERE id=$1`,
      [req.auth.sub]
    );

    if (!userResult.rows[0]) {
      return res.status(404).json({ error: 'user_not_found' });
    }
    const phone = userResult.rows[0].phone || null;

    const provider = (process.env.PAYMENT_PROVIDER || 'disabled').toLowerCase();

    const inserted = await db.query(
      `INSERT INTO membership_payments(user_id,amount_toman,provider)
       VALUES($1,$2,$3)
       RETURNING id`,
      [req.auth.sub, amount, provider]
    );

    const paymentId = inserted.rows[0].id;

    const created = await createMembershipPayment({
      paymentId,
      amountToman: amount,
      phone,
    });

    await db.query(
      `UPDATE membership_payments
       SET authority=$1,raw_response=$2
       WHERE id=$3`,
      [
        created.authority || null,
        created.raw ? JSON.stringify(created.raw) : null,
        paymentId,
      ]
    );

    res.json({
      paymentId,
      amountToman: amount,
      configured: created.configured,
      paymentUrl: created.paymentUrl || null,
      message: created.message || null,
    });
  } catch (e) {
    next(e);
  }
});

accountRouter.get('/subscription/payment/callback', async (req, res, next) => {
  try {
    const authority = String(
      req.query.authority ||
      req.query.Authority ||
      ''
    );

    if (!authority) {
      return res.status(400).send('Missing authority');
    }

    const paymentResult = await db.query(
      `SELECT * FROM membership_payments
       WHERE authority=$1 AND status='pending'
       ORDER BY id DESC LIMIT 1`,
      [authority]
    );

    const payment = paymentResult.rows[0];

    if (!payment) {
      return res.status(404).send('Payment not found');
    }

    const verified = await verifyMembershipPayment({
      authority,
      amountToman: Number(payment.amount_toman),
    });

    if (!verified.ok) {
      await db.query(
        `UPDATE membership_payments
         SET status='failed',raw_response=$1
         WHERE id=$2`,
        [JSON.stringify(verified.raw || {}), payment.id]
      );
      return res.status(400).send('Payment verification failed');
    }

    const client = await db.connect();

    try {
      await client.query('BEGIN');

      await client.query(
        `UPDATE membership_payments
         SET status='paid',
             provider_reference=$1,
             paid_at=NOW(),
             raw_response=$2
         WHERE id=$3`,
        [
          verified.reference || null,
          JSON.stringify(verified.raw || {}),
          payment.id,
        ]
      );

      const current = await client.query(
        `SELECT ends_at FROM subscriptions
         WHERE user_id=$1 AND status='active'
         ORDER BY ends_at DESC LIMIT 1`,
        [payment.user_id]
      );

      const start = (
        current.rows[0] &&
        new Date(current.rows[0].ends_at) > new Date()
      )
        ? new Date(current.rows[0].ends_at)
        : new Date();

      const end = new Date(start);
      end.setFullYear(end.getFullYear() + 1);

      await client.query(
        `INSERT INTO subscriptions(
           user_id,starts_at,ends_at,status,payment_id
         )
         VALUES($1,$2,$3,'active',$4)`,
        [payment.user_id, start, end, payment.id]
      );

      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }

    res.send('Payment verified. You can return to the app.');
  } catch (e) {
    next(e);
  }
});
