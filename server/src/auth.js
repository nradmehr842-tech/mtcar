import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { db } from './db.js';

const jwtSecret = () => {
  if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET is not configured.');
  return process.env.JWT_SECRET;
};

export function normalizeUsername(value) {
  return String(value || '').trim().toLowerCase();
}

export function validUsername(value) {
  const username = normalizeUsername(value);
  return /^[\p{L}\p{N}._-]{3,40}$/u.test(username);
}

// Kept for tracker/SIM metadata and optional future profile fields.
// It is no longer used as the MTcar login identifier.
export function normalizePhone(value) {
  return String(value || '').replace(/[^\d+]/g, '').trim();
}

export function signToken(user) {
  return jwt.sign(
    {
      sub: String(user.id),
      username: user.username,
      role: user.role || 'user',
    },
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
