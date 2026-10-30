import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../domain/event_form_state.dart';
import '../domain/host.dart';

/// What the host screens read and write. Tests replace it; [SupabaseHostRepository] is the real one. Writes throw [HostError].
abstract class HostRepository {
  /// My host profile, or null when I have not applied yet.
  Future<HostProfile?> me();
  Future<void> apply(HostApplication a);
  Future<HostDashboard> dashboard();

  /// draft | published | ended
  Future<List<HostEventRow>> events(String status);
  Future<HostEventRow?> event(String id);

  /// Creates a draft, or saves [id]. Returns the event id.
  Future<String> saveDraft(EventForm f, {String? id});
  Future<void> publish(String id);
  Future<void> update(
    String id, {
    String? title,
    String? description,
    int? capacity,
  });

  /// What guests have paid for the event so far, in sen (for the delete sheet).
  Future<int> grossSen(String id);
  Future<DeleteResult> delete(String id);
}

class SupabaseHostRepository implements HostRepository {
  SupabaseHostRepository(this._db);
  final SupabaseClient _db;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw HostError(e.message);
    }
  }

  @override
  Future<HostProfile?> me() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final h = await _db
        .schema('identity')
        .from('hosts')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (h == null) return null;
    final a = await _db
        .schema('identity')
        .from('host_payout_accounts')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    final r = await _db
        .schema('reviews')
        .from('host_rating')
        .select('average, count')
        .eq('host_id', uid)
        .maybeSingle();
    return HostProfile(
      id: uid,
      name: h['host_name'] as String,
      area: h['area'] as String,
      bio: h['bio'] as String?,
      ssm: h['ssm_number'] as String?,
      holder: (a?['account_holder'] as String?) ?? '',
      bank: (a?['bank'] as String?) ?? '',
      accountNumber: (a?['account_number'] as String?) ?? '',
      ratingAvg: (r?['average'] as num?)?.toDouble(),
      ratingCount: (r?['count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> apply(HostApplication a) => _guard(
    () => _db
        .schema('identity')
        .rpc(
          'apply_host',
          params: {
            'host_name': a.name,
            'area': a.area,
            'bio': a.bio,
            'account_holder': a.holder,
            'bank': a.bank,
            'account_number': a.accountNumber,
            'ssm_number': a.ssm,
          },
        ),
  );

  @override
  Future<HostDashboard> dashboard() async {
    final me = (await this.me())!;
    final summary =
        await _db.schema('payments').rpc('host_payout_summary') as List;
    final live = await events('published');
    final now = DateTime.now().toUtc();
    return HostDashboard(
      profile: me,
      upcomingPayoutSen: (summary.first['upcoming_sen'] as num).toInt(),
      guests: live.fold(0, (sum, e) => sum + e.seatsSold),
      next: live
          .where((e) => e.endsAt != null && e.endsAt!.isAfter(now))
          .firstOrNull,
    );
  }

  Future<List<HostEventRow>> _rows(Map<String, dynamic> params) async => [
    for (final r
        in await _db.schema('events').rpc('host_events', params: params)
            as List)
      HostEventRow.fromJson(r as Map<String, dynamic>),
  ];

  @override
  Future<List<HostEventRow>> events(String status) =>
      _rows({'p_status': status});

  @override
  Future<HostEventRow?> event(String id) async =>
      (await _rows({'p_event_id': id})).firstOrNull;

  @override
  Future<String> saveDraft(EventForm f, {String? id}) => _guard(
    () async =>
        await _db
                .schema('events')
                .rpc('save_draft', params: {'payload': f.toPayload(id)})
            as String,
  );

  @override
  Future<void> publish(String id) => _guard(
    () => _db.schema('events').rpc('publish', params: {'event_id': id}),
  );

  @override
  Future<void> update(
    String id, {
    String? title,
    String? description,
    int? capacity,
  }) => _guard(
    () => _db
        .schema('events')
        .rpc(
          'update_event',
          params: {
            'event_id': id,
            'title': title,
            'description': description,
            'capacity': capacity,
          },
        ),
  );

  @override
  Future<int> grossSen(String id) async {
    final rows =
        await _db
                .schema('payments')
                .rpc('event_earnings', params: {'p_event_id': id})
            as List;
    return (rows.first['gross_sen'] as num).toInt();
  }

  @override
  Future<DeleteResult> delete(String id) => _guard(() async {
    final r =
        await _db
                .schema('events')
                .rpc('delete_event', params: {'p_event_id': id})
            as Map<String, dynamic>;
    return DeleteResult(
      refunded: (r['refunded'] as num).toInt(),
      released: (r['released'] as num).toInt(),
    );
  });
}

final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => SupabaseHostRepository(ref.watch(supabaseClientProvider)),
);

final hostMeProvider = FutureProvider.autoDispose<HostProfile?>(
  (ref) => ref.watch(hostRepositoryProvider).me(),
);
final hostDashboardProvider = FutureProvider.autoDispose<HostDashboard>(
  (ref) => ref.watch(hostRepositoryProvider).dashboard(),
);
final hostEventsProvider = FutureProvider.autoDispose
    .family<List<HostEventRow>, String>(
      (ref, status) => ref.watch(hostRepositoryProvider).events(status),
    );
final hostEventProvider = FutureProvider.autoDispose
    .family<HostEventRow?, String>(
      (ref, id) => ref.watch(hostRepositoryProvider).event(id),
    );
