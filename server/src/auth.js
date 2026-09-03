import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { db } from './db.js';

const jwtSecret = () => {
  if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET is not configured.');
  return process.env.JWT_SECRET;
};

export function normalizePhone(value) {
  return String(value || '').replace(/[^\d+]/g, '').trim();
}

export function signToken(user) {
  return jwt.sign(
    { sub: String(user.id), phone: user.phone, role: user.role || 'user' },
    jwtSecret(),
    { expiresIn: process.env.JWT_EXPIRES_IN || '30d' }
  );
}

export async function hashPassword(password) {
  if (typeof password !== 'string' || password.length < 8) {
    throw new Error('Password must contain at least 8 characters.');
  }
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

export function authRequired(req, res, next) {
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: 'auth_required' });

  try {
    req.auth = jwt.verify(token, jwtSecret());
    next();
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }
}


export function adminRequired(req, res, next) {
  if (!req.auth || req.auth.role !== 'admin') {
    return res.status(403).json({ error: 'admin_required' });
  }
  next();
}

export async function activeUserRequired(req, res, next) {
  try {
    const { rows } = await db.query(
      `SELECT status FROM users WHERE id=$1`,
      [req.auth.sub]
    );
    if (!rows[0] || rows[0].status !== 'active') {
      return res.status(403).json({ error: 'account_suspended' });
    }
    next();
  } catch (e) {
    next(e);
  }
}

export async function subscriptionRequired(req, res, next) {
  try {
    const graceDays = Math.max(0, Number(process.env.SUBSCRIPTION_GRACE_DAYS || 0));
    const { rows } = await db.query(
      `SELECT ends_at,status FROM subscriptions
       WHERE user_id=$1 AND status='active'
       ORDER BY ends_at DESC LIMIT 1`,
      [req.auth.sub]
    );
    const row = rows[0];
    if (!row) {
      return res.status(402).json({ error: 'subscription_required' });
    }

    const graceMs = graceDays * 24 * 60 * 60 * 1000;
    if (new Date(row.ends_at).getTime() + graceMs <= Date.now()) {
      return res.status(402).json({
        error: 'subscription_expired',
        endsAt: row.ends_at,
        graceDays,
      });
    }

    req.subscription = row;
    next();
  } catch (e) {
    next(e);
  }
}

function hashOtp(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

export async function issueOtp({ userId = null, purpose, phone }) {
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const expiresAt = new Date(Date.now() + 5 * 60_000);

  const { rows } = await db.query(
    `INSERT INTO otp_challenges(user_id,purpose,target_phone,code_hash,expires_at)
     VALUES($1,$2,$3,$4,$5) RETURNING id`,
    [userId, purpose, phone, hashOtp(code), expiresAt]
  );

  await sendOtp(phone, code);

  return {
    challengeId: rows[0].id,
    expiresAt,
    ...(process.env.NODE_ENV !== 'production' ? { debugCode: code } : {}),
  };
}

export async function consumeOtp({ challengeId, purpose, phone, code }) {
  const { rows } = await db.query(
    `SELECT * FROM otp_challenges
     WHERE id=$1 AND purpose=$2 AND target_phone=$3
       AND consumed_at IS NULL AND expires_at > NOW()
     LIMIT 1`,
    [challengeId, purpose, phone]
  );

  const row = rows[0];
  if (!row || row.code_hash !== hashOtp(String(code))) return false;

  await db.query(`UPDATE otp_challenges SET consumed_at=NOW() WHERE id=$1`, [row.id]);
  return true;
}

async function sendOtp(phone, code) {
  const provider = (process.env.SMS_PROVIDER || 'disabled').toLowerCase();

  if (provider === 'disabled') {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('SMS OTP provider is not configured.');
    }
    console.log(`[DEV OTP] ${phone}: ${code}`);
    return;
  }

  const url = process.env.SMS_API_URL;
  const key = process.env.SMS_API_KEY;
  if (!url || !key) throw new Error('SMS provider credentials are incomplete.');

  // Generic adapter placeholder. Replace with the chosen provider's official contract.
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      to: phone,
      code,
      sender: process.env.SMS_SENDER || undefined,
    }),
  });

  if (!response.ok) {
    throw new Error(`SMS provider failed: ${response.status}`);
  }
}
