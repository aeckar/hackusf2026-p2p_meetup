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
  final gemini = GeminiService('AIzaSyAhLbOKzIzncwEFVg2Y6V7C6Hwfd7IXmrI');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSession(),
      child: MaterialApp(
        title: 'USF Meet',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: UsfTheme.green,
          colorScheme: ColorScheme.fromSeed(seedColor: UsfTheme.green, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: AuthNavigatorShell(
          supabase: supabase,
          profileRepository: profiles,
          gemini: gemini,
        ),
      ),
    ),
  );
}

class AuthNavigatorShell extends StatefulWidget {
  const AuthNavigatorShell({
    super.key,
    required this.supabase,
    required this.profileRepository,
    required this.gemini,
  });

  final SupabaseClient supabase;
  final ProfileRepository profileRepository;
  final GeminiService gemini;

  @override
  State<AuthNavigatorShell> createState() => _AuthNavigatorShellState();
}

class _AuthNavigatorShellState extends State<AuthNavigatorShell> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: widget.supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = widget.supabase.auth.currentUser;

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final s = context.read<AppSession>();
            if (s.localUserId.isNotEmpty) {
              s.clearForLogout();
            }
          });
        }

        return Navigator(
          pages: [
            if (user == null)
              SlideFromRightPage(
                key: const ValueKey<String>('auth'),
                child: AuthScreen(
                  supabase: widget.supabase,
                  profileRepository: widget.profileRepository,
                ),
              )
            else
              SlideFromRightPage(
                key: ValueKey<String>('dash-${user.id}'),
                child: DashboardScreen(
                  supabase: widget.supabase,
                  profileRepository: widget.profileRepository,
                  gemini: widget.gemini,
                  onLogout: () => widget.supabase.auth.signOut(),
                ),
              ),
          ],
          onPopPage: (route, result) => route.didPop(result),
        );
      },
    );
  }
}
