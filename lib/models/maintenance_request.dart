import 'package:flutter/material.dart';

const List<String> requestTypes = [
  'Electrical',
  'Plumbing',
  'HVAC',
  'Civil',
  'Relocation',
  'Repair',
];

const List<String> priorities = ['Low', 'Normal', 'High', 'Urgent'];
const List<String> statuses = ['Pending', 'In Progress', 'Completed'];

Color statusColor(String status) {
  switch (status) {
    case 'Pending':
      return Colors.blueGrey;
    case 'In Progress':
      return Colors.orange;
    case 'Completed':
      return Colors.green;
    default:
      return Colors.blueGrey;
  }
}

Color priorityColor(String p) {
  switch (p) {
    case 'Urgent':
      return Colors.red;
    case 'High':
      return Colors.deepOrange;
    case 'Normal':
      return Colors.blue;
    case 'Low':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

IconData typeIcon(String type) {
  switch (type.toLowerCase()) {
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
      return Icons.build_rounded;
    default:
      return Icons.assignment_rounded;
  }
}

String formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// 12-hour time with AM/PM, e.g. 3:05 PM
String formatTime12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ap';
}

/// e.g. Nov 10, 2026  3:05 PM
String formatDateTime(DateTime d) => '${formatDate(d)}  ${formatTime12(d)}';

class MaintenanceRequest {
  final String id;
  DateTime date;
  String addressedTo;
  String requesterName;
  String designation;
  String location;
  String type;
  String priority;
  String subject;
  String details;
  String reason;
  String status;
  DateTime? completedAt;
  String addressedTitle;

  MaintenanceRequest({
    required this.id,
    required this.date,
    required this.addressedTo,
    required this.requesterName,
    required this.designation,
    required this.location,
    required this.type,
    required this.priority,
    required this.subject,
    required this.details,
    required this.reason,
    this.status = 'Pending',
    this.completedAt,
    this.addressedTitle = 'Dept. Manager',
  });

  /// Row coming from Supabase -> app object.
  factory MaintenanceRequest.fromMap(Map<String, dynamic> m) {
    return MaintenanceRequest(
      id: m['id'] as String,
      date: DateTime.parse((m['requested_at'] ?? m['date']) as String).toLocal(),
      addressedTo: m['addressed_to'] as String,
      requesterName: m['requester_name'] as String,
      designation: m['designation'] as String,
      location: m['location'] as String,
      type: m['type'] as String,
      priority: m['priority'] as String,
      subject: m['subject'] as String,
      details: m['details'] as String,
      reason: (m['reason'] as String?) ?? '',
      status: (m['status'] as String?) ?? 'Pending',
      completedAt: m['completed_at'] == null
          ? null
          : DateTime.parse(m['completed_at'] as String).toLocal(),
      addressedTitle: (m['addressed_title'] as String?) ?? 'Dept. Manager',
    );
  }

  /// App object -> row to send to Supabase.
  Map<String, dynamic> toMap() {
    final y = date.year.toString().padLeft(4, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return {
      'id': id,
      'date': '$y-$mo-$d',
      'requested_at': date.toUtc().toIso8601String(),
      'addressed_to': addressedTo,
      'requester_name': requesterName,
      'designation': designation,
      'location': location,
      'type': type,
      'priority': priority,
      'subject': subject,
      'details': details,
      'reason': reason,
      'status': status,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'addressed_title': addressedTitle,
    };
  }
}