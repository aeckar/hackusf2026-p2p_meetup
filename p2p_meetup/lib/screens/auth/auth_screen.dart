import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/profile_repository.dart';
import '../../state/app_session.dart';
import '../../theme/usf_theme.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/loading_overlay.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.profileRepository});

  final ProfileRepository profileRepository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showSignup = false;

  final _loginUser = TextEditingController();
  final _loginPass = TextEditingController();

  final _suUser = TextEditingController();
  final _suEmail = TextEditingController();
  final _suPass = TextEditingController();
  final _suPass2 = TextEditingController();

  @override
  void dispose() {
    _loginUser.dispose();
    _loginPass.dispose();
    _suUser.dispose();
    _suEmail.dispose();
    _suPass.dispose();
    _suPass2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submitLogin() async {
    final username = _loginUser.text.trim();
    final pass = _loginPass.text;
    if (username.isEmpty || pass.isEmpty) return;

    try {
      await showLoadingOverlay<void>(context, _runLogin(username: username, password: pass));
    } catch (e) {
      _snack('Login failed: $e');
    }
  }

  Future<void> _runLogin({required String username, required String password}) async {
    final row = await widget.profileRepository.loginWithCredentials(
      username: username,
      password: password,
    );
    if (row == null) throw Exception('Incorrect username or password.');
    if (!mounted) return;
    final session = Provider.of<AppSession>(context, listen: false);
    session.setLocalUserId(row['id'] as String);
    session.currentUsername = username;
    session.setInterests(List<String>.from(row['interests'] as List? ?? []));
    final socials = row['socials'];
    session.setSocials(socials is Map ? socials.map((k, v) => MapEntry('$k', '$v')) : {});
    session.setShowRealName(row['is_real_name_public'] == true);
  }

  Future<void> _submitSignup() async {
    final username = _suUser.text.trim();
    final email = _suEmail.text.trim();
    final p1 = _suPass.text;
    final p2 = _suPass2.text;

    if (username.isEmpty || p1.isEmpty) return;
    if (p1 != p2) {
      _snack('Passwords do not match.');
      return;
    }

    try {
      await showLoadingOverlay<void>(
          context, _runSignup(username: username, email: email, password: p1));
    } catch (e) {
      _snack('Sign up failed: $e');
    }
  }

  Future<void> _runSignup({
    required String username,
    required String email,
    required String password,
  }) async {
    final uid = await widget.profileRepository.createAccount(
      username: username,
      email: email,
      password: password,
    );
    if (!mounted) return;
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
                  'Connect with Your peers!',
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
            controller: _loginUser,
            style: UsfTheme.inputTextStyle,
            decoration: UsfTheme.inputDeco('username'),
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
            decoration: UsfTheme.inputDeco('email (optional)'),
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
