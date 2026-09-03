import { db } from './db.js';
import { operatorCodes, normalizeOperator } from './carrier-codes.js';

function publicStatus(row, device) {
  const operator = normalizeOperator(row?.operator || device?.tracker_sim_operator);

  return {
    deviceId: device?.id ?? row?.device_id ?? null,
    phone: device?.tracker_sim_phone ?? null,
    operator,
    operatorName: operatorCodes(operator)?.faName ?? device?.tracker_sim_operator ?? null,
    simType: device?.tracker_sim_type ?? null,
    simActive: row?.sim_active ?? null,

    airtime: {
      available: Boolean(row?.airtime_available),
      balanceRial: row?.airtime_balance_rial == null
        ? null
        : Number(row.airtime_balance_rial),
    },

    data: {
      available: Boolean(row?.data_available),
      remainingMb: row?.data_remaining_mb == null
        ? null
        : Number(row.data_remaining_mb),
      packageName: row?.data_package_name ?? null,
      expiresAt: row?.data_package_expires_at ?? null,
    },

    source: row?.source ?? 'unavailable',
    lastQueriedAt: row?.last_queried_at ?? null,
    lastError: row?.last_error ?? null,

    ussdFallback: operatorCodes(operator),
  };
}

async function device(deviceId) {
  const { rows } = await db.query(
    `SELECT id,user_id,organization_id,tracker_sim_phone,
            tracker_sim_operator,tracker_sim_type
     FROM user_devices
     WHERE id=$1 LIMIT 1`,
    [deviceId]
  );
  return rows[0] || null;
}

export async function getSimStatus(deviceId) {
  const d = await device(deviceId);
  if (!d) return null;

  const { rows } = await db.query(
    `SELECT * FROM device_sim_status
     WHERE device_id=$1 LIMIT 1`,
    [deviceId]
  );

  return publicStatus(rows[0], d);
}

export async function saveSimStatus({
  deviceId,
  operator = null,
  simActive = null,
  airtimeAvailable = false,
  airtimeBalanceRial = null,
  dataAvailable = false,
  dataRemainingMb = null,
  dataPackageName = null,
  dataPackageExpiresAt = null,
  source = 'provider_api',
  lastError = null,
  rawResponse = null,
}) {
  const { rows } = await db.query(
    `INSERT INTO device_sim_status(
       device_id,operator,sim_active,
       airtime_available,airtime_balance_rial,
       data_available,data_remaining_mb,data_package_name,data_package_expires_at,
       source,last_queried_at,last_error,raw_response,updated_at
     )
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW(),$11,$12::jsonb,NOW())
     ON CONFLICT(device_id) DO UPDATE SET
       operator=COALESCE(EXCLUDED.operator,device_sim_status.operator),
       sim_active=COALESCE(EXCLUDED.sim_active,device_sim_status.sim_active),
       airtime_available=EXCLUDED.airtime_available,
       airtime_balance_rial=EXCLUDED.airtime_balance_rial,
       data_available=EXCLUDED.data_available,
       data_remaining_mb=EXCLUDED.data_remaining_mb,
       data_package_name=EXCLUDED.data_package_name,
       data_package_expires_at=EXCLUDED.data_package_expires_at,
       source=EXCLUDED.source,
       last_queried_at=NOW(),
       last_error=EXCLUDED.last_error,
       raw_response=EXCLUDED.raw_response,
       updated_at=NOW()
     RETURNING *`,
    [
      deviceId,
      operator,
      simActive,
      airtimeAvailable,
      airtimeBalanceRial,
      dataAvailable,
      dataRemainingMb,
      dataPackageName,
      dataPackageExpiresAt,
      source,
      lastError,
      JSON.stringify(rawResponse || {}),
    ]
  );

  const d = await device(deviceId);
  return publicStatus(rows[0], d);
}

export async function refreshSimStatus(deviceId) {
  const d = await device(deviceId);
  if (!d) return null;

  const provider = (process.env.SIM_STATUS_PROVIDER || 'disabled').toLowerCase();

  if (provider === 'disabled') {
    // Never fabricate a balance/data value.
    const current = await getSimStatus(deviceId);
    return {
      ...current,
      refreshMode: 'provider_not_configured',
    };
  }

  const url = process.env.SIM_STATUS_API_URL;
  const key = process.env.SIM_STATUS_API_KEY;

  if (!url || !key) {
    throw new Error('SIM status provider credentials are incomplete.');
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      phone: d.tracker_sim_phone,
      operator: normalizeOperator(d.tracker_sim_operator),
    }),
  });

  const raw = await response.json().catch(() => ({}));

  if (!response.ok) {
    return saveSimStatus({
      deviceId,
      operator: d.tracker_sim_operator,
      source: 'operator_api',
      lastError: `provider_${response.status}`,
      rawResponse: raw,
    });
  }

  return saveSimStatus({
    deviceId,
    operator: raw.operator || d.tracker_sim_operator,
    simActive: raw.simActive ?? null,
    airtimeAvailable: raw.airtimeBalanceRial != null,
    airtimeBalanceRial: raw.airtimeBalanceRial ?? null,
    dataAvailable: raw.dataRemainingMb != null,
    dataRemainingMb: raw.dataRemainingMb ?? null,
    dataPackageName: raw.dataPackageName ?? null,
    dataPackageExpiresAt: raw.dataPackageExpiresAt ?? null,
    source: 'operator_api',
    rawResponse: raw,
  });
}

