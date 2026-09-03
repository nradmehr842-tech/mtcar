import { getConfigValue } from './config.js';

export async function annualPriceToman() {
  const remote = await getConfigValue(
    'subscription.annual_price_toman',
    Number(process.env.SUBSCRIPTION_ANNUAL_PRICE_TOMAN || 0)
  );
  const value = Number(remote);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error('Annual subscription price is invalid.');
  }
  return Math.round(value);
}

export async function createMembershipPayment({ paymentId, amountToman, phone }) {
  const provider = (process.env.PAYMENT_PROVIDER || 'disabled').toLowerCase();

  if (provider === 'disabled') {
    return {
      ok: false,
      configured: false,
      provider,
      paymentId,
      message: 'Payment gateway is not configured.',
    };
  }

  const url = process.env.PAYMENT_API_URL;
  const key = process.env.PAYMENT_API_KEY;
  const callbackUrl = process.env.PAYMENT_CALLBACK_URL;
  if (!url || !key || !callbackUrl) {
    throw new Error('Payment gateway credentials are incomplete.');
  }

  // Generic adapter. Map this to the selected payment gateway's official API.
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      amountToman,
      callbackUrl,
      description: 'MTcar annual membership',
      mobile: phone,
      metadata: { paymentId },
    }),
  });

  const raw = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`Payment provider failed: ${response.status}`);
  }

  return {
    ok: true,
    configured: true,
    provider,
    authority: raw.authority || raw.id || raw.token || null,
    paymentUrl: raw.paymentUrl || raw.url || null,
    raw,
  };
}

export async function verifyMembershipPayment({ authority, amountToman }) {
  const provider = (process.env.PAYMENT_PROVIDER || 'disabled').toLowerCase();

  if (provider === 'disabled') {
    return { ok: false, configured: false, provider };
  }

  const verifyUrl = process.env.PAYMENT_VERIFY_URL;
  const key = process.env.PAYMENT_API_KEY;
  if (!verifyUrl || !key) {
    throw new Error('Payment verification configuration is incomplete.');
  }

  const response = await fetch(verifyUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({ authority, amountToman }),
  });

  const raw = await response.json().catch(() => ({}));

  return {
    ok: response.ok && Boolean(raw.success ?? raw.paid ?? raw.verified),
    provider,
    reference: raw.reference || raw.refId || raw.transactionId || null,
    raw,
  };
}
