export function canStopEngine(position) {
  const max = Number(process.env.ENGINE_STOP_MAX_SPEED_KMH || 20);
  const speedKnots = Number(position?.speed || 0);
  const speedKmh = speedKnots * 1.852;
  return { allowed: speedKmh <= max, speedKmh, max };
}

export function classifyTamper(events, now = Date.now()) {
  const windowMs = 120_000;
  const recent = events.filter(e => now - e.time <= windowMs);
  const power = recent.some(e => e.type === 'power');
  const motion = recent.some(e => e.type === 'shock' || e.type === 'movement');
  return power && motion;
}
