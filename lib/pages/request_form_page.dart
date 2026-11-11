import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maintenance_request.dart';
import '../services/request_repository.dart';

const List<String> requestStatusOptions = [
  'Pending',
  'In Progress',
  'Completed'
];

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

class RequestFormPage extends StatefulWidget {
  final MaintenanceRequest? existing;
  final String nextId;
  const RequestFormPage({super.key, this.existing, required this.nextId});

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  static const _primary = Color(0xFF2563EB);
  static const _indigo = Color(0xFF4F46E5);
  static const _bg = Color(0xFFF4F6FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();
  final _repo = RequestRepository();

  bool _saving = false;

  late DateTime _date;
  DateTime? _completed;
  late String _priority;
  late final TextEditingController _type;
  late final TextEditingController _to;
  late final TextEditingController _title;
  late final TextEditingController _ack;
  late final TextEditingController _ackTitle;
  late final TextEditingController _name;
  late final TextEditingController _designation;
  late final TextEditingController _location;
  late final TextEditingController _subject;
  late final TextEditingController _details;
  late final TextEditingController _reason;

  bool get _editing => widget.existing != null;
  String get _id => widget.existing?.id ?? widget.nextId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _completed = e?.completedAt;
    _type = TextEditingController(text: e?.type ?? '');
    _priority = e?.priority ?? 'Normal';
    _to = TextEditingController(text: e?.addressedTo ?? '');
    _title = TextEditingController(text: e?.addressedTitle ?? '');
    _ack = TextEditingController(text: e?.acknowledgedBy ?? '');
    _ackTitle = TextEditingController(text: e?.acknowledgedTitle ?? '');
    _name = TextEditingController(text: e?.requesterName ?? '');
    _designation = TextEditingController(text: e?.designation ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _subject = TextEditingController(text: e?.subject ?? '');
    _details = TextEditingController(text: e?.details ?? '');
    _reason = TextEditingController(text: e?.reason ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _type,
      _to,
      _title,
      _ack,
      _ackTitle,
      _name,
      _designation,
      _location,
      _subject,
      _details,
      _reason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pick a date, then a time (12-hour AM/PM clock).
  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return null;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    final time = t ?? TimeOfDay.fromDateTime(initial);
    return DateTime(d.year, d.month, d.day, time.hour, time.minute);
  }

  Future<void> _pickRequested() async {
    final p = await _pickDateTime(_date);
    if (p != null) setState(() => _date = p);
  }

  Future<void> _pickCompleted() async {
    final p = await _pickDateTime(_completed ?? DateTime.now());
    if (p != null) setState(() => _completed = p);
  }

  MaintenanceRequest _build(String id) => MaintenanceRequest(
        id: id,
        date: _date,
        addressedTo: _to.text.trim(),
        requesterName: _name.text.trim(),
        designation: _designation.text.trim(),
        location: _location.text.trim(),
        type: _type.text.trim(),
        priority: _priority,
        subject: _subject.text.trim(),
        details: _details.text.trim(),
        reason: _reason.text.trim(),
        status: _completed != null
            ? 'Completed'
            : (widget.existing?.status ?? 'Pending'),
        completedAt: _completed,
        addressedTitle: _title.text.trim(),
        acknowledgedBy: _ack.text.trim(),
        acknowledgedTitle: _ackTitle.text.trim(),
      );

  /// Validates the form, saves it to Supabase, then closes the page.
  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the required fields')),
      );
      return;
    }

