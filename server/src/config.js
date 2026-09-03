import { db } from './db.js';

export async function getRemoteConfig({ publicOnly = false } = {}) {
  const { rows } = await db.query(
    `SELECT key,value,public,updated_at
     FROM remote_config
     ${publicOnly ? 'WHERE public=TRUE' : ''}
     ORDER BY key ASC`
  );
  return Object.fromEntries(
    rows.map(row => [
      row.key,
      {
        value: row.value,
        public: row.public,
        updatedAt: row.updated_at,
      },
    ])
  );
}

export async function getConfigValue(key, fallback = null) {
  const { rows } = await db.query(
    `SELECT value FROM remote_config WHERE key=$1 LIMIT 1`,
    [key]
  );
  return rows[0]?.value ?? fallback;
}

export async function setConfigValue({
  key,
  value,
  isPublic = false,
  adminUserId,
}) {
  const { rows } = await db.query(
    `INSERT INTO remote_config(key,value,public,updated_by,updated_at)
     VALUES($1,$2::jsonb,$3,$4,NOW())
     ON CONFLICT(key) DO UPDATE
     SET value=EXCLUDED.value,
         public=EXCLUDED.public,
         updated_by=EXCLUDED.updated_by,
         updated_at=NOW()
     RETURNING key,value,public,updated_at`,
    [key, JSON.stringify(value), Boolean(isPublic), adminUserId]
  );
  return rows[0];
}

export async function auditAdmin({
  adminUserId,
  action,
  targetType = null,
  targetId = null,
  details = {},
}) {
  await db.query(
    `INSERT INTO admin_audit_log(
       admin_user_id,action,target_type,target_id,details
     ) VALUES($1,$2,$3,$4,$5::jsonb)`,
    [
      adminUserId,
      action,
      targetType,
      targetId == null ? null : String(targetId),
      JSON.stringify(details),
    ]
  );
}