export async function internetPackages(deviceId) {
  const d = await device(deviceId);
  if (!d) return null;

  const provider = (process.env.SIM_TOPUP_PROVIDER || 'disabled').toLowerCase();

  if (provider === 'disabled') {
    return {
      configured: false,
      operator: normalizeOperator(d.tracker_sim_operator),
      packages: [],
      fallbackUssd: operatorCodes(d.tracker_sim_operator)?.dataPurchaseMenu ?? null,
    };
  }

  const url = process.env.SIM_PACKAGES_API_URL;
  const key = process.env.SIM_TOPUP_API_KEY;

  if (!url || !key) {
    throw new Error('SIM package provider credentials are incomplete.');
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      phone: d.tracker_sim_phone,
      operator: normalizeOperator(d.tracker_sim_operator),
    }),
  });

  const raw = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(`SIM package provider failed: ${response.status}`);
  }

  return {
    configured: true,
    operator: normalizeOperator(d.tracker_sim_operator),
    packages: Array.isArray(raw.packages) ? raw.packages : [],
  };
}

export async function buySimProduct({
  deviceId,
  userId,
  type,
  amountRial = null,
  packageId = null,
  packageName = null,
}) {
  const d = await device(deviceId);
  if (!d) throw new Error('Device not found.');

  if (!['airtime', 'internet'].includes(type)) {
    throw new Error('Unsupported SIM purchase type.');
  }

  const provider = (process.env.SIM_TOPUP_PROVIDER || 'disabled').toLowerCase();

  const inserted = await db.query(
    `INSERT INTO sim_purchase_history(
       device_id,user_id,purchase_type,amount_rial,
       package_id,package_name,provider,status
     )
     VALUES($1,$2,$3,$4,$5,$6,$7,'pending')
     RETURNING id`,
    [
      deviceId,
      userId,
      type,
      amountRial,
      packageId,
      packageName,
      provider,
    ]
  );

  const purchaseId = inserted.rows[0].id;

  if (provider === 'disabled') {
    return {
      configured: false,
      purchaseId,
      phone: d.tracker_sim_phone,
      operator: normalizeOperator(d.tracker_sim_operator),
      fallbackUssd: type === 'internet'
        ? operatorCodes(d.tracker_sim_operator)?.dataPurchaseMenu ?? null
        : null,
      message: 'SIM recharge provider is not configured.',
    };
  }

  const url = process.env.SIM_TOPUP_API_URL;
  const key = process.env.SIM_TOPUP_API_KEY;

  if (!url || !key) {
    throw new Error('SIM top-up provider credentials are incomplete.');
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      phone: d.tracker_sim_phone,
      operator: normalizeOperator(d.tracker_sim_operator),
      type,
      amountRial,
      packageId,
    }),
  });

  const raw = await response.json().catch(() => ({}));
  const ok = response.ok && Boolean(raw.success ?? raw.ok ?? false);

  await db.query(
    `UPDATE sim_purchase_history
     SET status=$1,
         provider_reference=$2,
         raw_response=$3::jsonb,
         completed_at=CASE WHEN $1='completed' THEN NOW() ELSE NULL END
     WHERE id=$4`,
    [
      ok ? 'completed' : 'failed',
      raw.reference || raw.refId || raw.transactionId || null,
      JSON.stringify(raw),
      purchaseId,
    ]
  );

  return {
    configured: true,
    ok,
    purchaseId,
    reference: raw.reference || raw.refId || raw.transactionId || null,
  };
}

export async function purchaseHistory(deviceId) {
  const { rows } = await db.query(
    `SELECT id,purchase_type,amount_rial,package_id,package_name,
            provider,status,provider_reference,created_at,completed_at
     FROM sim_purchase_history
     WHERE device_id=$1
     ORDER BY created_at DESC
     LIMIT 100`,
    [deviceId]
  );

  return rows;
}
