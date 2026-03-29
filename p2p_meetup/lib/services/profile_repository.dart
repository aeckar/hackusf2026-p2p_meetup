import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/profile_parse.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  Stream<List<Map<String, dynamic>>> profilesStream() {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false);
  }

  /// Returns the matching profile row, or null if credentials are wrong.
  Future<Map<String, dynamic>?> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    return _client
        .from('profiles')
        .select()
        .eq('username', username)
        .eq('password', password)
        .maybeSingle();
  }

  /// Inserts a new profile row and returns the generated id.
  /// Throws if the username is already taken.
  Future<String> createAccount({
    required String username,
    required String email,
    required String password,
  }) async {
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    if (existing != null) throw Exception('Username already taken.');

    final uid = _uuid.v4();
    await _client.from('profiles').insert({
      'id': uid,
      'username': username,
      'email': email.isEmpty ? null : email,
      'password': password,
      'updated_at': DateTime.now().toIso8601String(),
      'campus_location': null,
      'interests': <String>[],
      'is_online': false,
      'location_history': <String, dynamic>{},
      'socials': <String, dynamic>{},
      'is_real_name_public': false,
    });
    return uid;
  }

  /// Ensures a row exists for this device's profile id.
  Future<void> ensureProfileRow({
    required String userId,
    String username = 'Peer',
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'username': username,
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

  /// Sends a ping with an optional icebreaker to another user.
  Future<void> sendPing({
    required String fromId,
    required String toId,
    required String message,
    required String icebreaker,
  }) async {
    await _client.from('pings').insert({
      'from_id': fromId,
      'to_id': toId,
      'message': message,
      'icebreaker': icebreaker,
    });
  }

  /// Stream of unseen pings addressed to [userId].
  Stream<List<Map<String, dynamic>>> incomingPingsStream(String userId) {
    return _client
        .from('pings')
        .stream(primaryKey: ['id'])
        .eq('to_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> markPingSeen(String pingId) async {
    await _client.from('pings').update({'seen': true}).eq('id', pingId);
  }

  /// Best-effort read for merging into [AppSession].
  Future<void> hydrateSession({
    required String userId,
    required void Function(Map<String, dynamic> row) onRow,
  }) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row != null) onRow(Map<String, dynamic>.from(row));
  }
}

List<Map<String, dynamic>> visibleOnlineProfiles(List<Map<String, dynamic>> rows) {
  return rows.where(profileIsOnline).toList();
}
