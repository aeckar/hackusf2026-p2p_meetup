/// Tolerates legacy column names (`online`, `interest`) and current `profiles` schema.
bool profileIsOnline(Map<String, dynamic> row) {
  if (row['is_online'] == true) return true;
  if (row['online'] == true) return true;
  return false;
}

List<String> profileInterests(Map<String, dynamic> row) {
  if (row['interests'] != null) {
    return List<String>.from(row['interests'] as List? ?? []);
  }
  if (row['interest'] != null) {
    return List<String>.from(row['interest'] as List? ?? []);
  }
  return [];
}

String? profileUsername(Map<String, dynamic> row) => row['username'] as String?;

String profileLocationLabel(Map<String, dynamic> row) {
  final v = row['campus_location'] as String?;
  if (v == null || v.trim().isEmpty) return '???';
  return v;
}

Map<String, dynamic> profileLocationHistory(Map<String, dynamic> row) {
  final raw = row['location_history'];
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return {};
}

Map<String, String> profileSocials(Map<String, dynamic> row) {
  final raw = row['socials'];
  if (raw is Map) {
    return raw.map((k, v) => MapEntry('$k', '$v'));
  }
  return {};
}

List<String> profileFriends(Map<String, dynamic> row) {
  final raw = row['friends'];
  if (raw is List) {
    return List<String>.from(raw.map((e) => '$e'));
  }
  if (raw != null && '$raw'.isNotEmpty) {
    return ['$raw'];
  }
  return [];
}

bool profileRealNamePublic(Map<String, dynamic> row) {
  if (row['is_real_name_public'] == true) return true;
  return false;
}

/// Client-side encoding for active meets: `MEET|<topic>|<location label>`.
String encodeMeetCampusLocation({required String topic, required String locationLabel}) {
  return 'MEET|${topic.replaceAll('|', ' ')}|${locationLabel.replaceAll('|', ' ')}';
}

({String topic, String location})? decodeMeetCampus(String? raw) {
  if (raw == null || !raw.startsWith('MEET|')) return null;
  final parts = raw.split('|');
  if (parts.length < 3) return null;
  final topic = parts[1];
  final location = parts.sublist(2).join('|');
  if (topic.isEmpty) return null;
  return (topic: topic, location: location);
}
