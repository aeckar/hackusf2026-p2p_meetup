import 'campus_geo.dart';

class CampusLandmark {
  const CampusLandmark(this.id, this.label, this.lat, this.lng);
  final String id;
  final String label;
  final double lat;
  final double lng;
}

/// Hard-coded campus landmarks (approximate). Extend as needed.
const List<CampusLandmark> kUsfLandmarks = [
  CampusLandmark('enb', 'Engineering II (ENB)', 28.05850, -82.41590),
  CampusLandmark('msc', 'Marshall Student Center', 28.06490, -82.41320),
  CampusLandmark('lib', 'Library', 28.05970, -82.41340),
  CampusLandmark('cwb', 'Cooper Hall (CWB)', 28.06320, -82.41460),
];

CampusLandmark? nearestLandmarkWithinMeters(double lat, double lng, double maxMeters) {
  CampusLandmark? best;
  double bestD = double.infinity;
  for (final l in kUsfLandmarks) {
    final d = haversineMeters(lat, lng, l.lat, l.lng);
    if (d < bestD) {
      bestD = d;
      best = l;
    }
  }
  if (best != null && bestD <= maxMeters) return best;
  return null;
}
