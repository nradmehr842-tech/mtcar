/*
  Operator USSD registry for fallback/reference UI.

  IMPORTANT:
  These codes run on the SIM that executes the USSD session.
  MTcar's target SIM is normally inside the vehicle tracker, so automatic
  top-up/package purchase for that SIM should use the server-side provider API.
*/

export const CARRIER_CODES = {
  mci: {
    id: 'mci',
    faName: 'همراه اول',
    balance: {
      primary: '*10*121#',
      alternatives: ['*140*11#'],
    },
    dataStatus: {
      primary: '*100*1#',
    },
    dataPurchaseMenu: {
      primary: '*100#',
    },
  },

  irancell: {
    id: 'irancell',
    faName: 'ایرانسل',
    balance: {
      primary: '*555*1*2#',
      alternatives: ['*141*1#'],
    },
    dataStatus: {
      primary: '*555*1*4#',
    },
    dataPurchaseMenu: {
      primary: '*555*5#',
    },
  },
};

export function normalizeOperator(value) {
  const v = String(value || '').trim().toLowerCase();

  if (['mci', 'mtn-mci', 'hamrah aval', 'همراه اول', 'همراه‌اول'].includes(v)) {
    return 'mci';
  }

  if (['irancell', 'mtn irancell', 'mtn-irancell', 'ایرانسل'].includes(v)) {
    return 'irancell';
  }

  return 'unknown';
}

export function operatorCodes(value) {
  const id = normalizeOperator(value);
  return CARRIER_CODES[id] || null;
}
