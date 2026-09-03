import { db } from './db.js';

const MT120 = {
  brand: 'MTcar',
  model: 'MT120',
  displayName: 'MT120',
  thumbnailAsset: 'mt120-thumb',
  protocol: 'gps103',
  serverPort: 5001,
  transport: 'tcp',
  capabilities: {
    liveTracking: true,
    routeHistory: true,
    acc: true,
    door: true,
    shock: true,
    externalPower: true,
    backupBattery: true,
    sos: true,
    voiceMonitor: true,
    engineControl: true,
    siren: true,
    fuelSensor: true,
    geofence: true,
    movement: true,
    overspeed: true
  },
  commandProfile: {
    initialize: 'begin{password}',
    apn: 'APN{password} {apn}',
    gprsUserPass: 'up{password} {gprsUser} {gprsPassword}',
    server: 'adminip{password} {serverHost} {serverPort}',
    gprsOn: 'GPRS{password}',
    smsMode: 'SMS{password}',
    check: 'check{password}',
    imei: 'imei{password}',
    monitorOn: 'monitor{password}',
    trackerMode: 'tracker{password}',
    arm: 'arm{password}',
    disarm: 'disarm{password}',
    engineStop: 'stop{password}',
    engineResume: 'resume{password}'
  },
  setupProfile: {
    family: 'mt120',
    deviceClass: 'vehicle',
    requiresImei: true,
    requiresTrackerSim: true,
    requiresTrackerPassword: true,
    requiresApn: true,
    requiresServerHost: true
  }
};

export async function seedMt120AndMigrateCatalog() {
  await db.query(
    `INSERT INTO device_models(
       brand,model,display_name,thumbnail_asset,protocol,server_port,transport,
       capabilities,command_profile,setup_profile,is_active,is_verified,notes,updated_at
     )
     VALUES($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9::jsonb,$10::jsonb,TRUE,TRUE,$11,NOW())
     ON CONFLICT(brand,model) DO UPDATE SET
       display_name=EXCLUDED.display_name,
       thumbnail_asset=EXCLUDED.thumbnail_asset,
       protocol=EXCLUDED.protocol,
       server_port=EXCLUDED.server_port,
       transport=EXCLUDED.transport,
       capabilities=EXCLUDED.capabilities,
       command_profile=EXCLUDED.command_profile,
       setup_profile=EXCLUDED.setup_profile,
       is_active=TRUE,
       is_verified=TRUE,
       notes=EXCLUDED.notes,
       updated_at=NOW()`,
    [
      MT120.brand,
      MT120.model,
      MT120.displayName,
      MT120.thumbnailAsset,
      MT120.protocol,
      MT120.serverPort,
      MT120.transport,
      JSON.stringify(MT120.capabilities),
      JSON.stringify(MT120.commandProfile),
      JSON.stringify(MT120.setupProfile),
      'Default MTcar tracker profile.'
    ]
  );

  // One-time migration from v19: hide the previously bundled Coban/AIKA/AKSH
  // catalog. This flag prevents future admin-created models from being hidden
  // again after a server restart.
  const migrated = await db.query(
    `SELECT value FROM remote_config
     WHERE key='device_models.v20_mt120_only_migrated'
     LIMIT 1`
  );

  if (!migrated.rowCount) {
    await db.query(
      `UPDATE device_models
       SET is_active=FALSE,updated_at=NOW()
       WHERE NOT (brand='MTcar' AND model='MT120')`
    );

    await db.query(
      `INSERT INTO remote_config(key,value,public,updated_at)
       VALUES('device_models.v20_mt120_only_migrated','true'::jsonb,FALSE,NOW())
       ON CONFLICT(key) DO UPDATE SET value='true'::jsonb,updated_at=NOW()`
    );
  }

  const { rows } = await db.query(
    `SELECT id,brand,model,display_name,protocol,server_port,transport
     FROM device_models
     WHERE brand='MTcar' AND model='MT120'
     LIMIT 1`
  );

  return rows[0];
}
