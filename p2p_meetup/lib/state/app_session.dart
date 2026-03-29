import 'package:flutter/foundation.dart';

enum MeetVibe { coworking, studying, brainstorming, socialGaming }

enum FriendEdge { none, pendingOutgoing, pendingIncoming, friends }

class ActiveMeet {
  ActiveMeet({
    required this.topic,
    required this.vibe,
    required this.locationLabel,
    this.lat,
    this.lng,
    required this.maxPeople,
    required this.durationMinutes,
    required this.filterPingOnly,
    required this.filterFriendsOnly,
    required this.openAllMajors,
    this.icebreakerQuestion,
  });

  final String topic;
  final MeetVibe vibe;
  final String locationLabel;
  final double? lat;
  final double? lng;
  final int? maxPeople;
  final int durationMinutes;
  final bool filterPingOnly;
  final bool filterFriendsOnly;
  final bool openAllMajors;
  final String? icebreakerQuestion;
}

class GuestSeekState {
  GuestSeekState({
    required this.locationLabel,
    this.lat,
    this.lng,
  });

  final String locationLabel;
  final double? lat;
  final double? lng;
}

/// In-memory session + preferences mirrored to Supabase where possible.
class AppSession extends ChangeNotifier {
  AppSession({String localUserId = ''}) : _localUserId = localUserId;

  /// Matches `profiles.id` (Supabase Auth uid when signed in).
  String _localUserId;
  String get localUserId => _localUserId;

  void setLocalUserId(String id) {
    if (_localUserId == id) return;
    _localUserId = id;
    notifyListeners();
  }

  void clearForLogout() {
    _localUserId = '';
    currentUsername = '';
    interests = [];
    socials.clear();
    shareGeoPublic = true;
    showRealName = true;
    plusDismissed = false;
    hostingMeet = null;
    seekingHost = null;
    friendEdges.clear();
    incomingRequestFrom.clear();
    notifyListeners();
  }

  String currentUsername = '';

  List<String> interests = [];
  Map<String, String> socials = {};
  bool shareGeoPublic = true;
  bool showRealName = true;

  bool plusDismissed = false;
  ActiveMeet? hostingMeet;
  GuestSeekState? seekingHost;

  final Map<String, FriendEdge> friendEdges = {};
  final Set<String> incomingRequestFrom = {};

  void setLocalFriendEdge(String otherId, FriendEdge edge) {
    friendEdges[otherId] = edge;
    notifyListeners();
  }

  FriendEdge edgeFor(String otherId) => friendEdges[otherId] ?? FriendEdge.none;

  void setInterests(List<String> v) {
    interests = List<String>.from(v);
    notifyListeners();
  }

  void setSocials(Map<String, String> v) {
    socials = Map<String, String>.from(v);
    notifyListeners();
  }

  void setShareGeoPublic(bool v) {
    shareGeoPublic = v;
    notifyListeners();
  }

  void setShowRealName(bool v) {
    showRealName = v;
    notifyListeners();
  }

  void startHosting(ActiveMeet meet) {
    hostingMeet = meet;
    seekingHost = null;
    plusDismissed = true;
    notifyListeners();
  }

  void startSeeking(GuestSeekState s) {
    seekingHost = s;
    hostingMeet = null;
    plusDismissed = true;
    notifyListeners();
  }

  void cancelHostGuestMode() {
    hostingMeet = null;
    seekingHost = null;
    plusDismissed = false;
    notifyListeners();
  }

  void sendFriendRequest(String toId) {
    friendEdges[toId] = FriendEdge.pendingOutgoing;
    notifyListeners();
  }

  void rescindFriendRequest(String toId) {
    friendEdges[toId] = FriendEdge.none;
    notifyListeners();
  }

  void receiveFriendRequest(String fromId) {
    incomingRequestFrom.add(fromId);
    friendEdges[fromId] = FriendEdge.pendingIncoming;
    notifyListeners();
  }

  void acceptFriend(String fromId) {
    incomingRequestFrom.remove(fromId);
    friendEdges[fromId] = FriendEdge.friends;
    notifyListeners();
  }

  void rejectFriend(String fromId) {
    incomingRequestFrom.remove(fromId);
    friendEdges[fromId] = FriendEdge.none;
    notifyListeners();
  }

  void removeFriend(String id) {
    friendEdges[id] = FriendEdge.none;
    notifyListeners();
  }
}
