import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maintenance_request.dart';
import '../models/profile.dart';
import '../services/request_repository.dart';
import 'admin_page.dart';
import 'login_page.dart';
import 'receipt_page.dart';
import 'request_form_page.dart';

const List<String> statuses = ['Pending', 'In Progress', 'Completed'];

String formatDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

IconData typeIcon(String type) {
  final t = type.toLowerCase();
  switch (t) {
    case 'electrical':
    case 'power':
      return Icons.electrical_services_rounded;
    case 'plumbing':
      return Icons.plumbing_rounded;
    case 'aircon':
    case 'aircon':
      return Icons.ac_unit_rounded;
    case 'civil':
    case 'structural':
      return Icons.construction_rounded;
    case 'relocation':
    case 'service':
      return Icons.swap_horiz_rounded;
    case 'repair':
    case 'maintenance':
    default:
      return Icons.build_rounded;
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'Pending':
      return const Color(0xFF0EA5E9);
    case 'In Progress':
      return const Color(0xFFF59E0B);
    case 'Completed':
      return const Color(0xFF087F75);
    default:
      return const Color(0xFF64748B);
  }
}

Color priorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'low':
      return const Color(0xFF10B981);
    case 'normal':
      return const Color(0xFF3B82F6);
    case 'high':
      return const Color(0xFFF59E0B);
    case 'urgent':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF6366F1);
  }
}

enum _Section { overview, requests, completed }

class HomePage extends StatefulWidget {
  final String username;
  final Profile? profile;
  const HomePage({super.key, required this.username, this.profile});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Same colors as the login page
  static const _primary = Color(0xFF087F75); // login teal
  static const _indigo = Color(0xFF14A89A); // lighter teal (gradients)
  static const _navy = Color(0xFF173B46); // login dark panel (top)
  static const _bgBottom = Color(0xFF102B38); // login dark panel (bottom)
  static const _bg = Color(0xFFF3F7F5); // login canvas
  static const _field = Color(0xFFF5F8F7); // login field fill
  static const _mint = Color(0xFFB8F2D8); // login mint accent
  static const _cardLine = Color(0xFFE8EFEB); // login card border
  static const _ink = Color(0xFF172B3A);
  static const _muted = Color(0xFF71818C);
  static const _line = Color(0xFFE7EEEA);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _repo = RequestRepository();

  _Section _section = _Section.overview;
  String _filter = 'All';
  String _search = '';
  bool _loading = true;
  bool _showAllTypes = false;
  String? _error;

  List<MaintenanceRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Supabase

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _repo.fetchAll();
      if (!mounted) return;
      setState(() {
        _requests = list;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _updateStatus(MaintenanceRequest r, String s) async {
    final oldStatus = r.status;
    final oldCompleted = r.completedAt;
    setState(() {
      r.status = s;
      if (s == 'Completed') {
        r.completedAt ??= DateTime.now();
      } else {
        r.completedAt = null;
      }
    });
    try {
      await _repo.updateStatus(r.id, s, r.completedAt);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        r.status = oldStatus;
        r.completedAt = oldCompleted;
      });
      _snack('Could not update status: $e');
    }
  }

  Future<void> _deleteRequest(MaintenanceRequest r) async {
    try {
      await _repo.delete(r.id);
      if (!mounted) return;
      setState(() => _requests.removeWhere((x) => x.id == r.id));
    } catch (e) {
      _snack('Could not delete: $e');
    }
  }

  // ------------------------------------------------------------------- Logic

