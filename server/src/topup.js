export async function topupSim({ phone, amount, operator }) {
  const provider = (process.env.TOPUP_PROVIDER || 'disabled').toLowerCase();

  if (provider === 'disabled') {
    return {
      ok: false,
      code: 'TOPUP_NOT_CONFIGURED',
      message: 'Top-up provider is not configured on the server.',
    };
  }

  const url = process.env.TOPUP_API_URL;
  const key = process.env.TOPUP_API_KEY;
  if (!url || !key) throw new Error('Top-up provider credentials are incomplete.');

  // Adapter placeholder. Map request/response exactly to the chosen provider contract.
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({ phone, amount, operator }),
  });

  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body };
}
