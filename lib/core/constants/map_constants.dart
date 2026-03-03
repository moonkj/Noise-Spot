class MapConstants {
  MapConstants._();

  // Query radius
  static const double defaultRadiusMeters = 3000.0;
  static const double maxRadiusMeters = 5000.0;

  // Reporting proximity gate
  static const double reportMaxDistanceMeters = 65.0;

  // Camera idle debounce
  static const int cameraIdleDebounceMs = 300;

  // Bounds cache TTL (5 minutes)
  static const int boundsCacheTtlSeconds = 300;

  // Zoom thresholds
  static const double zoomMinLoad = 11.0;      // below this: no data load
  static const double zoomHeatmapMin = 11.0;   // 11–12: heatmap/average
  static const double zoomHeatmapMax = 12.9;
  static const double zoomReducedMin = 13.0;   // 13–14: reduced markers
  static const double zoomReducedMax = 14.9;
  static const double zoomIndividualMin = 15.0; // 15+: individual markers

  // Default map center (Seoul City Hall)
  static const double defaultLat = 37.5665;
  static const double defaultLng = 126.9780;
  static const double defaultZoom = 17.0;

  // Marker sizes
  static const double markerSizeIndividual = 32.0;
  static const double markerSizeReduced = 24.0;

  // Spot inactivity threshold for fading
  static const int spotFadeAfterDays = 30;

  // Max spots per query
  static const int maxSpotsPerQuery = 100;

  // Data freshness
  static const int freshDataHours = 24;
  static const int fallbackDataDays = 7;
}
