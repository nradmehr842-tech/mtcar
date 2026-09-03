import pg from 'pg';
const { Pool } = pg;

export const db = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export async function initDb() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGSERIAL PRIMARY KEY,
      phone VARCHAR(32) UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
      role VARCHAR(24) NOT NULL DEFAULT 'user',
      status VARCHAR(24) NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(24) NOT NULL DEFAULT 'user';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'active';

    CREATE TABLE IF NOT EXISTS organizations (
      id BIGSERIAL PRIMARY KEY,
      name VARCHAR(180) NOT NULL,
      legal_name VARCHAR(220),
      phone VARCHAR(32),
      national_id VARCHAR(64),
      status VARCHAR(24) NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS organization_members (
      id BIGSERIAL PRIMARY KEY,
      organization_id BIGINT REFERENCES organizations(id) ON DELETE CASCADE,
      user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
      member_role VARCHAR(32) NOT NULL DEFAULT 'viewer',
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(organization_id,user_id)
    );


    CREATE TABLE IF NOT EXISTS user_preferences (
      user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      map_provider VARCHAR(32) NOT NULL DEFAULT 'auto',
      navigation_provider VARCHAR(32) NOT NULL DEFAULT 'waze',
      map_style VARCHAR(24) NOT NULL DEFAULT 'standard',
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS otp_challenges (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
      purpose VARCHAR(32) NOT NULL,
      target_phone VARCHAR(32) NOT NULL,
      code_hash TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      consumed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS subscriptions (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
      organization_id BIGINT REFERENCES organizations(id) ON DELETE CASCADE,
      starts_at TIMESTAMPTZ NOT NULL,
      ends_at TIMESTAMPTZ NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'active',
      payment_id BIGINT,
      note TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS organization_id BIGINT REFERENCES organizations(id) ON DELETE CASCADE;

    CREATE TABLE IF NOT EXISTS membership_payments (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
      organization_id BIGINT REFERENCES organizations(id) ON DELETE CASCADE,
      amount_toman BIGINT NOT NULL,
      provider VARCHAR(50) NOT NULL,
      authority VARCHAR(255),
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      provider_reference VARCHAR(255),
      raw_response JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      paid_at TIMESTAMPTZ
    );

    ALTER TABLE membership_payments ADD COLUMN IF NOT EXISTS organization_id BIGINT REFERENCES organizations(id) ON DELETE CASCADE;


    CREATE TABLE IF NOT EXISTS device_models (
      id BIGSERIAL PRIMARY KEY,
      brand VARCHAR(80) NOT NULL,
      model VARCHAR(120) NOT NULL,
      display_name VARCHAR(180) NOT NULL,
      thumbnail_asset VARCHAR(500),
      protocol VARCHAR(80),
      server_port INTEGER,
      transport VARCHAR(16) NOT NULL DEFAULT 'tcp',
      capabilities JSONB NOT NULL DEFAULT '{}'::jsonb,
      command_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
      setup_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      is_verified BOOLEAN NOT NULL DEFAULT FALSE,
      notes TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(brand,model)
    );

    CREATE TABLE IF NOT EXISTS user_devices (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
      device_model_id BIGINT REFERENCES device_models(id),
      organization_id BIGINT REFERENCES organizations(id) ON DELETE CASCADE,
      traccar_device_id BIGINT,
      imei VARCHAR(64) UNIQUE NOT NULL,
      tracker_sim_phone VARCHAR(32),
      tracker_password_hint VARCHAR(32),
      vehicle_name VARCHAR(120),
      vehicle_type VARCHAR(24) NOT NULL DEFAULT 'car',
      vehicle_icon VARCHAR(64) NOT NULL DEFAULT 'car',
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    ALTER TABLE device_models ADD COLUMN IF NOT EXISTS thumbnail_asset VARCHAR(500);
    ALTER TABLE device_models ALTER COLUMN thumbnail_asset TYPE VARCHAR(500);

    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS organization_id BIGINT REFERENCES organizations(id) ON DELETE CASCADE;
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS device_model_id BIGINT REFERENCES device_models(id);
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS protocol_override VARCHAR(80);
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS server_port_override INTEGER;

    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS tracker_sim_operator VARCHAR(64);
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS tracker_sim_type VARCHAR(24) NOT NULL DEFAULT 'prepaid';

    CREATE TABLE IF NOT EXISTS device_sim_status (
      id BIGSERIAL PRIMARY KEY,
      device_id BIGINT UNIQUE REFERENCES user_devices(id) ON DELETE CASCADE,
      operator VARCHAR(64),
      sim_active BOOLEAN,
      airtime_available BOOLEAN NOT NULL DEFAULT FALSE,
      airtime_balance_rial BIGINT,
      data_available BOOLEAN NOT NULL DEFAULT FALSE,
      data_remaining_mb BIGINT,
      data_package_name VARCHAR(180),
      data_package_expires_at TIMESTAMPTZ,
      source VARCHAR(40) NOT NULL DEFAULT 'unavailable',
      last_queried_at TIMESTAMPTZ,
      last_error TEXT,
      raw_response JSONB,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS device_events (
      id BIGSERIAL PRIMARY KEY,
      device_id BIGINT REFERENCES user_devices(id) ON DELETE CASCADE,
      event_type VARCHAR(80) NOT NULL,
      severity VARCHAR(24) NOT NULL DEFAULT 'info',
      title VARCHAR(180) NOT NULL,
      message TEXT,
      source VARCHAR(40) NOT NULL DEFAULT 'server',
      event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      attributes JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_device_events_device_time
      ON device_events(device_id,event_time DESC);

    CREATE TABLE IF NOT EXISTS sim_purchase_history (
      id BIGSERIAL PRIMARY KEY,
      device_id BIGINT REFERENCES user_devices(id) ON DELETE CASCADE,
      user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
      purchase_type VARCHAR(24) NOT NULL,
      amount_rial BIGINT,
      package_id VARCHAR(120),
      package_name VARCHAR(180),
      provider VARCHAR(64),
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      provider_reference VARCHAR(255),
      raw_response JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      completed_at TIMESTAMPTZ
    );


    ALTER TABLE users ADD COLUMN IF NOT EXISTS free_trial_started_at TIMESTAMPTZ;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS free_trial_ends_at TIMESTAMPTZ;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS free_trial_used BOOLEAN NOT NULL DEFAULT FALSE;


    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS first_online_at TIMESTAMPTZ;
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS last_online_at TIMESTAMPTZ;


    ALTER TABLE device_models ADD COLUMN IF NOT EXISTS thumbnail_asset VARCHAR(120);

    CREATE INDEX IF NOT EXISTS idx_device_sim_status_device
      ON device_sim_status(device_id);

    CREATE INDEX IF NOT EXISTS idx_sim_purchase_device_created
      ON sim_purchase_history(device_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS support_tickets (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
      organization_id BIGINT REFERENCES organizations(id) ON DELETE SET NULL,
      subject VARCHAR(220) NOT NULL,
      category VARCHAR(64) NOT NULL DEFAULT 'general',
      priority VARCHAR(24) NOT NULL DEFAULT 'normal',
      status VARCHAR(24) NOT NULL DEFAULT 'open',
      assigned_admin_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      closed_at TIMESTAMPTZ
    );

    CREATE TABLE IF NOT EXISTS support_messages (
      id BIGSERIAL PRIMARY KEY,
      ticket_id BIGINT REFERENCES support_tickets(id) ON DELETE CASCADE,
      sender_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
      sender_role VARCHAR(24) NOT NULL,
      message TEXT NOT NULL,
      is_internal BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS remote_config (
      key VARCHAR(120) PRIMARY KEY,
      value JSONB NOT NULL,
      public BOOLEAN NOT NULL DEFAULT FALSE,
      updated_by BIGINT REFERENCES users(id),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS admin_audit_log (
      id BIGSERIAL PRIMARY KEY,
      admin_user_id BIGINT REFERENCES users(id),
      action VARCHAR(120) NOT NULL,
      target_type VARCHAR(64),
      target_id VARCHAR(128),
      details JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_user_preferences_map_provider ON user_preferences(map_provider);

    CREATE INDEX IF NOT EXISTS idx_subscriptions_user_end
      ON subscriptions(user_id, ends_at DESC);

    CREATE INDEX IF NOT EXISTS idx_subscriptions_org_end
      ON subscriptions(organization_id, ends_at DESC);

    CREATE INDEX IF NOT EXISTS idx_membership_payments_user_created
      ON membership_payments(user_id, created_at DESC);

    CREATE INDEX IF NOT EXISTS idx_user_devices_user
      ON user_devices(user_id);

    CREATE INDEX IF NOT EXISTS idx_user_devices_org
      ON user_devices(organization_id);

    CREATE INDEX IF NOT EXISTS idx_org_members_user
      ON organization_members(user_id);

    CREATE INDEX IF NOT EXISTS idx_support_tickets_user
      ON support_tickets(user_id, updated_at DESC);

    CREATE INDEX IF NOT EXISTS idx_support_tickets_status
      ON support_tickets(status, updated_at DESC);

    CREATE INDEX IF NOT EXISTS idx_support_messages_ticket
      ON support_messages(ticket_id, created_at);

    CREATE INDEX IF NOT EXISTS idx_admin_audit_created
      ON admin_audit_log(created_at DESC);


    INSERT INTO device_models(
      brand,model,display_name,thumbnail_asset,protocol,server_port,transport,
      capabilities,command_profile,setup_profile,is_verified,notes
    )
    VALUES (
      'MTcar','MT120','MT120','mt120-thumb','gps103',5001,'tcp',
      '{"liveTracking":true,"routeHistory":true,"acc":true,"door":true,"shock":true,"externalPower":true,"backupBattery":true,"sos":true,"voiceMonitor":true,"engineControl":true,"siren":true,"fuelSensor":true,"geofence":true,"movement":true,"overspeed":true}'::jsonb,
      '{"initialize":"begin{password}","apn":"APN{password} {apn}","gprsUserPass":"up{password} {gprsUser} {gprsPassword}","server":"adminip{password} {serverHost} {serverPort}","gprsOn":"GPRS{password}","smsMode":"SMS{password}","check":"check{password}","imei":"imei{password}","monitorOn":"monitor{password}","trackerMode":"tracker{password}","arm":"arm{password}","disarm":"disarm{password}","engineStop":"stop{password}","engineResume":"resume{password}"}'::jsonb,
      '{"family":"mt120","deviceClass":"vehicle","requiresImei":true,"requiresTrackerSim":true,"requiresTrackerPassword":true,"requiresApn":true,"requiresServerHost":true}'::jsonb,
      TRUE,
      'Default MTcar tracker profile.'
    )
    ON CONFLICT(brand,model) DO NOTHING;

    INSERT INTO remote_config(key,value,public)
      VALUES
        ('subscription.annual_price_toman', '1200000'::jsonb, true),
        ('subscription.org_annual_price_per_vehicle_toman', '900000'::jsonb, true),
        ('subscription.grace_days', '3'::jsonb, true),
        ('app.brand_name', '"MTcar"'::jsonb, true),
        ('app.brand_name_en', '"MTcar"'::jsonb, true),
        ('app.support_phone', '""'::jsonb, true),
        ('app.support_email', '"support@mediatelecom.ir"'::jsonb, true),
        ('app.about_title', '"MTcar"'::jsonb, true),
        ('app.about_text', '"سامانه مدیریت و رهگیری خودرو و موتورسیکلت"'::jsonb, true),
        ('app.announcement', '""'::jsonb, true),
        ('app.minimum_version', '"1.0.0"'::jsonb, true),
        ('app.force_update', 'false'::jsonb, true),
        ('features.sms_backup', 'true'::jsonb, true),
        ('features.voice_monitor', 'true'::jsonb, true),
        ('features.engine_control', 'true'::jsonb, true),
        ('features.organization_portal', 'true'::jsonb, true),
        ('features.support_tickets', 'true'::jsonb, true),
        ('map.preferred_provider', '"auto"'::jsonb, true),
        ('map.allowed_providers', '["google","neshan","balad","osm"]'::jsonb, true),
        ('navigation.allowed_providers', '["waze","google","neshan","balad"]'::jsonb, true),
        ('subscription.free_trial_months', '1'::jsonb, true)
      ON CONFLICT (key) DO NOTHING;
  `);
}
