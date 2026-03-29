import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/profile_parse.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> profilesStream() {
    return _client.from('profiles').stream(primaryKey: ['id']).order('updated_at', ascending: false);
  }

  /// Ensures a row exists for this device’s profile id (direct upsert, no auth).
  Future<void> ensureProfileRow({
    required String userId,
    String username = 'Peer',
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'username': username,
      'email': null,
      'updated_at': DateTime.now().toIso8601String(),
      'campus_location': null,
      'interests': <String>[],
      'is_online': false,
      'location_history': <String, dynamic>{},
      'socials': <String, dynamic>{},
      'is_real_name_public': false,
    });
  }

  Future<void> syncSettings({
    required String userId,
    required List<String> interests,
    required Map<String, String> socials,
    required bool shareGeoPublic,
    required bool showRealName,
  }) async {
    await _client.from('profiles').update({
      'interests': interests,
      'socials': socials,
      'is_real_name_public': showRealName,
      // Optional: persist a settings flag if you add a column; for now only public geo is behavioral in UI.
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> setOnlinePresence({
    required String userId,
    required bool online,
    String? campusLocation,
  }) async {
    final patch = <String, dynamic>{
      'is_online': online,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (campusLocation != null) patch['campus_location'] = campusLocation;
    await _client.from('profiles').update(patch).eq('id', userId);
  }

  /// Best-effort read for merging into [AppSession].
  Future<void> hydrateSession({
    required String userId,
    required void Function(Map<String, dynamic> row) onRow,
  }) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row != null) onRow(Map<String, dynamic>.from(row));
  }
}

List<Map<String, dynamic>> visibleOnlineProfiles(List<Map<String, dynamic>> rows) {
  return rows.where(profileIsOnline).toList();
}
