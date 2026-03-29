import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/gemini_service.dart';
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

  final supabase = Supabase.instance.client;
  final profiles = ProfileRepository(supabase);
  final gemini = GeminiService('AIzaSyAhLbOKzIzncwEFVg2Y6V7C6Hwfd7IXmrI');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSession(),
      child: HackUSFApp(
        supabase: supabase,
        profileRepository: profiles,
        gemini: gemini,
      ),
    ),
  );
}

class HackUSFApp extends StatelessWidget {
  const HackUSFApp({
    super.key,
    required this.supabase,
    required this.profileRepository,
    required this.gemini,
  });

  final SupabaseClient supabase;
  final ProfileRepository profileRepository;
  final GeminiService gemini;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USF Meet',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: UsfTheme.green,
        colorScheme: ColorScheme.fromSeed(seedColor: UsfTheme.green, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final signedIn = supabase.auth.currentSession != null;
          if (!signedIn) {
            return AuthScreen(supabase: supabase, profileRepository: profileRepository);
          }
          return DashboardScreen(
            supabase: supabase,
            profileRepository: profileRepository,
            gemini: gemini,
          );
        },
      ),
    );
  }
}
