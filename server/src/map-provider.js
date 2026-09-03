export function getMapProviderConfig() {
  const provider = (process.env.MAP_PROVIDER || 'auto').toLowerCase();

  return {
    provider,
    googleConfigured: Boolean(process.env.GOOGLE_MAPS_API_KEY),
    neshanConfigured: Boolean(process.env.NESHAN_API_KEY),
    baladConfigured: Boolean(process.env.BALAD_API_KEY),

    allowedMapProviders: ['google', 'neshan', 'balad', 'osm'],
    allowedNavigationProviders: ['waze', 'google', 'neshan', 'balad'],

    fallback: 'osm',
  };
}

/*
  MTcar provider policy

  In-app maps:
  - Google: official Google Maps SDK/API key required.
  - Neshan: enable only with valid official SDK/API credentials.
  - Balad: enable only when official documented developer access is available.
  - OSM: development/fallback provider.

  Navigation:
  - Waze is treated as an external navigation target/deep-link, not as an
    embeddable base-map layer.
  - Google/Neshan/Balad can also be navigation targets when supported.

  Do not hard-code undocumented map tile URLs.
*/
