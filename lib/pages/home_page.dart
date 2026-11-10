import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/maintenance_request.dart';
import '../services/request_repository.dart';
import 'login_page.dart';
import 'receipt_page.dart';
import 'request_form_page.dart';

const List<String> statuses = ['Pending', 'In Progress', 'Completed'];

String formatDate(DateTime date) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    case 'hvac':
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
      return const Color(0xFF22C55E);
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
  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _primary = Color(0xFF2563EB);
  static const _indigo = Color(0xFF4F46E5);
  static const _navy = Color(0xFF0B1B4D);
  static const _bg = Color(0xFFF4F6FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _repo = RequestRepository();

  _Section _section = _Section.overview;
  String _filter = 'All';
  String _search = '';
  bool _loading = true;
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
          color: const Color(0xFF1E3A8A).withOpacity(0.07),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

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

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(selected ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
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

    return Container(
      width: drawer ? null : 264,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_navy, Color(0xFF1E3A8A)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Maintenance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _navItem(
                        Icons.dashboard_rounded,
                        'Dashboard',
                        selected: _section == _Section.overview,
                        onTap: () => go(() => _setSection(_Section.overview)),
                      ),
                      _navItem(
                        Icons.list_alt_rounded,
                        'Requests',
                        selected: _section == _Section.requests,
                        onTap: () => go(() => _setSection(_Section.requests)),
                        count: _openCount,
                      ),
                      _navItem(
                        Icons.check_circle_rounded,
                        'Completed',
                        selected: _section == _Section.completed,
                        onTap: () => go(() => _setSection(_Section.completed)),
                        count: _count('Completed'),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.username.isEmpty ? 'User' : widget.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _navItem(Icons.logout_rounded, 'Log out',
                  selected: false, onTap: () => go(_logout)),
            ],
          ),
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
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
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

  Widget _banner(bool wide) {
    final pending = _count('Pending');
    final active = _count('In Progress');
    final message = (pending + active) == 0
        ? 'No open requests. You are all caught up.'
        : 'You have $pending pending and $active in-progress requests.';

    final newBtn = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => _openForm(),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'New Request',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 14),
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
              colors: [_primary, _indigo],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -50, top: -60, child: _circle(220, 0.10)),
              Positioned(right: 140, bottom: -90, child: _circle(180, 0.07)),
              Padding(
                padding: EdgeInsets.all(wide ? 32 : 22),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (wide) newBtn,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color,
      {double? fraction}) {
    final total = _requests.length;
    final frac = fraction ?? (total == 0 ? 0.0 : value / total);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: frac),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(double w) {
    final total = _requests.length;
    final cards = <Widget>[
      _statCard('Total requests', total, Icons.assignment_rounded, _primary,
          fraction: total == 0 ? 0.0 : 1.0),
      _statCard('Pending', _count('Pending'), Icons.pending_actions_rounded,
          statusColor('Pending')),
      _statCard('In Progress', _count('In Progress'),
          Icons.hourglass_top_rounded, statusColor('In Progress')),
      _statCard('Completed', _count('Completed'), Icons.check_circle_rounded,
          statusColor('Completed')),
    ];

    if (w >= 760) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: cards[2]),
          const SizedBox(width: 12),
          Expanded(child: cards[3]),
        ]),
      ],
    );
  }

  Widget _panel({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(color: _muted, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        ],
      ),
    );
  }

  Widget _statusPanel() {
    final pending = _count('Pending');
    final active = _count('In Progress');
    final done = _count('Completed');
    final total = _requests.length;
    final rate = total == 0 ? 0 : (done * 100 / total).round();

    return _panel(
      title: 'Status overview',
      subtitle: 'How your requests are progressing',
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
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
                      track: const Color(0xFFEFF3F8),
                      progress: t,
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
                              color: _ink,
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
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _legendRow('Pending', pending, statusColor('Pending')),
                    _legendRow(
                        'In Progress', active, statusColor('In Progress')),
                    _legendRow('Completed', done, statusColor('Completed')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 24, color: _line),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20, color: _muted),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Average turnaround',
                    style: TextStyle(
                        color: _muted, fontWeight: FontWeight.w600)),
              ),
              Text(
                _avgTurnaround(),
                style: const TextStyle(
                    color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barRow({
    required IconData icon,
    required String label,
    required int value,
    required int max,
    required Color color,
  }) {
    final frac = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
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
                        style: const TextStyle(
                            color: _ink, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typePanel() {
    int countType(String t) => _requests.where((r) => r.type == t).length;
    final max = requestTypes
        .map(countType)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return _panel(
      title: 'Requests by type',
      subtitle: 'All requests',
      child: Column(
        children: [
          for (final t in requestTypes)
            _barRow(
              icon: typeIcon(t),
              label: t,
              value: countType(t),
              max: max,
              color: _primary,
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

    return _panel(
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
        ],
      ),
    );
  }

  Widget _miniTile(MaintenanceRequest r) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDetails(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primary, _indigo],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(typeIcon(r.type), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
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
          ],
        ),
      ),
    );
  }

  Widget _recentPanel() {
    final recent = _requests.take(5).toList();
    return _panel(
      title: 'Recent requests',
      subtitle: 'Latest activity',
      trailing: TextButton(
        onPressed: () => _setSection(_Section.requests),
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

  Widget _overviewPage(double w) {
    final twoCol = w >= 860;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(w >= 700),
        const SizedBox(height: 22),
        if (_loading)
          _loadingBox()
        else if (_error != null)
          _errorBox()
        else ...[
          _statsGrid(w),
          const SizedBox(height: 22),
          if (twoCol)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _statusPanel()),
                const SizedBox(width: 20),
                Expanded(child: _typePanel()),
              ],
            )
          else ...[
            _statusPanel(),
            const SizedBox(height: 20),
            _typePanel(),
          ],
          const SizedBox(height: 22),
          if (twoCol)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _recentPanel()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _priorityPanel()),
              ],
            )
          else ...[
            _recentPanel(),
            const SizedBox(height: 20),
            _priorityPanel(),
          ],
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _ink,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Request',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: _shadow,
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search by subject, location, name or ID',
          hintStyle: const TextStyle(color: _muted),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: _muted),
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
                  color: selected
                      ? Colors.white.withOpacity(0.25)
                      : const Color(0xFFF1F5F9),
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
    return _HoverCard(
      onTap: () => _showDetails(r),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _badge(r.status, statusColor(r.status), dot: true),
                IconButton(
                  tooltip: 'Print receipt',
                  icon: const Icon(Icons.print_rounded, color: _muted),
                  onPressed: () => _openReceipt(r),
                ),
              ],
            ),
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
            _infoRow(Icons.person_rounded, '${r.requesterName} - ${r.designation}'),
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
      child: const Center(child: CircularProgressIndicator()),
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
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
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
    return Column(
      children: [
        if (!wide) _mobileBar(),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
              wide ? 32 : 16,
              wide ? 28 : 8,
              wide ? 32 : 16,
              100,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
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
              field(Icons.person_rounded, 'Requested by', '${r.requesterName} (${r.designation})'),
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
              width: 280,
              backgroundColor: Colors.transparent,
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
              label: const Text('New Request'),
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

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = (values[i] / total) * math.pi * 2 * progress;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = colors[i];
      canvas.drawArc(rect, start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.values.join(',') != values.join(',');
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
                  ? const Color(0xFF2563EB).withOpacity(0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A)
                    .withOpacity(_hover ? 0.16 : 0.07),
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