import { db } from './db.js';

/**
 * Starts the one-time free trial for the account that owns a device.
 *
 * Rules:
 * - Trial starts only after the device is confirmed online.
 * - Trial is granted once per account, not once per device.
 * - Default duration is one calendar month.
 * - Existing paid time is not overwritten.
 * - If a paid subscription already extends beyond the trial, it is preserved.
 */
export async function startFreeTrialForDevice(deviceId) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const deviceResult = await client.query(
      `SELECT d.id, d.user_id
       FROM user_devices d
       WHERE d.id=$1
       FOR UPDATE`,
      [deviceId]
    );

    const device = deviceResult.rows[0];
    if (!device?.user_id) {
      await client.query('COMMIT');
      return { started: false, reason: 'no_account_owner' };
    }

    const userResult = await client.query(
      `SELECT id,free_trial_started_at,free_trial_ends_at,free_trial_used
       FROM users
       WHERE id=$1
       FOR UPDATE`,
      [device.user_id]
    );

    const user = userResult.rows[0];
    if (!user) {
      await client.query('COMMIT');
      return { started: false, reason: 'user_not_found' };
    }

    if (user.free_trial_used) {
      await client.query('COMMIT');
      return {
        started: false,
        reason: 'already_used',
        startsAt: user.free_trial_started_at,
        endsAt: user.free_trial_ends_at,
      };
    }

    const nowResult = await client.query(
      `SELECT NOW() AS starts_at, NOW() + INTERVAL '1 month' AS ends_at`
    );
    const { starts_at, ends_at } = nowResult.rows[0];

    await client.query(
      `UPDATE users
       SET free_trial_started_at=$2,
           free_trial_ends_at=$3,
           free_trial_used=TRUE
       WHERE id=$1`,
      [user.id, starts_at, ends_at]
    );

    const currentSub = await client.query(
      `SELECT id,status,starts_at,ends_at
       FROM subscriptions
       WHERE user_id=$1
       ORDER BY ends_at DESC NULLS LAST
       LIMIT 1
       FOR UPDATE`,
      [user.id]
    );

    const sub = currentSub.rows[0];

    if (!sub) {
      await client.query(
        `INSERT INTO subscriptions(
           user_id,status,starts_at,ends_at,created_at,updated_at
         )
         VALUES($1,'active',$2,$3,NOW(),NOW())`,
        [user.id, starts_at, ends_at]
      );
    } else {
      // Never shorten existing paid or promotional time.
      await client.query(
        `UPDATE subscriptions
         SET status='active',
             starts_at=LEAST(COALESCE(starts_at,$2),$2),
             ends_at=GREATEST(COALESCE(ends_at,$3),$3),
             updated_at=NOW()
         WHERE id=$1`,
        [sub.id, starts_at, ends_at]
      );
    }

    const result = {
      started: true,
      userId: user.id,
      startsAt: starts_at,
      endsAt: ends_at,
    };

    await client.query('COMMIT');
    return result;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}
