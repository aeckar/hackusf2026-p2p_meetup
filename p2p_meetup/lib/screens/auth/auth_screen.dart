import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/profile_repository.dart';
import '../../state/app_session.dart';
import '../../theme/usf_theme.dart';
import '../../utils/profile_parse.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/loading_overlay.dart';

String _authUserMessage(Object e) {
  if (e is AuthWeakPasswordException) {
    return 'Password is too weak.';
  }
  if (e is AuthException && e.code == 'weak_password') {
    return 'Password is too weak.';
  }
  if (e is AuthException) {
    return e.message;
  }
  return e.toString();
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.supabase, required this.profileRepository});

  final SupabaseClient supabase;
  final ProfileRepository profileRepository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showSignup = false;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  final _suUser = TextEditingController();
  final _suEmail = TextEditingController();
  final _suEmail2 = TextEditingController();
  final _suPass = TextEditingController();
  final _suPass2 = TextEditingController();

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPass.dispose();
    _suUser.dispose();
    _suEmail.dispose();
    _suEmail2.dispose();
    _suPass.dispose();
    _suPass2.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final email = _loginEmail.text.trim();
    final pass = _loginPass.text;
    if (email.isEmpty || pass.isEmpty) return;

    try {
      await showLoadingOverlay<void>(context, _runLogin(email: email, password: pass));
    } catch (e) {
      if (!mounted) return;
      final weak = e is AuthWeakPasswordException ||
          (e is AuthException && e.code == 'weak_password');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            weak ? 'Password is too weak.' : 'Login failed: ${_authUserMessage(e)}',
          ),
        ),
      );
    }
  }

  Future<void> _runLogin({required String email, required String password}) async {
    await widget.supabase.auth.signInWithPassword(email: email, password: password);
    final uid = widget.supabase.auth.currentUser?.id;
    final session = Provider.of<AppSession>(context, listen: false);
    if (uid == null) return;
    session.setLocalUserId(uid);
    await widget.profileRepository.hydrateSession(
      userId: uid,
      onRow: (row) {
        session.currentUsername = profileUsername(row) ?? '';
        session.setInterests(profileInterests(row));
        session.setSocials(profileSocials(row));
        session.setShowRealName(profileRealNamePublic(row));
      },
    );
  }

  Future<void> _submitSignup() async {
    final username = _suUser.text.trim();
    final email = _suEmail.text.trim();
    final email2 = _suEmail2.text.trim();
    final p1 = _suPass.text;
    final p2 = _suPass2.text;

    if (username.isEmpty || email.isEmpty || p1.isEmpty) return;
    if (email != email2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emails do not match.')),
      );
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    try {
      await showLoadingOverlay<void>(context, _runSignup(username: username, email: email, password: p1));
    } catch (e) {
      if (!mounted) return;
      final weak = e is AuthWeakPasswordException ||
          (e is AuthException && e.code == 'weak_password');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            weak ? 'Password is too weak.' : 'Sign up failed: ${_authUserMessage(e)}',
          ),
        ),
      );
    }
  }

  Future<void> _runSignup({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await widget.supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    final uid = res.user?.id ?? widget.supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Could not create user (check email confirmation settings).');
    }
    await widget.profileRepository.upsertAfterSignup(
      userId: uid,
      username: username,
      email: email,
    );
    final session = Provider.of<AppSession>(context, listen: false);
    session.setLocalUserId(uid);
    session.currentUsername = username;
    session.setInterests([]);
    session.setSocials({});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UsfTheme.green,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BrandHeader(),
            if (!_showSignup)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Chat with your peers!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (_showSignup) const SizedBox(height: 36),
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      offset: _showSignup ? const Offset(-1, 0) : Offset.zero,
                      child: _loginColumn(context),
                    ),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      offset: _showSignup ? Offset.zero : const Offset(1, 0),
                      child: _signupColumn(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginColumn(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            controller: _loginEmail,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('username / email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loginPass,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('password'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitLogin(),
          ),
          const SizedBox(height: 16),
          _orDivider(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => setState(() => _showSignup = true),
              child: const Text('Sign up'),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: UsfTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submitLogin,
              child: const Text('Log in'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _signupColumn(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            controller: _suUser,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('username'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _suEmail,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _suEmail2,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('confirm email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _suPass,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('password'),
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _suPass2,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('confirm password'),
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => setState(() => _showSignup = false),
              child: const Text('Log in'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: UsfTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submitSignup,
              child: const Text('Create account'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.35))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.35))),
      ],
    );
  }
}