  List<BoxShadow> get _shadow => [
        BoxShadow(
          color: const Color(0xFF193C42).withOpacity(0.07),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  /// True on phones (narrow screens).
  bool get _small => MediaQuery.of(context).size.width < 480;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  int _count(String status) =>
      _requests.where((r) => r.status == status).length;

  int get _openCount => _requests.where((r) => r.status != 'Completed').length;

  String get _sectionTitle {
    if (_section == _Section.requests) return 'Requests';
    if (_section == _Section.completed) return 'Completed';
    return 'Dashboard';
  }

  void _setSection(_Section s) {
    setState(() {
      _section = s;
      _filter = 'All';
      _search = '';
      _searchCtrl.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Requests page -> open requests only. Completed page -> completed only.
  List<MaintenanceRequest> get _visible {
    final q = _search.toLowerCase();
    final list = _requests.where((r) {
      final done = r.status == 'Completed';
      final inSection = _section == _Section.completed ? done : !done;
      final okStatus = _filter == 'All' || r.status == _filter;
      final okSearch = q.isEmpty ||
          r.subject.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q) ||
          r.requesterName.toLowerCase().contains(q) ||
          r.id.toLowerCase().contains(q);
      return inSection && okStatus && okSearch;
    }).toList();

    if (_section == _Section.completed) {
      list.sort((a, b) =>
          (b.completedAt ?? b.date).compareTo(a.completedAt ?? a.date));
    }
    return list;
  }

  String _avgTurnaround() {
    final done = _requests.where((r) => r.completedAt != null).toList();
    if (done.isEmpty) return '-';
    var total = Duration.zero;
    for (final r in done) {
      final d = r.completedAt!.difference(r.date);
      total += d.isNegative ? Duration.zero : d;
    }
    final avg = Duration(minutes: (total.inMinutes / done.length).round());
    final days = avg.inDays;
    final hours = avg.inHours % 24;
    final mins = avg.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (avg.inHours > 0) return '${avg.inHours}h ${mins}m';
    return '${avg.inMinutes}m';
  }

  Future<void> _openForm({MaintenanceRequest? existing}) async {
    String nextId;
    if (existing != null) {
      nextId = existing.id;
    } else {
      try {
        nextId = await _repo.nextId();
      } catch (e) {
        _snack('Could not reach the database: $e');
        return;
      }
    }
    if (!mounted) return;

    final result = await Navigator.push<MaintenanceRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => RequestFormPage(
          existing: existing,
          nextId: nextId,
        ),
      ),
    );

    if (result == null) return;

    // The form already saved the request to Supabase; just reload the list.
    await _load(showSpinner: false);
    _snack('Saved ${result.id} to Supabase');
  }

  void _openReceipt(MaintenanceRequest r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptPage(request: r)),
    );
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

  void _openAdminSection() {
    final profile = widget.profile;
    if (profile == null || !profile.isAdmin) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminHomePage(profile: profile)),
    );
  }

  void _confirmDelete(MaintenanceRequest r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete request?'),
        content: Text('${r.id} - ${r.subject}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close details sheet
              await _deleteRequest(r);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Small pieces

  Widget _badge(String text, Color color, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
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

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  // ----------------------------------------------------------------- Sidebar

  Widget _navItem(
    IconData icon,
    String label, {
    required bool selected,
    required VoidCallback onTap,
    int? count,
    bool danger = false,
  }) {
    final fg = selected
        ? Colors.white
        : (danger ? const Color(0xFFFCA5A5) : Colors.white.withOpacity(0.68));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: Colors.white.withOpacity(0.10))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: selected ? _mint : fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected
                        ? _mint.withOpacity(0.20)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? _mint : Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebar({bool drawer = false}) {
    void go(VoidCallback fn) {
      if (drawer) _scaffoldKey.currentState?.closeDrawer();
      fn();
    }

    final initial =
        widget.username.isEmpty ? '?' : widget.username[0].toUpperCase();
    final screenW = MediaQuery.of(context).size.width;
    final radius = drawer
        ? const BorderRadius.horizontal(right: Radius.circular(28))
        : BorderRadius.circular(28);

    // Same dark teal panel look as the login page's left side.
    return Container(
      width: drawer ? null : (screenW >= 1200 ? 264.0 : 232.0),
      margin: drawer ? EdgeInsets.zero : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: drawer
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF193C42).withOpacity(0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, _bgBottom],
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
            SafeArea(
              child: Padding(
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
                          child: const Icon(Icons.handyman_rounded,
                              color: _mint, size: 24),
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
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 10),
                      child: Text(
                        'MENU',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _navItem(
                              Icons.dashboard_rounded,
                              'Dashboard',
                              selected: _section == _Section.overview,
                              onTap: () =>
                                  go(() => _setSection(_Section.overview)),
                            ),
                            _navItem(
                              Icons.list_alt_rounded,
                              'Requests',
                              selected: _section == _Section.requests,
                              onTap: () =>
                                  go(() => _setSection(_Section.requests)),
                              count: _openCount,
                            ),
                            _navItem(
                              Icons.check_circle_rounded,
                              'Completed',
                              selected: _section == _Section.completed,
                              onTap: () =>
                                  go(() => _setSection(_Section.completed)),
                              count: _count('Completed'),
                            ),
                            if (widget.profile?.isAdmin == true) ...[
                              const Padding(
                                padding: EdgeInsets.fromLTRB(6, 18, 6, 10),
                                child: Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _navItem(
                                Icons.admin_panel_settings_rounded,
                                'Admin section',
                                selected: false,
                                onTap: () => go(_openAdminSection),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
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
                                  widget.username.isEmpty
                                      ? 'User'
                                      : widget.username,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Signed in',
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
                    _navItem(Icons.logout_rounded, 'Log out',
                        selected: false,
                        danger: true,
                        onTap: () => go(_logout)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileBar() {
    final initial =
        widget.username.isEmpty ? '?' : widget.username[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: _ink),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: Text(
              _sectionTitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _ink),
            onPressed: _load,
          ),
          CircleAvatar(
            radius: 17,
            backgroundColor: _primary,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Dashboard

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int _pct(int v) =>
      _requests.isEmpty ? 0 : (v * 100 / _requests.length).round();

  void _goRequests([String filter = 'All']) {
    _setSection(_Section.requests);
    setState(() => _filter = filter);
  }

  Widget _heroPill(String label, int value, IconData icon, Color color) {
    final tint = Color.lerp(color, Colors.white, 0.55) ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Blue gradient panel (same look as the login page's sliding panel).

  Widget _banner(bool wide) {
    final now = DateTime.now();
    final dateText = '${_weekdays[now.weekday - 1]}, ${formatDate(now)}';
    final pending = _count('Pending');
    final active = _count('In Progress');
    final done = _count('Completed');
    final message = (pending + active) == 0
        ? 'No open requests. You are all caught up.'
        : 'You have $pending pending and $active in-progress requests.';
    final name = widget.username.isEmpty ? '' : ', ${widget.username}';

    final newBtn = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: _mint,
        foregroundColor: _ink,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => _openForm(),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'New Request',
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: _mint),
              const SizedBox(width: 8),
              Text(
                dateText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${_greeting()}$name',
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 32 : 26,
            fontWeight: FontWeight.w700,
            height: 1.16,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _heroPill('Pending', pending, Icons.pending_actions_rounded,
                statusColor('Pending')),
            _heroPill('In Progress', active, Icons.hourglass_top_rounded,
                statusColor('In Progress')),
            _heroPill('Completed', done, Icons.check_circle_rounded,
                statusColor('Completed')),
          ],
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
              colors: [_navy, _bgBottom],
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
                padding: EdgeInsets.all(wide ? 34 : 24),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: info),
                          const SizedBox(width: 20),
                          newBtn,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          info,
                          const SizedBox(height: 20),
                          newBtn,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    int value,
    IconData icon,
    Color color, {
    required String footer,
    VoidCallback? onTap,
  }) {
    final light = Color.lerp(color, Colors.white, 0.3) ?? color;
    return _HoverCard(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, light],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded,
                    size: 18, color: _muted),
              ],
            ),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                '${v.round()}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                footer,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(double w) {
    final total = _requests.length;
    final pending = _count('Pending');
    final active = _count('In Progress');
    final done = _count('Completed');

    final cards = <Widget>[
      _statCard('Total requests', total, Icons.assignment_rounded, _primary,
          footer: '$_openCount open', onTap: () => _goRequests()),
      _statCard('Pending', pending, Icons.pending_actions_rounded,
          statusColor('Pending'),
          footer: '${_pct(pending)}% of total',
          onTap: () => _goRequests('Pending')),
      _statCard('In Progress', active, Icons.hourglass_top_rounded,
          statusColor('In Progress'),
          footer: '${_pct(active)}% of total',
          onTap: () => _goRequests('In Progress')),
      _statCard('Completed', done, Icons.check_circle_rounded,
          statusColor('Completed'),
          footer: '${_pct(done)}% of total',
          onTap: () => _setSection(_Section.completed)),
    ];

    // Large screens: 4 across.
    if (w >= 760) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    // Tablets and phones: 2 x 2.
    if (w >= 300) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 14),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }
    // Very small screens: one per row.
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }

  Widget _panel({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    final pad = _small ? 18.0 : 24.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardLine),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primary, _indigo],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: _small ? 18 : 22),
          child,
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _legendRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: _muted, fontWeight: FontWeight.w600)),
          ),
          Text('$value',
              style: const TextStyle(
                  color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${_pct(value)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPanel(double inner) {
    final pending = _count('Pending');
    final active = _count('In Progress');
    final done = _count('Completed');
    final rate = _pct(done);
    final compact = inner < 400;

    final donut = SizedBox(
      width: 150,
      height: 150,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(
          painter: _DonutPainter(
            values: [
              pending.toDouble(),
              active.toDouble(),
              done.toDouble(),
            ],
            colors: [
              statusColor('Pending'),
              statusColor('In Progress'),
              statusColor('Completed'),
            ],
            track: _field,
            progress: t,
            stroke: 20,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$rate%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const Text(
                  'completed',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final legend = Column(
      children: [
        _legendRow('Pending', pending, statusColor('Pending')),
        _legendRow('In Progress', active, statusColor('In Progress')),
        _legendRow('Completed', done, statusColor('Completed')),
      ],
    );

    return _panel(
      icon: Icons.donut_large_rounded,
      title: 'Status overview',
      subtitle: 'How your requests are progressing',
      child: Column(
        children: [
          if (compact)
            Column(
              children: [
                Center(child: donut),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: legend),
              ],
            )
          else
            Row(
              children: [
                donut,
                const SizedBox(width: 20),
                Expanded(child: legend),
              ],
            ),
          const Divider(height: 28, color: _line),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _field,
                  borderRadius: BorderRadius.circular(11),
                ),
                child:
                    const Icon(Icons.timer_outlined, size: 19, color: _primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Average turnaround',
                    style:
                        TextStyle(color: _muted, fontWeight: FontWeight.w600)),
              ),
              Text(
                _avgTurnaround(),
                style: const TextStyle(
                    color: _ink, fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Rounded horizontal progress bar with a gradient fill.
  Widget _bar(double frac, List<Color> colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 10,
        color: const Color(0xFFEFF3F8),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: frac),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barRow({
    required IconData icon,
    required String label,
    required int value,
    required int max,
    required Color color,
    List<Color>? gradient,
  }) {
    final frac = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Text('$value',
                        style: TextStyle(
                            color: value == 0 ? _muted : _ink,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                _bar(frac, gradient ?? [color, color.withOpacity(0.65)]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekBar({
    required String label,
    required int count,
    required int max,
    required bool today,
  }) {
    final frac = count == 0 ? 0.04 : count / max;
    final radius = BorderRadius.circular(9);
    final decoration = (today && count > 0)
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_primary, _indigo],
            ),
            borderRadius: radius,
          )
        : BoxDecoration(
            color: count > 0 ? _primary.withOpacity(0.28) : _line,
            borderRadius: radius,
          );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 18,
          child: Text(
            count > 0 ? '$count' : '',
            style: const TextStyle(
                color: _ink, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: frac),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Container(
            width: 26,
            height: (96 * v) < 4 ? 4 : 96 * v,
            decoration: decoration,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: today ? _primary : _muted,
            fontWeight: today ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _weekPanel() {
    final now = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );
    final counts = days
        .map((d) => _requests
            .where((r) =>
                r.date.year == d.year &&
                r.date.month == d.month &&
                r.date.day == d.day)
            .length)
        .toList();
    final max = counts.fold<int>(1, (a, b) => a > b ? a : b);
    final total = counts.fold<int>(0, (a, b) => a + b);

    return _panel(
      icon: Icons.bar_chart_rounded,
      title: 'Weekly activity',
      subtitle: 'Requests filed in the last 7 days',
      trailing: _chip('$total this week', _primary),
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: _weekBar(
                  label: _weekdays[days[i].weekday - 1],
                  count: counts[i],
                  max: max,
                  today: i == days.length - 1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _typePanel() {
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final request in _requests) {
      final label = request.type.trim();
      if (label.isEmpty) continue;
      final key = label.toLowerCase();
      labels.putIfAbsent(key, () => label);
      counts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final types = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return labels[a.key]!.toLowerCase().compareTo(
              labels[b.key]!.toLowerCase(),
            );
      });
    const visibleLimit = 5;
    final shownTypes =
        _showAllTypes ? types : types.take(visibleLimit).toList();
    final max = types.isEmpty
        ? 0
        : types.map((type) => type.value).reduce((a, b) => a > b ? a : b);

    return _panel(
      icon: Icons.category_rounded,
      title: 'Requests by type',
      subtitle: 'All requests',
      child: Column(
        children: [
          if (shownTypes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Request types will appear here when entered.',
                style: TextStyle(color: _muted),
              ),
            )
          else
            for (final type in shownTypes)
              _barRow(
                icon: typeIcon(labels[type.key]!),
                label: labels[type.key]!,
                value: type.value,
                max: max,
                color: _primary,
                gradient: const [_primary, _indigo],
              ),
          if (types.length > visibleLimit)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _showAllTypes = !_showAllTypes),
                child: Text(_showAllTypes ? 'Show less' : 'See all'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _priorityPanel() {
    final open = _requests.where((r) => r.status != 'Completed').toList();
    int countP(String p) => open.where((r) => r.priority == p).length;
    final order = priorities.reversed.toList(); // Urgent first
    final max = order.map(countP).fold<int>(0, (a, b) => a > b ? a : b);
    final hot = countP('Urgent') + countP('High');
    final alertColor =
        hot > 0 ? const Color(0xFFEF4444) : statusColor('Completed');

    return _panel(
      icon: Icons.flag_rounded,
      title: 'Open by priority',
      subtitle: 'Pending and in-progress only',
      child: Column(
        children: [
          for (final p in order)
            _barRow(
              icon: Icons.flag_rounded,
              label: p,
              value: countP(p),
              max: max,
              color: priorityColor(p),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: alertColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: alertColor.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  hot > 0
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  color: alertColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hot > 0
                        ? '$hot urgent or high request${hot == 1 ? '' : 's'} need attention'
                        : 'No urgent requests. Great work!',
                    style: TextStyle(
                      color: alertColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (hot > 0)
                  TextButton(
                    onPressed: () => _goRequests(),
                    child: const Text('Review'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTile(MaintenanceRequest r) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDetails(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primary, _indigo],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(typeIcon(r.type), color: Colors.white, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${r.id}  -  ${formatDateTime(r.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _badge(r.status, statusColor(r.status), dot: true),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _recentPanel() {
    final recent = _requests.take(5).toList();
    return _panel(
      icon: Icons.history_rounded,
      title: 'Recent requests',
      subtitle: 'Latest activity',
      trailing: TextButton(
        style: TextButton.styleFrom(foregroundColor: _primary),
        onPressed: () => _goRequests(),
        child: const Text('View all'),
      ),
      child: recent.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No requests yet. Tap New Request to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: _line),
                  _miniTile(recent[i]),
                ],
              ],
            ),
    );
  }

  /// Two panels side by side with the SAME height (stacked on narrow screens).
  Widget _pairRow(bool twoCol, Widget a, Widget b) {
    if (!twoCol) {
      return Column(children: [a, const SizedBox(height: 20), b]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 20),
          Expanded(child: b),
        ],
      ),
    );
  }

  Widget _overviewPage(double w) {
    final twoCol = w >= 860;
    final panelW = twoCol ? (w - 20) / 2 : w;
    final inner = panelW - (_small ? 36 : 48);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(w >= 720),
        const SizedBox(height: 24),
        if (_loading)
          _loadingBox()
        else if (_error != null)
          _errorBox()
        else ...[
          _statsGrid(w),
          const SizedBox(height: 24),
          _pairRow(twoCol, _statusPanel(inner), _weekPanel()),
          const SizedBox(height: 20),
          _pairRow(twoCol, _typePanel(), _priorityPanel()),
          const SizedBox(height: 20),
          _recentPanel(),
        ],
      ],
    );
  }

  // ------------------------------------------------ Requests / Completed pages

  Widget _pageHeader(String title, String subtitle,
      {bool showNew = false, bool wide = true}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: _small ? 24 : 28,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
        if (showNew && wide)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Request',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
          hintText: 'Search by subject, location, name or ID',
          hintStyle: const TextStyle(color: Color(0xFF9AA7AE), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF82939B), size: 22),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF82939B)),
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

  Widget _pill(String label) {
    final selected = _filter == label;
    final count = label == 'All' ? _openCount : _count(label);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => setState(() => _filter = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? _primary : _line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.25) : _field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestCard(MaintenanceRequest r) {
    final compact = MediaQuery.of(context).size.width < 600;
    final badge = _badge(r.status, statusColor(r.status), dot: true);

    return _HoverCard(
      onTap: () => _showDetails(r),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primary, _indigo],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(typeIcon(r.type), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.id,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDateTime(r.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact) badge,
                IconButton(
                  tooltip: 'Print receipt',
                  icon: const Icon(Icons.print_rounded, color: _muted),
                  onPressed: () => _openReceipt(r),
                ),
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: badge),
            ],
            const SizedBox(height: 16),
            Text(
              r.subject,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 14),
            _infoRow(Icons.place_rounded, r.location),
            const SizedBox(height: 8),
            _infoRow(
                Icons.person_rounded, '${r.requesterName} - ${r.designation}'),
            if (r.completedAt != null) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.event_available_rounded,
                  'Completed ${formatDateTime(r.completedAt!)}'),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(r.type, _primary),
                _tag('${r.priority} priority', priorityColor(r.priority)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow,
      ),
      child: const Center(child: CircularProgressIndicator(color: _primary)),
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.red),
          const SizedBox(height: 14),
          const Text(
            'Could not load requests',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _empty(bool completedPage) {
    final filtering = _search.isNotEmpty || _filter != 'All';

    IconData icon;
    String title;
    String message;
    bool showCreate = false;

    if (filtering) {
      icon = Icons.search_off_rounded;
      title = 'No matching requests';
      message = 'Try a different search or filter.';
    } else if (completedPage) {
      icon = Icons.check_circle_outline_rounded;
      title = 'Nothing completed yet';
      message = 'Requests you mark as Completed will appear here.';
    } else if (_requests.isEmpty) {
      icon = Icons.inbox_rounded;
      title = 'No requests yet';
      message = 'Create your first maintenance request to get started.';
      showCreate = true;
    } else {
      icon = Icons.celebration_rounded;
      title = 'No open requests';
      message = 'You are all caught up.';
      showCreate = true;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary.withOpacity(0.1),
            ),
            child: Icon(icon, size: 44, color: _primary),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          if (showCreate && !filtering) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create request'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _listPage(bool wide, {required bool completed}) {
    final list = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          completed ? 'Completed' : 'Requests',
          completed
              ? 'Finished requests and their receipts'
              : 'Pending and in-progress maintenance requests',
          showNew: !completed,
          wide: wide,
        ),
        const SizedBox(height: 20),
        _searchBar(),
        const SizedBox(height: 18),
        if (!completed) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _pill('All'),
                _pill('Pending'),
                _pill('In Progress'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_loading)
          _loadingBox()
        else if (_error != null)
          _errorBox()
        else if (list.isEmpty)
          _empty(completed)
        else
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            _requestCard(list[i]),
          ],
      ],
    );
  }

  Widget _content(bool wide) {
    final sw = MediaQuery.of(context).size.width;
    final hPad = wide ? 32.0 : (sw < 400 ? 12.0 : 16.0);

    return Column(
      children: [
        if (!wide) _mobileBar(),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(hPad, wide ? 28 : 8, hPad, 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    if (_section == _Section.requests) {
                      return _listPage(wide, completed: false);
                    }
                    if (_section == _Section.completed) {
                      return _listPage(wide, completed: true);
                    }
                    return _overviewPage(w);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- Details sheet

  void _showDetails(MaintenanceRequest r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 760),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        Widget field(IconData icon, String label, String value) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 18, color: _muted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

        Widget block(String title, String text) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text.isEmpty ? '-' : text,
                    style: const TextStyle(color: _muted, height: 1.5),
                  ),
                ],
              ),
            );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(typeIcon(r.type), color: _primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      r.subject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                  _badge(r.status, statusColor(r.status), dot: true),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                r.id,
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              field(Icons.event_rounded, 'Requested', formatDateTime(r.date)),
              field(
                  Icons.event_available_rounded,
                  'Completed',
                  r.completedAt == null
                      ? 'Not completed yet'
                      : formatDateTime(r.completedAt!)),
              field(
                  Icons.send_rounded,
                  'Addressed to',
                  r.addressedTitle.isEmpty
                      ? r.addressedTo
                      : '${r.addressedTo} (${r.addressedTitle})'),
              field(Icons.person_rounded, 'Requested by',
                  '${r.requesterName} (${r.designation})'),
              field(
                  Icons.engineering_rounded,
                  'Acknowledged by',
                  r.acknowledgedBy.isEmpty
                      ? 'Not assigned yet'
                      : (r.acknowledgedTitle.isEmpty
                          ? r.acknowledgedBy
                          : '${r.acknowledgedBy} (${r.acknowledgedTitle})')),
              field(Icons.place_rounded, 'Location', r.location),
              field(Icons.category_rounded, 'Type', r.type),
              field(Icons.flag_rounded, 'Priority', r.priority),
              const SizedBox(height: 4),
              block('Details', r.details),
              block('Reason / Purpose', r.reason),
              const SizedBox(height: 6),
              const Text(
                'Update status',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: statuses.map((s) {
                  final selected = r.status == s;
                  return ChoiceChip(
                    label: Text(s),
                    selected: selected,
                    selectedColor: statusColor(s),
                    onSelected: (_) {
                      if (selected) return;
                      Navigator.pop(ctx);
                      _updateStatus(r, s);
                    },
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openReceipt(r);
                },
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text(
                  'View / Print Receipt',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openForm(existing: r);
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text(
                  'Edit request',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _confirmDelete(r),
                      icon: const Icon(Icons.delete_rounded),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      drawer: wide
          ? null
          : Drawer(
              width: 290,
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const RoundedRectangleBorder(),
              child: _sidebar(drawer: true),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) _sidebar(),
          Expanded(child: SafeArea(child: _content(wide))),
        ],
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Request',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}

/// Donut chart used on the dashboard.
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color track;
  final double progress;
  final double stroke;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.track,
    required this.progress,
    this.stroke = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    // Small gap between segments (only when more than one has data).
    final active = values.where((v) => v > 0).length;
    final gap = active > 1 ? 0.07 : 0.0;

    var start = -math.pi / 2 + gap / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final full = (values[i] / total) * math.pi * 2;
      final sweep = math.max(0.0, full - gap) * progress;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = colors[i];
      canvas.drawArc(rect, start, sweep, false, p);
      start += full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.values.join(',') != values.join(',');
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverCard({required this.child, required this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hover
                  ? const Color(0xFF087F75).withOpacity(0.45)
                  : const Color(0xFFE8EFEB),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    const Color(0xFF193C42).withOpacity(_hover ? 0.14 : 0.07),
                blurRadius: _hover ? 30 : 24,
                offset: Offset(0, _hover ? 16 : 10),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
