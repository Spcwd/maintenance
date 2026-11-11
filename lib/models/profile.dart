/// One account (row in the `profiles` table).
class Profile {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role; // 'admin' or 'user'
  final String status; // 'pending', 'approved' or 'blocked'
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isApproved => status == 'approved';

  /// Name to show in the app.
  String get displayName {
    final n = fullName.trim();
    if (n.isNotEmpty) return n;
    if (username.isNotEmpty) return username;
    return email.contains('@') ? email.split('@').first : email;
  }

  factory Profile.fromMap(Map<String, dynamic> m) {
    return Profile(
      id: m['id'] as String,
      email: (m['email'] as String?) ?? '',
      username: (m['username'] as String?) ?? '',
      fullName: (m['full_name'] as String?) ?? '',
      role: (m['role'] as String?) ?? 'user',
      status: (m['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    );
  }

  Profile copyWith({String? status}) => Profile(
        id: id,
        email: email,
        username: username,
        fullName: fullName,
        role: role,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
