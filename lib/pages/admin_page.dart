import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maintenance_request.dart' show formatDateTime;
import '../models/profile.dart';
import '../services/account_repository.dart';
import 'login_page.dart';

/// Account-management section available only to administrators.
class AdminHomePage extends StatefulWidget {
  final Profile profile;
  const AdminHomePage({super.key, required this.profile});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static const _teal = Color(0xFF087F75);
  static const _tealLight = Color(0xFF14A89A);
  static const _navy = Color(0xFF173B46);
  static const _navy2 = Color(0xFF102B38);
  static const _mint = Color(0xFFB8F2D8);
  static const _canvas = Color(0xFFF3F7F5);
  static const _ink = Color(0xFF172B3A);
  static const _muted = Color(0xFF71818C);
  static const _line = Color(0xFFE7EEEA);
  static const _cardLine = Color(0xFFE8EFEB);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);

  final _repo = AccountRepository();
  final _searchCtrl = TextEditingController();

  List<Profile> _accounts = [];
  bool _loading = true;
  String? _error;
  String _filter = 'Pending'; // Pending | Approved | Blocked | All
  String _search = '';
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  Future<void> _load({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _repo.fetchAll();
      if (!mounted) return;
      setState(() {
        _accounts = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _snack(String text) {
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

  int _count(String status) =>
      _accounts.where((a) => a.status == status).length;

  List<Profile> get _visible {
    final q = _search.toLowerCase();
    return _accounts.where((a) {
      final okStatus = _filter == 'All' || a.status == _filter.toLowerCase();
      final okSearch =
          q.isEmpty ||
          a.fullName.toLowerCase().contains(q) ||
          a.username.toLowerCase().contains(q) ||
          a.email.toLowerCase().contains(q);
      return okStatus && okSearch;
    }).toList();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    required Color color,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _setStatus(Profile p, String status, String doneMsg) async {
    setState(() => _busy.add(p.id));
    try {
      await _repo.setStatus(p.id, status);
      if (!mounted) return;
      setState(() {
        _accounts = _accounts
            .map((a) => a.id == p.id ? a.copyWith(status: status) : a)
            .toList();
      });
      _snack(doneMsg);
    } catch (e) {
      _snack('Action failed: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  Future<void> _approve(Profile p) =>
      _setStatus(p, 'approved', '${p.displayName} was approved');

  Future<void> _unblock(Profile p) =>
      _setStatus(p, 'approved', '${p.displayName} was unblocked');

  Future<void> _block(Profile p) async {
    final ok = await _confirm(
      title: 'Block this account?',
      message:
          '${p.displayName} will not be able to sign in until you unblock them.',
      action: 'Block',
      color: _amber,
    );
    if (ok) await _setStatus(p, 'blocked', '${p.displayName} was blocked');
  }

  Future<void> _delete(Profile p) async {
    final ok = await _confirm(
      title: 'Delete this account?',
      message:
          '${p.displayName} (@${p.username}) will be permanently removed. This cannot be undone.',
      action: 'Delete',
      color: _red,
    );
    if (!ok) return;

    setState(() => _busy.add(p.id));
    try {
      await _repo.deleteAccount(p.id);
      if (!mounted) return;
      setState(() => _accounts = _accounts.where((a) => a.id != p.id).toList());
      _snack('${p.displayName} was deleted');
    } catch (e) {
      _snack('Could not delete: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  Future<void> _changePassword(Profile p) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var hidePassword = true;
    var hideConfirmation = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Change ${p.displayName}'s password"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      tooltip: hidePassword ? 'Show password' : 'Hide password',
                      onPressed: () =>
                          setDialogState(() => hidePassword = !hidePassword),
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Use at least 6 characters';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: confirmController,
                  obscureText: hideConfirmation,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    suffixIcon: IconButton(
                      tooltip: hideConfirmation
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setDialogState(
                        () => hideConfirmation = !hideConfirmation,
                      ),
                      icon: Icon(
                        hideConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Change password'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      passwordController.dispose();
      confirmController.dispose();
      return;
    }

    setState(() => _busy.add(p.id));
    try {
      await _repo.setPassword(p.id, passwordController.text);
      if (mounted) _snack("${p.displayName}'s password was changed");
    } catch (e) {
      if (mounted) _snack('Could not change password: $e');
    } finally {
      passwordController.dispose();
      confirmController.dispose();
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _openWorkOrders() {
    Navigator.pop(context);
  }

  // ----------------------------------------------------------------- helpers

  List<BoxShadow> get _shadow => [
    BoxShadow(
      color: const Color(0xFF193C42).withOpacity(0.07),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return _teal;
      case 'blocked':
        return _red;
      default:
        return _amber;
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- sidebar

  Widget _sidebarFilter(String label, IconData icon, Color color) {
    final selected = _filter == label;

    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 3, bottom: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _filter = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? _mint : Colors.white.withOpacity(0.62),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_count(label.toLowerCase())}',
                  style: TextStyle(
                    color: selected ? _ink : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    final screenW = MediaQuery.of(context).size.width;
    final initial = widget.profile.displayName.isEmpty
        ? '?'
        : widget.profile.displayName[0].toUpperCase();

    return Container(
      width: screenW >= 1200 ? 264.0 : 232.0,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193C42).withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, _navy2],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -90,
              top: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _mint.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: _mint,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'MAINTENANCE',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openWorkOrders,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            size: 22,
                            color: Colors.white.withOpacity(0.68),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Work orders',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 10),
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 22,
                          color: _mint,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Accounts',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_count('pending') > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _amber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_count('pending')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _sidebarFilter(
                    'Pending',
                    Icons.hourglass_top_rounded,
                    _amber,
                  ),
                  _sidebarFilter(
                    'Approved',
                    Icons.verified_rounded,
                    _tealLight,
                  ),
                  _sidebarFilter('Blocked', Icons.block_rounded, _red),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _mint,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.profile.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Administrator',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _logout,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 22,
                            color: Color(0xFFFCA5A5),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Log out',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Admin',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Work orders',
            icon: const Icon(Icons.work_outline_rounded, color: _teal),
            onPressed: _openWorkOrders,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _ink),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded, color: _red),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ content

  Widget _banner(bool wide) {
    final pending = _count('pending');
    final message = pending == 0
        ? 'All accounts have been reviewed.'
        : (pending == 1
              ? '1 account is waiting for your approval.'
              : '$pending accounts are waiting for your approval.');

    final button = pending == 0
        ? null
        : FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _mint,
              foregroundColor: _ink,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => setState(() => _filter = 'Pending'),
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text(
              'Review pending',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, size: 14, color: _mint),
              SizedBox(width: 8),
              Text(
                'Admin section',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Account approvals',
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 30 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.5),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193C42).withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_navy, _navy2],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -100,
                top: -90,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
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
                    color: _mint.withOpacity(0.07),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 32 : 22),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: info),
                          if (button != null) ...[
                            const SizedBox(width: 20),
                            button,
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          info,
                          if (button != null) ...[
                            const SizedBox(height: 18),
                            button,
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(
    String label,
    int value,
    IconData icon,
    Color color,
    String filter,
  ) {
    final selected = _filter == filter;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : _cardLine,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: _shadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(double w) {
    final tiles = <Widget>[
      _statTile(
        'Pending',
        _count('pending'),
        Icons.hourglass_top_rounded,
        _amber,
        'Pending',
      ),
      _statTile(
        'Approved',
        _count('approved'),
        Icons.verified_rounded,
        _teal,
        'Approved',
      ),
      _statTile(
        'Blocked',
        _count('blocked'),
        Icons.block_rounded,
        _red,
        'Blocked',
      ),
      _statTile(
        'All accounts',
        _accounts.length,
        Icons.groups_rounded,
        const Color(0xFF3B82F6),
        'All',
      ),
    ];

    if (w >= 760) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: tiles[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 12),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 12),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search by name or username',
          hintStyle: const TextStyle(color: Color(0xFF9AA7AE), fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF82939B),
            size: 22,
          ),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF82939B),
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    if (filled) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: shape,
          padding: pad,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: shape,
        padding: pad,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _accountCard(Profile p) {
    final isMe = p.id == widget.profile.id;
    final busy = _busy.contains(p.id);
    final color = _statusColor(p.status);

    final actions = <Widget>[];
    actions.add(
      _actionBtn(
        label: 'Change password',
        icon: Icons.lock_reset_rounded,
        color: _teal,
        filled: false,
        onTap: busy ? null : () => _changePassword(p),
      ),
    );
    if (!p.isAdmin && !isMe) {
      if (p.status == 'pending') {
        actions.add(
          _actionBtn(
            label: 'Approve',
            icon: Icons.check_rounded,
            color: _teal,
            filled: true,
            onTap: busy ? null : () => _approve(p),
          ),
        );
      } else if (p.status == 'blocked') {
        actions.add(
          _actionBtn(
            label: 'Unblock',
            icon: Icons.lock_open_rounded,
            color: _teal,
            filled: true,
            onTap: busy ? null : () => _unblock(p),
          ),
        );
      } else {
        actions.add(
          _actionBtn(
            label: 'Block',
            icon: Icons.block_rounded,
            color: _amber,
            filled: false,
            onTap: busy ? null : () => _block(p),
          ),
        );
      }
      actions.add(
        _actionBtn(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          color: _red,
          filled: false,
          onTap: busy ? null : () => _delete(p),
        ),
      );
    }

    final initial = p.displayName.isEmpty
        ? '?'
        : p.displayName[0].toUpperCase();

    final avatar = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_teal, _tealLight],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.displayName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          p.username.isNotEmpty ? '@${p.username}' : p.email,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          'Joined ${formatDateTime(p.createdAt)}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );

    final badges = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _badge(_cap(p.status), color),
        if (p.isAdmin) _badge('Admin', _tealLight),
        if (isMe && !p.isAdmin) _badge('You', _muted),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardLine),
        boxShadow: _shadow,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 680;
          if (wide) {
            return Row(
              children: [
                avatar,
                const SizedBox(width: 14),
                Expanded(child: info),
                const SizedBox(width: 14),
                badges,
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: 14),
                  Expanded(child: info),
                ],
              ),
              const SizedBox(height: 12),
              badges,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _messageBox({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardLine),
        boxShadow: _shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.10),
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted),
          ),
          if (action != null) ...[const SizedBox(height: 18), action],
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 56),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardLine),
        ),
        child: const Center(child: CircularProgressIndicator(color: _teal)),
      );
    }
    if (_error != null) {
      return _messageBox(
        icon: Icons.cloud_off_rounded,
        color: _red,
        title: 'Could not load accounts',
        message: _error!,
        action: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _teal),
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    }

    final list = _visible;
    if (list.isEmpty) {
      final searching = _search.isNotEmpty;
      return _messageBox(
        icon: searching
            ? Icons.search_off_rounded
            : (_filter == 'Pending'
                  ? Icons.task_alt_rounded
                  : Icons.groups_rounded),
        color: _teal,
        title: searching
            ? 'No matching accounts'
            : (_filter == 'Pending'
                  ? 'No accounts waiting'
                  : 'No $_filter accounts'.replaceAll('No All ', 'No ')),
        message: searching
            ? 'Try a different name or username.'
            : (_filter == 'Pending'
                  ? 'New sign-ups will show up here for your approval.'
                  : 'Nothing to show here yet.'),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _accountCard(list[i]),
        ],
      ],
    );
  }

  Widget _content(bool wide) {
    final sw = MediaQuery.of(context).size.width;
    final hPad = wide ? 32.0 : (sw < 400 ? 12.0 : 16.0);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, wide ? 28 : 8, hPad, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _banner(w >= 720),
                  const SizedBox(height: 22),
                  _stats(w),
                  const SizedBox(height: 22),
                  _searchBar(),
                  const SizedBox(height: 16),
                  _list(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _canvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) _sidebar(),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  if (!wide) _topBar(),
                  Expanded(child: _content(wide)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
