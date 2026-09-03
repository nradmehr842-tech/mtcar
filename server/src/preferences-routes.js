import express from 'express';
import { db } from './db.js';
import { authRequired, activeUserRequired } from './auth.js';
import { getMapProviderConfig } from './map-provider.js';

export const preferencesRouter = express.Router();

const MAPS = new Set(['auto', 'google', 'neshan', 'balad', 'osm']);
const NAV = new Set(['waze', 'google', 'neshan', 'balad']);

preferencesRouter.get('/preferences/maps', authRequired, activeUserRequired, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT map_provider,navigation_provider,map_style,updated_at
       FROM user_preferences WHERE user_id=$1`,
      [req.auth.sub]
    );

    const preferences = rows[0] || {
      map_provider: 'auto',
      navigation_provider: 'waze',
      map_style: 'standard',
      updated_at: null,
    };

    res.json({
      preferences,
      availability: getMapProviderConfig(),
    });
  } catch (e) {
    next(e);
  }
});

preferencesRouter.put('/preferences/maps', authRequired, activeUserRequired, async (req, res, next) => {
  try {
    const mapProvider = String(req.body?.mapProvider || 'auto').toLowerCase();
    const navigationProvider = String(req.body?.navigationProvider || 'waze').toLowerCase();
    const mapStyle = String(req.body?.mapStyle || 'standard').toLowerCase();

    if (!MAPS.has(mapProvider)) {
      return res.status(400).json({ error: 'invalid_map_provider' });
    }

    if (!NAV.has(navigationProvider)) {
      return res.status(400).json({ error: 'invalid_navigation_provider' });
    }

    if (!['standard', 'satellite', 'dark'].includes(mapStyle)) {
      return res.status(400).json({ error: 'invalid_map_style' });
    }

    const { rows } = await db.query(
      `INSERT INTO user_preferences(
         user_id,map_provider,navigation_provider,map_style,updated_at
       )
       VALUES($1,$2,$3,$4,NOW())
       ON CONFLICT(user_id) DO UPDATE SET
         map_provider=EXCLUDED.map_provider,
         navigation_provider=EXCLUDED.navigation_provider,
         map_style=EXCLUDED.map_style,
         updated_at=NOW()
       RETURNING map_provider,navigation_provider,map_style,updated_at`,
      [req.auth.sub, mapProvider, navigationProvider, mapStyle]
    );

    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});
