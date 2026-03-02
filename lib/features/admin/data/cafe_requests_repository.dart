import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class CafeRequest {
  final String id;
  final String? userId;
  final String cafeName;
  final String? address;
  final String? note;
  final String status;
  final DateTime createdAt;

  const CafeRequest({
    required this.id,
    this.userId,
    required this.cafeName,
    this.address,
    this.note,
    required this.status,
    required this.createdAt,
  });

  factory CafeRequest.fromJson(Map<String, dynamic> j) => CafeRequest(
        id: j['id'] as String,
        userId: j['user_id'] as String?,
        cafeName: j['cafe_name'] as String,
        address: j['address'] as String?,
        note: j['note'] as String?,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class CafeRequestsRepository {
  final SupabaseClient _client;
  CafeRequestsRepository(this._client);

  /// Submit a new cafe addition request (user-facing).
  Future<void> submitRequest({
    required String cafeName,
    String? address,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('cafe_requests').insert({
      'user_id': uid,
      'cafe_name': cafeName,
      if (address != null && address.isNotEmpty) 'address': address,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Fetch all pending requests (admin only — requires service role or RLS bypass).
  Future<List<CafeRequest>> fetchPending() async {
    final data = await _client
        .from('cafe_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (data as List).map((e) => CafeRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Update request status (admin only).
  Future<void> updateStatus(String id, String status) async {
    await _client.from('cafe_requests').update({'status': status}).eq('id', id);
  }
}

final cafeRequestsRepositoryProvider = Provider<CafeRequestsRepository>(
  (ref) => CafeRequestsRepository(ref.watch(supabaseClientProvider)),
);
