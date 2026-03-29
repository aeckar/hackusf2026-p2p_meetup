import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/gemini_service.dart';
import 'services/profile_repository.dart';
import 'state/app_session.dart';
import 'theme/usf_theme.dart';
import 'widgets/slide_route_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pemnwlmnxjgpqognkrwf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBlbW53bG1ueGpncHFvZ25rcndmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3MTY4NDcsImV4cCI6MjA5MDI5Mjg0N30.8bldTDZsfNZVe8S8mKHwKfoSKqEskV2VtbgRQ09MPb0',
  );

  final supabase = Supabase.instance.client;
  final profiles = ProfileRepository(supabase);
  final gemini = GeminiService('AIzaSyD4Pc2yIUrS3a3gUWTOeOQTe250xok-8Cg');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSession(),
      child: MaterialApp(
        title: 'USF Meet',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: UsfTheme.green,
          colorScheme: ColorScheme.fromSeed(
              seedColor: UsfTheme.green, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: AuthNavigatorShell(
          profileRepository: profiles,
          gemini: gemini,
          supabase: supabase,
        ),
      ),
    ),
  );
}

class AuthNavigatorShell extends StatelessWidget {
  const AuthNavigatorShell({
    super.key,
    required this.profileRepository,
    required this.gemini,
    required this.supabase,
  });

  final ProfileRepository profileRepository;
  final GeminiService gemini;
  final SupabaseClient supabase;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final loggedIn = session.localUserId.isNotEmpty;

    return Navigator(
      pages: [
        if (!loggedIn)
          SlideFromRightPage(
            key: const ValueKey<String>('auth'),
            child: AuthScreen(profileRepository: profileRepository),
          )
        else
          SlideFromRightPage(
            key: ValueKey<String>('dash-${session.localUserId}'),
            child: DashboardScreen(
              supabase: supabase,
              profileRepository: profileRepository,
              gemini: gemini,
              onLogout: () async => session.clearForLogout(),
            ),
          ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}
