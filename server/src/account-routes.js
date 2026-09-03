import express from 'express';
import { db } from './db.js';
import {
  authRequired,
  normalizePhone,
  signToken,
  hashPassword,
  verifyPassword,
  issueOtp,
  consumeOtp,
} from './auth.js';
import {
  annualPriceToman,
  createMembershipPayment,
  verifyMembershipPayment,
} from './membership-payment.js';

export const accountRouter = express.Router();

accountRouter.post('/auth/register', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const passwordHash = await hashPassword(req.body?.password || '');

    if (!phone) {
      return res.status(400).json({ error: 'phone_required' });
    }

    const existing = await db.query(`SELECT id FROM users WHERE phone=$1`, [phone]);
    if (existing.rowCount) {
      return res.status(409).json({ error: 'phone_exists' });
    }

    const { rows } = await db.query(
      `INSERT INTO users(phone,password_hash)
       VALUES($1,$2)
       RETURNING id,phone,phone_verified,created_at`,
      [phone, passwordHash]
    );

    const otp = await issueOtp({
      userId: rows[0].id,
      purpose: 'register',
      phone,
    });

    res.status(201).json({ user: rows[0], otp });
  } catch (e) {
    next(e);
  }
});

accountRouter.post('/auth/verify-phone', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const ok = await consumeOtp({
      challengeId: req.body?.challengeId,
      purpose: 'register',
      phone,
      code: req.body?.code,
    });

    if (!ok) {
      return res.status(400).json({ error: 'invalid_or_expired_otp' });
    }

    const { rows } = await db.query(
      `UPDATE users
       SET phone_verified=TRUE,updated_at=NOW()
       WHERE phone=$1
       RETURNING id,phone,phone_verified`,
      [phone]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    res.json({
      token: signToken(rows[0]),
      user: rows[0],
    });
  } catch (e) {
    next(e);
  }
});


accountRouter.post('/auth/forgot-password/request', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    if (!phone) return res.status(400).json({ error: 'phone_required' });

    const { rows } = await db.query(
      `SELECT id,status FROM users WHERE phone=$1 LIMIT 1`,
      [phone]
    );

    // Avoid leaking whether an account exists.
    if (!rows[0] || rows[0].status !== 'active') {
      return res.json({ accepted: true });
    }

    const otp = await issueOtp({
      userId: rows[0].id,
      purpose: 'forgot_password',
      phone,
    });

    res.json({ accepted: true, otp });
  } catch (e) {
    next(e);
  }
});

accountRouter.post('/auth/forgot-password/confirm', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const newPasswordHash = await hashPassword(req.body?.newPassword || '');

    const ok = await consumeOtp({
      challengeId: req.body?.challengeId,
      purpose: 'forgot_password',
      phone,
      code: req.body?.code,
    });

    if (!ok) {
      return res.status(400).json({ error: 'invalid_or_expired_otp' });
    }

    const { rows } = await db.query(
      `UPDATE users
       SET password_hash=$2,updated_at=NOW()
       WHERE phone=$1 AND status='active'
       RETURNING id,phone`,
      [phone, newPasswordHash]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'user_not_found' });
    }

    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

accountRouter.post('/auth/login', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const { rows } = await db.query(
      `SELECT * FROM users WHERE phone=$1 LIMIT 1`,
      [phone]
    );

    const user = rows[0];

    if (!user || !(await verifyPassword(req.body?.password || '', user.password_hash))) {
      return res.status(401).json({ error: 'invalid_credentials' });
    }

    if (!user.phone_verified) {
      return res.status(403).json({ error: 'phone_not_verified' });
    }
    if (user.status !== 'active') {
      return res.status(403).json({ error: 'account_suspended' });
    }

    res.json({
      token: signToken(user),
      user: {
        id: user.id,
        phone: user.phone,
        phoneVerified: user.phone_verified,
        role: user.role,
        status: user.status,
      },
    });
  } catch (e) {
    next(e);
  }
});

accountRouter.get('/account', authRequired, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT id,phone,phone_verified,created_at
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

accountRouter.post('/account/change-phone/request', authRequired, async (req, res, next) => {
  try {
    const newPhone = normalizePhone(req.body?.newPhone);
    const currentPassword = req.body?.currentPassword || '';

    const current = await db.query(
      `SELECT password_hash FROM users WHERE id=$1`,
      [req.auth.sub]
    );

    if (!current.rows[0] || !(await verifyPassword(
      currentPassword,
      current.rows[0].password_hash
    ))) {
      return res.status(400).json({ error: 'current_password_incorrect' });
    }

    if (!newPhone) {
      return res.status(400).json({ error: 'new_phone_required' });
    }

    const exists = await db.query(`SELECT id FROM users WHERE phone=$1`, [newPhone]);
    if (exists.rowCount) {
      return res.status(409).json({ error: 'phone_exists' });
    }

    const otp = await issueOtp({
      userId: Number(req.auth.sub),
      purpose: 'change_phone',
      phone: newPhone,
    });

    res.json({ newPhone, otp });
  } catch (e) {
    next(e);
  }
});

accountRouter.post('/account/change-phone/confirm', authRequired, async (req, res, next) => {
  try {
    const newPhone = normalizePhone(req.body?.newPhone);

    const ok = await consumeOtp({
      challengeId: req.body?.challengeId,
      purpose: 'change_phone',
      phone: newPhone,
      code: req.body?.code,
    });

    if (!ok) {
      return res.status(400).json({ error: 'invalid_or_expired_otp' });
    }

    const { rows } = await db.query(
      `UPDATE users
       SET phone=$1,phone_verified=TRUE,updated_at=NOW()
       WHERE id=$2
       RETURNING id,phone,phone_verified`,
      [newPhone, req.auth.sub]
    );

    res.json({
      token: signToken(rows[0]),
      user: rows[0],
    });
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
      `SELECT phone FROM users WHERE id=$1`,
      [req.auth.sub]
    );

    const phone = userResult.rows[0]?.phone;
    if (!phone) {
      return res.status(404).json({ error: 'user_not_found' });
    }

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
