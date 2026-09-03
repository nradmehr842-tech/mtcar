enum MapProviderType {
  auto,
  google,
  neshan,
  balad,
  osm,
}

enum NavigationProviderType {
  waze,
  google,
  neshan,
  balad,
}

enum MapVisualStyle {
  standard,
  satellite,
  dark,
}

class MapProviderAvailability {
  final bool googleConfigured;
  final bool neshanConfigured;
  final bool baladConfigured;

  const MapProviderAvailability({
    required this.googleConfigured,
    required this.neshanConfigured,
    required this.baladConfigured,
  });

  bool isAvailable(MapProviderType type) {
    switch (type) {
      case MapProviderType.auto:
      case MapProviderType.osm:
        return true;
      case MapProviderType.google:
        return googleConfigured;
      case MapProviderType.neshan:
        return neshanConfigured;
      case MapProviderType.balad:
        return baladConfigured;
    }
  }

  MapProviderType resolve(MapProviderType preferred) {
    if (preferred != MapProviderType.auto && isAvailable(preferred)) {
      return preferred;
    }

    if (neshanConfigured) return MapProviderType.neshan;
    if (googleConfigured) return MapProviderType.google;
    if (baladConfigured) return MapProviderType.balad;
    return MapProviderType.osm;
  }
}

/*
  Important:
  - Google must use the official Google Maps SDK/API key.
  - Neshan/Balad must only use official documented SDK/API access.
  - Waze is a navigation target, not an embedded base-map provider.
  - OSM remains the safe development fallback.
*/
