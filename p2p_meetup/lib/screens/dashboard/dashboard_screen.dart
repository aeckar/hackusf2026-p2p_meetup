import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/gemini_service.dart';
import '../../services/profile_repository.dart';
import '../../state/app_session.dart';
import '../../theme/usf_theme.dart';
import '../../utils/avatar_url.dart';
import '../../utils/campus_geo.dart';
import '../../utils/profile_parse.dart';
import '../../utils/usf_landmarks.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/in_app_notifications.dart';
import '../../widgets/loading_overlay.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.supabase,
    required this.profileRepository,
    required this.gemini,
    required this.onLogout,
  });

  final SupabaseClient supabase;
  final ProfileRepository profileRepository;
  final GeminiService gemini;
  final Future<void> Function() onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final GlobalKey<InAppNotificationHostState> _notificationHostKey =
      GlobalKey<InAppNotificationHostState>();

  late final AnimationController _gearCtrl;
  StreamSubscription<List<Map<String, dynamic>>>? _pingSub;

  bool _settingsOpen = false;
  bool _friendsMode = false;
  bool _inMeeting = false;

  String _joinedTopic = 'Meet';
  int _joinedMax = 8;
  int _joinedCount = 1;

  double? _deviceLat;
  double? _deviceLng;

  @override
  void initState() {
    super.initState();
    _gearCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapProfile());
    });
  }

  @override
  void dispose() {
    _pingSub?.cancel();
    _gearCtrl.dispose();
    super.dispose();
  }

  void _subscribeToPings() {
    final uid = context.read<AppSession>().localUserId;
    if (uid.isEmpty) return;
    final seen = <String>{};
    _pingSub = widget.profileRepository.incomingPingsStream(uid).listen((pings) {
      for (final ping in pings) {
        final id = ping['id']?.toString() ?? '';
        if (ping['seen'] == true || seen.contains(id)) continue;
        seen.add(id);
        final msg = ping['message']?.toString() ?? '';
        final ice = ping['icebreaker']?.toString() ?? '';
        _toast(InAppNotification(
          message: msg.isNotEmpty
              ? 'Ping: "$msg"\nIcebreaker: $ice'
              : 'Icebreaker: $ice',
          edge: NotificationVerticalEdge.bottom,
        ));
        widget.profileRepository.markPingSeen(id);
      }
    });
  }

  Future<void> _bootstrapProfile() async {
    if (!mounted) return;
    final session = context.read<AppSession>();
    var uid = session.localUserId;
    if (uid.isEmpty) {
      uid = widget.supabase.auth.currentUser?.id ?? '';
    }
    if (uid.isEmpty) return;
    session.setLocalUserId(uid);
    try {
      await widget.profileRepository.ensureProfileRow(userId: uid);
      await widget.profileRepository.hydrateSession(
        userId: uid,
        onRow: (row) {
          session.currentUsername = profileUsername(row) ?? '';
          session.setInterests(profileInterests(row));
          session.setSocials(profileSocials(row));
          session.setShowRealName(profileRealNamePublic(row));
        },
      );
    } catch (_) {
      // Row may be blocked by RLS; UI still works locally.
    }
    if (!mounted) return;
    try {
      await widget.profileRepository.setOnlinePresence(userId: uid, online: true);
    } catch (_) {}
    _subscribeToPings();
  }

  Future<void> _ensureLocationForApp() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
    final p = await Geolocator.getCurrentPosition();
    setState(() {
      _deviceLat = p.latitude;
      _deviceLng = p.longitude;
    });
  }

  void _toast(InAppNotification n) {
    // State.context sits above [InAppNotificationHost], so [of] cannot find it; use a key.
    _notificationHostKey.currentState?.show(n);
  }

  Future<void> _openMaps(String label, double? lat, double? lng) async {
    Future<bool> tryOpen(Uri uri) async {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }

    final webUri = Uri.parse(
      (lat != null && lng != null)
          ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
          : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}',
    );

    if (lat != null && lng != null && !kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final geo = Uri.parse('geo:$lat,$lng?q=${Uri.encodeComponent(label)}');
        if (await tryOpen(geo)) return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apple =
            Uri.parse('http://maps.apple.com/?ll=$lat,$lng&q=${Uri.encodeComponent(label)}');
        if (await tryOpen(apple)) return;
      }
    }

    await tryOpen(webUri);
  }

  Future<void> _exitAppDialog() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit USF Meet?'),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (yes == true) SystemNavigator.pop();
  }

  Future<void> _logoutDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will return to the login screen. Host/guest state and friend shortcuts on this device reset.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await widget.onLogout();
    }
  }

  Future<void> _plusFlow() async {
    final session = context.read<AppSession>();
    if (session.plusDismissed) {
      session.cancelHostGuestMode();
      setState(() {});
      return;
    }

    final role = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Host or guest?'),
        content: const Text('Would you like to host a Meet or look for a host?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'host'), child: const Text('Host')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'guest'), child: const Text('Guest')),
        ],
      ),
    );
    if (!mounted || role == null) return;
    if (role == 'host') {
      await _hostMeetWizard();
    } else {
      await _guestSeekWizard();
    }
  }

  Future<void> _hostMeetWizard() async {
    final topicCtrl = TextEditingController(text: 'Open study');
    final iceCtrl = TextEditingController();
    int? maxPeople;
    var pingOnly = false;
    var friendsOnly = false;
    var allMajors = true;
    var duration = 60;
    var vibe = MeetVibe.studying;
    String locationMode = 'landmark';
    String landmarkId = kUsfLandmarks.first.id;
    MeetVibe? pickedVibe = vibe;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Set up your Meet'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: topicCtrl,
                    style: UsfTheme.inputTextStyle,
                    decoration: UsfTheme.inputDeco('Topic / subject'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: iceCtrl,
                    style: UsfTheme.inputTextStyle,
                    decoration: UsfTheme.inputDeco('Optional icebreaker question'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Max people (optional)'),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setLocal(() => maxPeople = (maxPeople == null) ? 6 : null),
                        icon: Icon(maxPeople == null ? Icons.person_off_outlined : Icons.people_outline),
                      ),
                    ],
                  ),
                  if (maxPeople != null)
                    Slider(
                      value: maxPeople!.toDouble().clamp(2, 30),
                      min: 2,
                      max: 30,
                      divisions: 28,
                      label: '${maxPeople!}',
                      onChanged: (v) => setLocal(() => maxPeople = v.round()),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only people I ping'),
                    value: pingOnly,
                    onChanged: (v) => setLocal(() => pingOnly = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only friends'),
                    value: friendsOnly,
                    onChanged: (v) => setLocal(() => friendsOnly = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open to all majors'),
                    value: allMajors,
                    onChanged: (v) => setLocal(() => allMajors = v),
                  ),
                  Text('Duration: ${duration}m'),
                  Slider(
                    value: duration.toDouble().clamp(15, 240),
                    min: 15,
                    max: 240,
                    divisions: 15,
                    label: '${duration}m',
                    onChanged: (v) => setLocal(() => duration = v.round()),
                  ),
                  const Text('Vibe'),
                  Wrap(
                    spacing: 8,
                    children: MeetVibe.values.map((v) {
                      return ChoiceChip(
                        label: Text(_vibeLabel(v)),
                        selected: pickedVibe == v,
                        onSelected: (_) => setLocal(() {
                          pickedVibe = v;
                          vibe = v;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text('Location'),
                  DropdownButton<String>(
                    value: locationMode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'landmark', child: Text('Pick campus landmark')),
                      DropdownMenuItem(value: 'gps', child: Text('Use my GPS')),
                    ],
                    onChanged: (v) => setLocal(() => locationMode = v ?? 'landmark'),
                  ),
                  if (locationMode == 'landmark')
                    DropdownButton<String>(
                      value: landmarkId,
                      isExpanded: true,
                      items: [
                        for (final l in kUsfLandmarks)
                          DropdownMenuItem(value: l.id, child: Text(l.label)),
                      ],
                      onChanged: (v) => setLocal(() => landmarkId = v ?? landmarkId),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) return;

    await showLoadingOverlay<void>(
      context,
      Future<void>.delayed(const Duration(milliseconds: 600)),
    );

    if (!mounted) return;

    String locLabel;
    double? lat;
    double? lng;
    if (locationMode == 'landmark') {
      final l = kUsfLandmarks.firstWhere((e) => e.id == landmarkId);
      locLabel = l.label;
      lat = l.lat;
      lng = l.lng;
    } else {
      await _ensureLocationForApp();
      final pLat = _deviceLat;
      final pLng = _deviceLng;
      if (pLat == null || pLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read GPS location.')),
        );
        return;
      }
      if (!isOnUsfTampaCampus(pLat, pLng)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You appear to be outside USF Tampa campus. Pick a landmark or move on campus.'),
          ),
        );
        return;
      }
      locLabel = 'GPS on campus';
      lat = pLat;
      lng = pLng;
    }

    final meet = ActiveMeet(
      topic: topicCtrl.text.trim().isEmpty ? 'Campus meet' : topicCtrl.text.trim(),
      vibe: vibe,
      locationLabel: locLabel,
      lat: lat,
      lng: lng,
      maxPeople: maxPeople,
      durationMinutes: duration,
      filterPingOnly: pingOnly,
      filterFriendsOnly: friendsOnly,
      openAllMajors: allMajors,
      icebreakerQuestion: iceCtrl.text.trim().isEmpty ? null : iceCtrl.text.trim(),
    );

    context.read<AppSession>().startHosting(meet);

    topicCtrl.dispose();
    iceCtrl.dispose();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meet confirmed'),
        content: const Text('Your Meet is live.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    setState(() {});

    final uid = context.read<AppSession>().localUserId;
    try {
      await widget.profileRepository.setOnlinePresence(
        userId: uid,
        online: true,
        campusLocation: encodeMeetCampusLocation(topic: meet.topic, locationLabel: meet.locationLabel),
      );
    } catch (_) {}

    if (meet.icebreakerQuestion != null) {
      _toast(InAppNotification(message: 'Icebreaker set: ${meet.icebreakerQuestion}'));
    }
  }

  Future<void> _guestSeekWizard() async {
    final share = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share location?'),
        content: const Text(
          'Allow USF Meet to use your device location to match landmarks and compute distance?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (share != true || !mounted) return;

    try {
      final p = await showLoadingOverlay<Position>(
        context,
        _readCampusPosition(),
      );
      if (!mounted) return;
      setState(() {
        _deviceLat = p.latitude;
        _deviceLng = p.longitude;
      });

      final near = nearestLandmarkWithinMeters(p.latitude, p.longitude, 120);
      if (near != null) {
        final use = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Nearby landmark'),
            content: Text('Use "${near.label}" as your location?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
            ],
          ),
        );
        if (!mounted) return;
        if (use == true) {
          context.read<AppSession>().startSeeking(
                GuestSeekState(locationLabel: near.label, lat: near.lat, lng: near.lng),
              );
        } else {
          context.read<AppSession>().startSeeking(
                GuestSeekState(locationLabel: 'On campus', lat: p.latitude, lng: p.longitude),
              );
        }
      } else {
        context.read<AppSession>().startSeeking(
              GuestSeekState(locationLabel: 'On campus', lat: p.latitude, lng: p.longitude),
            );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<Position> _readCampusPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw StateError('Location services are disabled.');
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw StateError('Location permission denied.');
    }
    final p = await Geolocator.getCurrentPosition();
    if (!isOnUsfTampaCampus(p.latitude, p.longitude)) {
      throw StateError('You appear to be outside USF Tampa campus.');
    }
    return p;
  }

  String _vibeLabel(MeetVibe v) {
    return switch (v) {
      MeetVibe.coworking => 'Co-working',
      MeetVibe.studying => 'Studying',
      MeetVibe.brainstorming => 'Brainstorming',
      MeetVibe.socialGaming => 'Social / gaming',
    };
  }

  Future<void> _pingUser(Map<String, dynamic> row) async {
    final msgCtrl = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ping ${profileUsername(row) ?? 'peer'}'),
        content: TextField(
          controller: msgCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Quick question…'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (send != true || !mounted) return;

    final my = context.read<AppSession>();
    final toId = row['id']?.toString() ?? '';
    final ice = await widget.gemini.getIcebreaker(my.interests, profileInterests(row));

    try {
      await widget.profileRepository.sendPing(
        fromId: my.localUserId,
        toId: toId,
        message: msgCtrl.text.trim(),
        icebreaker: ice,
      );
      if (mounted) {
        _toast(InAppNotification(message: 'Ping sent to ${profileUsername(row) ?? 'peer'}.'));
      }
    } catch (e) {
      if (mounted) {
        _toast(InAppNotification(message: 'Failed to send ping: $e'));
      }
    }
    msgCtrl.dispose();
  }

  Future<void> _openProfile(Map<String, dynamic> row) async {
    final uid = row['id']?.toString() ?? '';
    final name = profileUsername(row) ?? 'User';
    final session = context.read<AppSession>();
    final myId = session.localUserId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: SizedBox(
          width: 340,
          height: 460,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              FriendEdge edge = uid == myId ? FriendEdge.friends : session.edgeFor(uid);

              Widget friendAction() {
                if (uid == myId) return const SizedBox.shrink();
                switch (edge) {
                  case FriendEdge.friends:
                    return IconButton(
                      tooltip: 'Remove friend',
                      onPressed: () {
                        session.removeFriend(uid);
                        setLocal(() => edge = session.edgeFor(uid));
                      },
                      icon: const Icon(Icons.person_remove_alt_1_outlined),
                    );
                  case FriendEdge.pendingOutgoing:
                    return IconButton(
                      tooltip: 'Tap to rescind',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Rescind request?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          session.rescindFriendRequest(uid);
                          setLocal(() => edge = session.edgeFor(uid));
                        }
                      },
                      icon: const Icon(Icons.hourglass_top),
                    );
                  case FriendEdge.pendingIncoming:
                    return const Icon(Icons.inbox_outlined);
                  case FriendEdge.none:
                    return IconButton(
                      tooltip: 'Add friend',
                      onPressed: () {
                        session.sendFriendRequest(uid);
                        _toast(
                          InAppNotification(
                            message: '$name received a friend request (simulated).',
                          ),
                        );
                        setLocal(() => edge = session.edgeFor(uid));
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                    );
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(diceBearBotttsPngUrl(name)),
                        onBackgroundImageError: (_, __) {},
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                      friendAction(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Interests', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(profileInterests(row).join(', ').isEmpty ? '\u2014' : profileInterests(row).join(', ')),
                  const SizedBox(height: 12),
                  const Text('Common meeting spots', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    profileLocationHistory(row).keys.take(6).join(', ').isEmpty
                        ? '\u2014'
                        : profileLocationHistory(row).keys.take(6).join(', '),
                  ),
                  const SizedBox(height: 12),
                  const Text('Socials', style: TextStyle(fontWeight: FontWeight.w700)),
                  ...profileSocials(row).entries.map((e) => Text('${e.key}: ${e.value}')),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _maybeJoinHost(Map<String, dynamic> row) async {
    if (row['id'] == null) return;
    final decoded = decodeMeetCampus(row['campus_location'] as String?);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Meet?'),
        content: const Text('Do you want to join this Meet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _inMeeting = true;
      _joinedTopic = decoded?.topic ?? '${profileUsername(row) ?? 'Host'}\u2019s Meet';
      _joinedMax = 8;
      _joinedCount = 3;
    });
  }

  Widget _rowAvatar(Map<String, dynamic> row) {
    final name = profileUsername(row) ?? 'anon';
    return GestureDetector(
      onTap: () => _openProfile(row),
      child: CircleAvatar(
        backgroundImage: NetworkImage(diceBearBotttsPngUrl(name)),
        onBackgroundImageError: (_, __) {},
      ),
    );
  }

  String _locationForRow(Map<String, dynamic> row, AppSession session) {
    final meet = decodeMeetCampus(row['campus_location'] as String?);
    if (meet != null) return meet.location;
    if (!session.shareGeoPublic) return '???';
    return profileLocationLabel(row);
  }

  Widget _feedList(List<Map<String, dynamic>> users) {
    final session = context.watch<AppSession>();
    final myId = session.localUserId;
    final filtered = users.where((r) {
      if (r['id']?.toString() == myId) return false;
      if (!profileIsOnline(r)) return false;
      return decodeMeetCampus(r['campus_location'] as String?) != null;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No active meetups right now.'));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final row = filtered[i];
        final meet = decodeMeetCampus(row['campus_location'] as String?);
        final name = profileUsername(row) ?? 'Unknown';
        final location = meet?.location ?? profileLocationLabel(row);
        final topic = meet?.topic ?? 'Looking for connections';
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => meet != null ? _maybeJoinHost(row) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _rowAvatar(row),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(location, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(topic),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ping',
                    onPressed: () => _pingUser(row),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _friendsList(List<Map<String, dynamic>> users) {
    final session = context.watch<AppSession>();

    final friends = users.where((r) {
      final id = r['id']?.toString();
      if (id == null) return false;
      return session.edgeFor(id) == FriendEdge.friends;
    }).toList();

    if (friends.isEmpty) {
      return const Center(child: Text('No friends yet, send requests from profiles.'));
    }

    return ListView.separated(
      itemCount: friends.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final row = friends[i];
        return ListTile(
          leading: _rowAvatar(row),
          title: Text(profileUsername(row) ?? 'Friend'),
          subtitle: Text(_locationForRow(row, session)),
          onTap: () => _openProfile(row),
        );
      },
    );
  }

  Widget _meetingList() {
    final session = context.watch<AppSession>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(_joinedTopic, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (var k = 0; k < _joinedCount; k++)
          ListTile(
            leading: CircleAvatar(child: Text('$k')),
            title: Text('Guest ${k + 1}'),
            subtitle: const Text('In this Meet (demo roster)'),
          ),
        if (session.hostingMeet?.icebreakerQuestion != null)
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Icebreaker'),
            subtitle: Text(session.hostingMeet!.icebreakerQuestion!),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0E),
      body: SafeArea(
        child: InAppNotificationHost(
          key: _notificationHostKey,
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    color: UsfTheme.green,
                    padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6),
                    child: Row(
                      children: [
                        const Expanded(child: BrandHeaderDashboard(showDashboardTitle: true)),
                        IconButton(
                          tooltip: 'Exit',
                          onPressed: _exitAppDialog,
                          icon: const Icon(Icons.sensor_door_outlined, color: Colors.white),
                        ),
                        IconButton(
                          tooltip: 'Log out',
                          onPressed: _logoutDialog,
                          icon: const Icon(Icons.logout, color: Colors.white),
                        ),
                        IconButton(
                          tooltip: 'Friends',
                          onPressed: () => setState(() => _friendsMode = !_friendsMode),
                          icon: Icon(
                            _friendsMode ? Icons.people : Icons.person_outline,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: session.plusDismissed ? 'End' : 'Host / Guest',
                          onPressed: _plusFlow,
                          icon: Transform.rotate(
                            angle: session.plusDismissed ? 0.785398 : 0,
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                        RotationTransition(
                          turns: Tween(begin: 0.0, end: 0.33).animate(_gearCtrl),
                          child: IconButton(
                            tooltip: 'Settings',
                            onPressed: () async {
                              if (_settingsOpen) {
                                await _gearCtrl.reverse();
                                setState(() => _settingsOpen = false);
                              } else {
                                await _gearCtrl.forward();
                                setState(() => _settingsOpen = true);
                              }
                            },
                            icon: const Icon(Icons.settings, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (session.seekingHost != null)
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      offset: Offset.zero,
                      child: Material(
                        color: const Color(0xFF13221C),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Your seek location', style: TextStyle(fontWeight: FontWeight.w700)),
                                    Text(session.seekingHost!.locationLabel),
                                    if (_deviceLat != null &&
                                        _deviceLng != null &&
                                        session.seekingHost!.lat != null &&
                                        session.seekingHost!.lng != null)
                                      Text(
                                        '${haversineMeters(
                                          _deviceLat!,
                                          _deviceLng!,
                                          session.seekingHost!.lat!,
                                          session.seekingHost!.lng!,
                                        ).round()} m away',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _openMaps(
                                  session.seekingHost!.locationLabel,
                                  session.seekingHost!.lat,
                                  session.seekingHost!.lng,
                                ),
                                child: const Text('Maps'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ClipRect(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: widget.profileRepository.profilesStream(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final users = snap.data!.map((e) => Map<String, dynamic>.from(e)).toList();

                          if (_inMeeting) return _meetingList();

                          return Stack(
                            children: [
                              IgnorePointer(
                                ignoring: _friendsMode,
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                  offset: _friendsMode ? const Offset(-1, 0) : Offset.zero,
                                  child: _feedList(users),
                                ),
                              ),
                              IgnorePointer(
                                ignoring: !_friendsMode,
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                  offset: _friendsMode ? Offset.zero : const Offset(1, 0),
                                  child: _friendsList(users),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    color: const Color(0xFF13221C),
                    child: Center(
                      child: _inMeeting
                          ? Text(
                              '$_joinedCount / $_joinedMax',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            )
                          : const Text('\u{1F9AC}', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                ],
              ),
              if (_settingsOpen) ...[
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await _gearCtrl.reverse();
                            setState(() => _settingsOpen = false);
                          },
                          child: Container(color: Colors.black45),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        width: MediaQuery.sizeOf(context).width * 0.78,
                        color: const Color(0xFF101010),
                        child: _SettingsPanel(
                          onClose: () async {
                            await _gearCtrl.reverse();
                            setState(() => _settingsOpen = false);
                          },
                          profileRepository: widget.profileRepository,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.onClose,
    required this.profileRepository,
  });

  final VoidCallback onClose;
  final ProfileRepository profileRepository;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late final TextEditingController _interestCtrl;

  static const _socialKeys = ['discord', 'instagram', 'linkedin', 'x'];

  final Map<String, TextEditingController> _socialCtrls = {
    for (final k in _socialKeys) k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    final s = context.read<AppSession>();
    _interestCtrl = TextEditingController(text: s.interests.join(', '));
    for (final e in s.socials.entries) {
      if (_socialCtrls[e.key] != null) _socialCtrls[e.key]!.text = e.value;
    }
  }

  @override
  void dispose() {
    _interestCtrl.dispose();
    for (final c in _socialCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<AppSession>();
    final interests = _interestCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final socials = <String, String>{};
    for (final e in _socialCtrls.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) socials[e.key] = v;
    }

    session.setInterests(interests);
    session.setSocials(socials);
    session.setShareGeoPublic(session.shareGeoPublic);
    session.setShowRealName(session.showRealName);

    final uid = session.localUserId;
    try {
      await widget.profileRepository.syncSettings(
        userId: uid,
        interests: interests,
        socials: socials,
        shareGeoPublic: session.shareGeoPublic,
        showRealName: session.showRealName,
      );
    } catch (_) {}
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _interestCtrl,
            style: UsfTheme.inputTextStyle,
            decoration: const InputDecoration(labelText: 'Interests (comma separated)'),
          ),
          const SizedBox(height: 12),
          const Text('Socials'),
          for (final k in _socialKeys)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _socialCtrls[k]!,
                style: UsfTheme.inputTextStyle,
                decoration: InputDecoration(labelText: k),
              ),
            ),
          SwitchListTile(
            title: const Text('Public campus location'),
            subtitle: const Text('If off, others see "???" (the app may still use GPS privately).'),
            value: session.shareGeoPublic,
            onChanged: session.setShareGeoPublic,
          ),
          SwitchListTile(
            title: const Text('Show real name publicly'),
            value: session.showRealName,
            onChanged: session.setShowRealName,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save & close')),
        ],
      ),
    );
  }
}
