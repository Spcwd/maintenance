import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maintenance_request.dart';

class RequestRepository {
  static const _table = 'maintenance_requests';

  SupabaseClient get _db => Supabase.instance.client;

  /// All saved requests, newest first.
  Future<List<MaintenanceRequest>> fetchAll() async {
    final rows =
        await _db.from(_table).select().order('created_at', ascending: false);
    return rows
        .map<MaintenanceRequest>((r) => MaintenanceRequest.fromMap(r))
        .toList();
  }

  /// Next free ID like MR-002, based on what is already saved.
  Future<String> nextId() async {
    final rows = await _db.from(_table).select('id');
    var max = 0;
    for (final r in rows) {
      final n = int.tryParse((r['id'] as String).replaceAll('MR-', ''));
      if (n != null && n > max) max = n;
    }
    return 'MR-${(max + 1).toString().padLeft(3, '0')}';
  }

  Future<void> insert(MaintenanceRequest r) async {
    await _db.from(_table).insert(r.toMap());
  }

  Future<void> update(MaintenanceRequest r) async {
    final data = r.toMap()..remove('id');
    await _db.from(_table).update(data).eq('id', r.id);
  }

  Future<void> updateStatus(
      String id, String status, DateTime? completedAt) async {
    await _db.from(_table).update({
      'status': status,
      'completed_at': completedAt?.toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }
}