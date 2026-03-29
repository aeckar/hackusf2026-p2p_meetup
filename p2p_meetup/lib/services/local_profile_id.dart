import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kLocalProfileId = 'local_profile_id';

/// Stable UUID for `profiles.id` when Supabase Auth is not used.
Future<String> loadOrCreateLocalProfileId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kLocalProfileId);
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await prefs.setString(_kLocalProfileId, id);
  }
  return id;
}

/// Persists a new id (log out / switch local identity).
Future<String> replaceLocalProfileId() async {
  final prefs = await SharedPreferences.getInstance();
  final id = const Uuid().v4();
  await prefs.setString(_kLocalProfileId, id);
  return id;
}