    if (_completed != null && _completed!.isBefore(_date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Completed time cannot be earlier than the requested time')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      MaintenanceRequest? saved;

      if (_editing) {
        saved = _build(_id);
        await _repo.update(saved);
      } else {
        var id = _id;
        var attempts = 0;
        while (saved == null) {
          final req = _build(id);
          try {
            await _repo.insert(req);
            saved = req;
          } on PostgrestException catch (e) {
            // 23505 = this ID was just taken by someone else -> get a new one.
            if (e.code == '23505' && attempts < 3) {
              attempts++;
              id = await _repo.nextId();
            } else {
              rethrow;
            }
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save to Supabase: $e')),
      );
    }
  }

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  InputDecoration _dec(String label, IconData icon,
      {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      prefixIcon: Icon(icon, color: _muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _border(_line),
      enabledBorder: _border(_line),
      focusedBorder: _border(_primary, 1.8),
      errorBorder: _border(Colors.red),
      focusedErrorBorder: _border(Colors.red, 1.8),
    );
  }

  List<Widget> _spaced(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          items[i],
        ],
      ];

  Widget _pair(Widget a, Widget b) {
    final wide = MediaQuery.of(context).size.width >= 640;
    if (!wide) {
      return Column(children: [a, const SizedBox(height: 14), b]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 14),
        Expanded(child: b),
      ],
    );
  }

  Widget _card(int step, IconData icon, String title, String subtitle,
      List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primary, _indigo]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP $step',
                        style: const TextStyle(
                            color: _primary,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800)),
                    Text(title,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        style: const TextStyle(color: _muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._spaced(children),
        ],
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? color : _line, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: selected ? Colors.white : color),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : _ink,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 22),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _saving ? null : () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editing ? 'Edit Request' : 'New Maintenance Request',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    const Text('Fill in the details of your letter',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_id,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1, // keeps the bar only as tall as the buttons
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : Icon(
                            _editing ? Icons.save_rounded : Icons.send_rounded),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : (_editing ? 'Save changes' : 'Submit request'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    String v(TextEditingController c, String placeholder) =>
        c.text.trim().isEmpty ? placeholder : c.text.trim();

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Text(label,
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: _primary, size: 20),
              const SizedBox(width: 8),
              const Text('LIVE PREVIEW',
                  style: TextStyle(
                      color: _primary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(_id,
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w800)),
            ],
          ),
          const Divider(height: 24, color: _line),
          Text(
            v(_subject, 'Subject of your request'),
            style: TextStyle(
                color: _subject.text.trim().isEmpty ? _muted : _ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3),
          ),
          const SizedBox(height: 10),
          if (_type.text.trim().isNotEmpty)
            line('Request type', _type.text.trim()),
          line('Requested', formatDateTime(_date)),
          line('Completed',
              _completed == null ? '-' : formatDateTime(_completed!)),
          line('To', v(_to, '-')),
          line('Title', v(_title, '-')),
          line('Assigned', v(_ack, '-')),
          line('From', v(_name, '-')),
          line('Designation', v(_designation, '-')),
          line('Location', v(_location, '-')),
          const Divider(height: 24, color: _line),
          Text(v(_details, 'Details will appear here...'),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, height: 1.5)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: priorityColor(_priority).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_priority priority',
                    style: TextStyle(
                        color: priorityColor(_priority),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showPreview = width >= 980;

    final formColumn = Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(1, Icons.mail_rounded, 'Letter details',
              'When and to whom is this request addressed?', [
            _pair(
              InkWell(
                onTap: _pickRequested,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration:
                      _dec('Date & time requested', Icons.event_rounded),
                  child: Text(formatDateTime(_date),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              InkWell(
                onTap: _pickCompleted,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: _dec(
                    'Date & time completed',
                    Icons.event_available_rounded,
                    suffix: _completed == null
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _completed = null),
                          ),
                  ),
                  child: Text(
                    _completed == null
                        ? 'Not completed yet'
                        : formatDateTime(_completed!),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _completed == null ? _muted : _ink),
                  ),
                ),
              ),
            ),
            _pair(
              TextFormField(
                controller: _to,
                decoration: _dec('To (signs the receipt)', Icons.send_rounded,
                    hint: 'e.g. Engr. Ferdinand S. Abrigo'),
              ),
              TextFormField(
                controller: _title,
                decoration: _dec('Title under the name', Icons.badge_rounded,
                    hint: 'e.g. Dept. Manager'),
              ),
            ),
          ]),
          _card(2, Icons.person_rounded, 'Requester',
              'Who is making the request and where?', [
            _pair(
              TextFormField(
                controller: _name,
                decoration: _dec('Requester name', Icons.person_rounded),
              ),
              TextFormField(
                controller: _designation,
                decoration: _dec('Designation', Icons.badge_rounded,
                    hint: 'e.g. Operator'),
              ),
            ),
            TextFormField(
              controller: _location,
              decoration: _dec('Location / Site', Icons.place_rounded,
                  hint: 'e.g. Sta. Veronica PW'),
            ),
          ]),
          _card(3, Icons.build_circle_rounded, 'Request',
              'What needs to be done and how urgent is it?', [
            TextFormField(
              controller: _type,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(
                'Request type (optional)',
                Icons.category_rounded,
                hint: 'e.g. Electrical, Plumbing, Equipment repair',
              ),
            ),
            const Text('Priority',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: priorities.map((p) {
                return _choice(
                  label: p,
                  icon: Icons.flag_rounded,
                  color: priorityColor(p),
                  selected: _priority == p,
                  onTap: () => setState(() => _priority = p),
                );
              }).toList(),
            ),
            TextFormField(
              controller: _subject,
              decoration: _dec('Subject', Icons.title_rounded,
                  hint: 'e.g. Relocation of 220V service wire'),
            ),
            TextFormField(
              controller: _details,
              maxLines: 5,
              minLines: 4,
              decoration: _dec('Details of the request', Icons.notes_rounded),
            ),
            TextFormField(
              controller: _reason,
              maxLines: 3,
              minLines: 3,
              decoration: _dec(
                  'Reason / Purpose (optional)', Icons.help_outline_rounded,
                  hint: 'e.g. To prevent the risk of electrocution'),
            ),
          ]),
          _card(4, Icons.verified_user_rounded, 'Acknowledgement',
              'Who will carry out this request? They sign on the receipt.', [
            _pair(
              TextFormField(
                controller: _ack,
                decoration: _dec(
                    'Acknowledged by (name)', Icons.engineering_rounded,
                    hint: 'e.g. Juan Dela Cruz'),
              ),
              TextFormField(
                controller: _ackTitle,
                decoration: _dec('Designation', Icons.badge_outlined,
                    hint: 'e.g. Electrician'),
              ),
            ),
          ]),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _actionBar(),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(width >= 600 ? 28 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: showPreview
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: formColumn),
                            const SizedBox(width: 24),
                            SizedBox(width: 340, child: _preview()),
                          ],
                        )
                      : formColumn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
