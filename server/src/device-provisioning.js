export function renderCommandTemplate(template, values) {
  if (!template || typeof template !== 'string') return null;

  return template.replace(/\{([A-Za-z0-9_]+)\}/g, (_match, key) => {
    const value = values[key];
    return value === undefined || value === null || value === ''
      ? `{${key}}`
      : String(value);
  });
}

export function buildProvisioningPlan(model, {
  trackerPassword,
  apn,
  gprsUser = '',
  gprsPassword = '',
  serverHost,
} = {}) {
  if (!model) {
    return { ready: false, reason: 'model_not_found', commands: [] };
  }

  const protocol = model.protocol || null;
  const serverPort = Number(model.serverPort ?? model.server_port ?? 0) || null;
  const transport = String(model.transport || 'tcp').toLowerCase();
  const commandProfile = model.commandProfile || model.command_profile || {};
  const setupProfile = model.setupProfile || model.setup_profile || {};

  if (!protocol || !serverPort) {
    return {
      ready: false,
      reason: 'protocol_or_port_missing',
      protocol,
      serverPort,
      commands: [],
    };
  }

  const values = {
    password: trackerPassword || '{password}',
    apn: apn || '{apn}',
    gprsUser: gprsUser || '{gprsUser}',
    gprsPassword: gprsPassword || '{gprsPassword}',
    serverHost: serverHost || process.env.TRACKER_PUBLIC_HOST || '{serverHost}',
    serverPort,
    transport,
  };

  const preferredOrder = [
    'initialize',
    'apn',
    'gprsUserPass',
    'server',
    'tcpMode',
    'udpMode',
    'gprsOn',
    'check',
  ];

  const orderedKeys = [
    ...preferredOrder.filter(key => commandProfile[key]),
    ...Object.keys(commandProfile).filter(key => !preferredOrder.includes(key)),
  ];

  return {
    ready: true,
    protocol,
    serverPort,
    transport,
    serverHost: values.serverHost,
    setupProfile,
    commands: orderedKeys.map((key, index) => ({
      step: index + 1,
      key,
      sms: renderCommandTemplate(commandProfile[key], values),
    })),
  };
}
