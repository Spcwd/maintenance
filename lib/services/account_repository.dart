import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class AccountRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Profile of the person who is signed in (null if signed out).
  Future<Profile?> myProfile() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _db.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  /// All accounts (admin only - other users get nothing back).
  Future<List<Profile>> fetchAll() async {
    final rows = await _db
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return rows.map<Profile>((r) => Profile.fromMap(r)).toList();
  }

  /// Approve / block / unblock. status = 'approved' | 'blocked' | 'pending'.
  Future<void> setStatus(String id, String status) async {
    final rows = await _db
        .from('profiles')
        .update({'status': status})
        .eq('id', id)
        .select();
    if (rows.isEmpty) {
      throw Exception('Not allowed (only the admin can do this)');
    }
  }

  /// Permanently delete an account (admin only).
  Future<void> deleteAccount(String id) async {
    await _db.rpc('admin_delete_user', params: {'target': id});
  }

  /// Change any account password through the admin-only Edge Function.
  Future<void> setPassword(String id, String password) async {
    await _db.functions.invoke(
      'admin-set-password',
      body: {'userId': id, 'password': password},
    );
  }
}
