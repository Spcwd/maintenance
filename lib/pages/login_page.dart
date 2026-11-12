import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/account_repository.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _ink = Color(0xFF172B3A);
  static const _muted = Color(0xFF71818C);
  static const _teal = Color(0xFF087F75);
  static const _mint = Color(0xFFB8F2D8);
  static const _canvas = Color(0xFFF3F7F5);

  final _repo = AccountRepository();

  bool _isSignUp = false;
  bool _hidePassword = true;
  bool _busy = false;

  // True while we check whether the person is already signed in.
  late bool _checking = Supabase.instance.client.auth.currentSession != null;

  final _loginUsername = TextEditingController();
  final _loginPass = TextEditingController();
  final _signName = TextEditingController();
  final _signUsername = TextEditingController();
  final _signPass = TextEditingController();
  final _signConfirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_checking) _enterWithSession();
  }

  @override
  void dispose() {
    _loginUsername.dispose();
    _loginPass.dispose();
    _signName.dispose();
    _signUsername.dispose();
    _signPass.dispose();
    _signConfirm.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String _friendly(String m) {
    final l = m.toLowerCase();
    if (l.contains('invalid login')) return 'Invalid username or password';
    if (l.contains('database error saving new user')) {
      if (l.contains('column "email" of relation "profiles" does not exist')) {
        return 'Your Supabase profile trigger still expects profiles.email, but your table has no email column. Rerun supabase/migrations/20261111000000_add_username_to_profiles.sql in the SQL Editor to update it.';
      }
      return 'Supabase could not save the new account. Run the username migration in supabase/migrations/20261111000000_add_username_to_profiles.sql in the Supabase SQL Editor. If it is already applied, check Supabase Logs > Postgres for the auth.users trigger error.';
    }
    if (l.contains('email signups are disabled') ||
        l.contains('signup is disabled') ||
        l.contains('signups not allowed')) {
      return 'Username accounts still use a private Supabase email alias. In Supabase, enable new signups and the Email provider, then turn off email confirmation. Users will continue to enter only a username here.';
    }
    if (l.contains('email not confirmed')) {
      return 'Email confirmation is enabled in Supabase. Turn off "Confirm email"; users do not need an email address.';
    }
    if (l.contains('already registered') || l.contains('duplicate key')) {
      return 'That username is already taken';
    }
    if (l.contains('password') && l.contains('6')) {
      return 'Password must be at least 6 characters';
    }
    return m;
  }

  /// Signed in with Supabase -> check approval and open the right page.
  Future<void> _enterWithSession() async {
    try {
      final profile = await _repo.myProfile();
      if (!mounted) return;

      if (profile == null) {
        await _failAndSignOut(
            'Your account could not be found. Please contact the admin.');
        return;
      }
      if (profile.status == 'pending') {
        await _failAndSignOut('Your account is waiting for admin approval.');
        return;
      }
      if (profile.status == 'blocked') {
        await _failAndSignOut(
            'Your account has been blocked. Please contact the admin.');
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            username: profile.displayName,
            profile: profile,
          ),
        ),
      );
    } catch (e) {
      await _failAndSignOut('Could not sign in: $e');
    }
  }

  Future<void> _failAndSignOut(String message) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _checking = false;
    });
    _msg(message);
  }

  Future<void> _login() async {
    if (_busy) return;
    final username = _loginUsername.text.trim().toLowerCase();
    final pass = _loginPass.text;
    if (username.isEmpty || pass.isEmpty) {
      _msg('Please enter your username and password');
      return;
    }

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _usernameEmail(username),
        password: pass,
      );
      await _enterWithSession();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _msg(_friendly(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _msg('Could not connect. Please check your internet and try again.');
    }
  }

  Future<void> _signUp() async {
    if (_busy) return;
    final name = _signName.text.trim();
    final username = _signUsername.text.trim().toLowerCase();
    final pass = _signPass.text;

    if (name.isEmpty ||
        username.isEmpty ||
        pass.isEmpty ||
        _signConfirm.text.isEmpty) {
      _msg('Please fill in all fields');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      _msg(
          'Username must be 3-24 characters: letters, numbers, or underscores');
      return;
    }
    if (pass.length < 6) {
      _msg('Password must be at least 6 characters');
      return;
    }
    if (pass != _signConfirm.text) {
      _msg('Passwords do not match');
      return;
    }

    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      final res = await auth.signUp(
        email: _usernameEmail(username),
        password: pass,
        data: {'full_name': name, 'username': username},
      );

      final message = res.session == null
          ? 'Supabase did not start a session. Enable new signups and the Email provider, and turn off email confirmation in Supabase.'
          : 'Account created! Please wait for the admin to approve it before you sign in.';
      if (res.session != null) await auth.signOut();

      if (!mounted) return;
      setState(() {
        _busy = false;
        _loginUsername.text = username;
        _loginPass.clear();
        _signName.clear();
        _signUsername.clear();
        _signPass.clear();
        _signConfirm.clear();
        _isSignUp = false;
      });
      _msg(message);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _msg(_friendly(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _msg('Could not create the account: $e');
    }
  }

  String _usernameEmail(String username) => '$username@maintenance.invalid';

  InputDecoration _fieldDecoration(
    String hint,
    IconData icon, {
    bool password = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA7AE), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF82939B)),
      suffixIcon: password
          ? IconButton(
              tooltip: _hidePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: const Color(0xFF82939B),
              ),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFF5F8F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7EEEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
    );
  }

  Widget _authForm() {
    final signUp = _isSignUp;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey(signUp),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            signUp ? 'Create your account' : 'Welcome back',
            style: const TextStyle(
              color: _ink,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            signUp
                ? 'The admin will approve your account before you can sign in.'
                : 'Sign in to pick up where your team left off.',
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 30),
          if (signUp) ...[
            _fieldLabel('FULL NAME'),
            const SizedBox(height: 9),
            TextField(
              controller: _signName,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: _fieldDecoration(
                'Enter your full name',
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: 19),
          ],
          _fieldLabel('USERNAME'),
          const SizedBox(height: 9),
          TextField(
            controller: signUp ? _signUsername : _loginUsername,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: _fieldDecoration(
              'Enter your username',
              Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 19),
          _fieldLabel('PASSWORD'),
          const SizedBox(height: 9),
          TextField(
            controller: signUp ? _signPass : _loginPass,
            obscureText: _hidePassword,
            textInputAction:
                signUp ? TextInputAction.next : TextInputAction.done,
            autofillHints: [
              signUp ? AutofillHints.newPassword : AutofillHints.password,
            ],
            onSubmitted: signUp ? null : (_) => _login(),
            decoration: _fieldDecoration(
              'Enter your password',
              Icons.lock_outline,
              password: true,
            ),
          ),
          if (signUp) ...[
            const SizedBox(height: 19),
            _fieldLabel('CONFIRM PASSWORD'),
            const SizedBox(height: 9),
            TextField(
              controller: _signConfirm,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signUp(),
              decoration: _fieldDecoration(
                'Re-enter your password',
                Icons.lock_reset_outlined,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _busy ? null : (signUp ? _signUp : _login),
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _teal.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          signUp ? 'Create account' : 'Sign in',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  signUp ? 'Already have an account? ' : 'New to Maintenance? ',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _isSignUp = !_isSignUp),
                  style: TextButton.styleFrom(
                    foregroundColor: _teal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    signUp ? 'Sign in' : 'Create an account',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF526670),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _brandMark({bool light = false}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: light ? Colors.white.withValues(alpha: 0.12) : _teal,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        Icons.handyman_rounded,
        color: light ? _mint : Colors.white,
        size: 24,
      ),
    );
  }

  Widget _brandPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF173B46), Color(0xFF102B38)],
              ),
            ),
          ),
          Positioned(
            right: -100,
            top: -90,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: -55,
            top: -45,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mint.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 42, 38, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _brandMark(light: true),
                    const SizedBox(width: 12),
                    const Text(
                      'MAINTENANCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'Good work starts\nwith a clear view.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    height: 1.16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Keep every task, repair, and team update moving in one place.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 34),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _mint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.task_alt_rounded,
                          color: _mint,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your work, in good hands',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Simple tools. Smoother days.',
                              style: TextStyle(
                                color: Color(0xFFB5C9CB),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_outward_rounded,
                        color: _mint,
                        size: 17,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'A better day on every job.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1050, minHeight: 620),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193C42).withValues(alpha: 0.12),
            blurRadius: 45,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          // Taller when creating an account (more fields).
          height: _isSignUp ? 720 : 620,
          child: Row(
            children: [
              Expanded(flex: 44, child: _brandPanel()),
              Expanded(
                flex: 56,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 62,
                      vertical: 42,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: _authForm(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
              child: Row(
                children: [
                  _brandMark(),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAINTENANCE',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Work made easier',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8EFEB)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF193C42).withValues(alpha: 0.07),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: _authForm(),
            ),
            const SizedBox(height: 22),
            const Text(
              'A better day on every job.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Already signed in? Show a spinner while we open the right page.
    if (_checking) {
      return const Scaffold(
        backgroundColor: _canvas,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final verticalPadding = isDesktop ? 28.0 : 30.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 20,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - verticalPadding * 2)
                      .clamp(0.0, double.infinity)
                      .toDouble(),
                ),
                child: Center(
                  child: isDesktop ? _desktopLayout() : _mobileLayout(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
