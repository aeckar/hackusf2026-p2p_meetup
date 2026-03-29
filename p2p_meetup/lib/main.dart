import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'services/gemini_service.dart';
import 'services/local_profile_id.dart';
import 'services/profile_repository.dart';
import 'state/app_session.dart';
import 'theme/usf_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pemnwlmnxjgpqognkrwf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBlbW53bG1ueGpncHFvZ25rcndmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3MTY4NDcsImV4cCI6MjA5MDI5Mjg0N30.8bldTDZsfNZVe8S8mKHwKfoSKqEskV2VtbgRQ09MPb0',
  );

  final localUserId = await loadOrCreateLocalProfileId();
  final supabase = Supabase.instance.client;
  final profiles = ProfileRepository(supabase);
  final gemini = GeminiService('AIzaSyAhLbOKzIzncwEFVg2Y6V7C6Hwfd7IXmrI');

  runApp(
    HackUSFAppShell(
      initialUserId: localUserId,
      profileRepository: profiles,
      gemini: gemini,
    ),
  );
}

class HackUSFAppShell extends StatefulWidget {
  const HackUSFAppShell({
    super.key,
    required this.initialUserId,
    required this.profileRepository,
    required this.gemini,
  });

  final String initialUserId;
  final ProfileRepository profileRepository;
  final GeminiService gemini;

  @override
  State<HackUSFAppShell> createState() => _HackUSFAppShellState();
}

class _HackUSFAppShellState extends State<HackUSFAppShell> {
  late AppSession _session;

  @override
  void initState() {
    super.initState();
    _session = AppSession(localUserId: widget.initialUserId);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final newId = await replaceLocalProfileId();
    if (!mounted) return;
    final old = _session;
    setState(() {
      _session = AppSession(localUserId: newId);
    });
    old.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppSession>.value(
      value: _session,
      child: MaterialApp(
        title: 'USF Meet',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: UsfTheme.green,
          colorScheme: ColorScheme.fromSeed(seedColor: UsfTheme.green, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: DashboardScreen(
          key: ValueKey(_session.localUserId),
          profileRepository: widget.profileRepository,
          gemini: widget.gemini,
          onLogout: _logout,
        ),
      ),
    );
  }
}
