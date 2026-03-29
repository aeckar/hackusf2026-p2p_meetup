import 'dart:math' as math;

/// Rough axis-aligned bounds for USF Tampa main campus (verify/tighten for production).
bool isOnUsfTampaCampus(double lat, double lng) {
  const minLat = 28.0515;
  const maxLat = 28.0710;
  const minLng = -82.4280;
  const maxLng = -82.4040;
  return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}
