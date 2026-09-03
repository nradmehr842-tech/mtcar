const base = () => process.env.TRACCAR_URL || 'http://traccar:8082';

async function request(path, options = {}) {
  const token = process.env.TRACCAR_TOKEN;
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(options.headers || {}),
  };
  const res = await fetch(`${base()}${path}`, { ...options, headers });
  if (!res.ok) throw new Error(`Traccar ${res.status}: ${await res.text()}`);
  if (res.status === 204) return null;
  return res.json();
}

export const traccar = {
  devices: () => request('/api/devices'),
  createDevice: ({ name, uniqueId }) =>
    request('/api/devices', {
      method: 'POST',
      body: JSON.stringify({
        name: String(name || uniqueId),
        uniqueId: String(uniqueId),
      }),
    }),
  positions: () => request('/api/positions'),
  position: async (deviceId) => {
    const all = await request('/api/positions');
    return all.find(p => Number(p.deviceId) === Number(deviceId)) || null;
  },
  reportRoute: (deviceId, from, to) =>
    request(`/api/reports/route?deviceId=${encodeURIComponent(deviceId)}&from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`),
  sendCommand: (deviceId, type) =>
    request('/api/commands/send', {
      method: 'POST',
      body: JSON.stringify({ deviceId: Number(deviceId), type }),
    }),
};
