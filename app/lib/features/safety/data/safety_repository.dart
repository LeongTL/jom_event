import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../domain/safety.dart';

/// Report and block. Tests replace it; [SupabaseSafetyRepository] is the real one.
abstract class SafetyRepository {
  Future<void> block(String userId);
  Future<void> unblock(String userId);
  Future<List<BlockedUser>> blocked();
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? note,
  });
}

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _db => _ref.read(supabaseClientProvider);

  Future<dynamic> _rpc(String fn, [Map<String, dynamic>? params]) =>
      _db.schema('identity').rpc(fn, params: params);

  @override
  Future<void> block(String userId) =>
      _rpc('block_user', {'p_user_id': userId});

  @override
  Future<void> unblock(String userId) =>
      _rpc('unblock_user', {'p_user_id': userId});

  @override
  Future<List<BlockedUser>> blocked() async => [
    for (final r in await _rpc('my_blocks') as List)
      BlockedUser.fromJson(r as Map<String, dynamic>),
  ];

  @override
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? note,
  }) => _rpc('report', {
    'p_target_type': target.wire,
    'p_target_id': targetId,
    'p_reason': reason.wire,
    'p_note': note,
  });
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SupabaseSafetyRepository(ref),
);

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>(
  (ref) => ref.watch(safetyRepositoryProvider).blocked(),
);
