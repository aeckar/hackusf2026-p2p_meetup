import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // 1. Get the Live Stream of Online Users
  Stream<List<Map<String, dynamic>>> get onlineUsersStream {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('is_online', true)
        .order('updated_at', ascending: false);
  }

  // 2. The "Check-In" Function
  Future<void> updateProfile({
    String? username,
    List<String>? interests,
    String? location,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'username': username ?? user.userMetadata?['username'] as String? ?? user.email ?? 'user',
      'interests': interests ?? const ['rust', 'md', 'js'],
      'campus_location': location ?? 'MSC',
      'is_online': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // 3. The "Check-Out" (Optional for Demo)
  Future<void> goOffline() async {
    final userId = _client.auth.currentUser?.id ?? 'guest-id-123';
    await _client
        .from('profiles')
        .update({'is_online': false})
        .eq('id', userId);
  }
}
