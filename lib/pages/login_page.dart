import 'package:flutter/material.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static final Map<String, String> _users = {'admin': '1234'};

  static const _ink = Color(0xFF172B3A);
  static const _muted = Color(0xFF71818C);
  static const _teal = Color(0xFF087F75);
  static const _mint = Color(0xFFB8F2D8);
  static const _canvas = Color(0xFFF3F7F5);

  bool _isSignUp = false;
  bool _hidePassword = true;

  final _loginUser = TextEditingController();
  final _loginPass = TextEditingController();
  final _signUser = TextEditingController();
  final _signPass = TextEditingController();
  final _signConfirm = TextEditingController();

  @override
  void dispose() {
    _loginUser.dispose();
    _loginPass.dispose();
    _signUser.dispose();
    _signPass.dispose();
    _signConfirm.dispose();
    super.dispose();
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _login() {
    final user = _loginUser.text.trim();
    final pass = _loginPass.text;
    if (user.isEmpty || pass.isEmpty) {
      _msg('Please enter username and password');
      return;
    }
    if (_users[user] == pass) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(username: user)),
      );
    } else {
      _msg('Invalid username or password');
    }
  }

  void _signUp() {
    final user = _signUser.text.trim();
    final pass = _signPass.text;
    if (user.isEmpty || pass.isEmpty || _signConfirm.text.isEmpty) {
      _msg('Please fill in all fields');
      return;
    }
    if (pass != _signConfirm.text) {
      _msg('Passwords do not match');
      return;
    }
    if (_users.containsKey(user)) {
      _msg('Username already exists');
      return;
    }
    setState(() {
      _users[user] = pass;
      _loginUser.text = user;
      _loginPass.clear();
      _signUser.clear();
      _signPass.clear();
      _signConfirm.clear();
      _isSignUp = false;
    });
    _msg('Account created! You can now log in.');
  }

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
                ? 'Set up your workspace access in just a moment.'
                : 'Sign in to pick up where your team left off.',
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 30),
          _fieldLabel('USERNAME'),
          const SizedBox(height: 9),
          TextField(
            controller: signUp ? _signUser : _loginUser,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: _fieldDecoration(
              'Enter your username',
              Icons.person_outline,
            ),
          ),
          const SizedBox(height: 19),
          _fieldLabel('PASSWORD'),
          const SizedBox(height: 9),
          TextField(
            controller: signUp ? _signPass : _loginPass,
            obscureText: _hidePassword,
            textInputAction: signUp
                ? TextInputAction.next
                : TextInputAction.done,
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
              onPressed: signUp ? _signUp : _login,
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
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
          if (!signUp) ...[
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7F5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Demo: admin / 1234',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ),
          ],
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
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
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
      height: 620,
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
