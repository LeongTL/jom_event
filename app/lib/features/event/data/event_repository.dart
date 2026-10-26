import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../core/location.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/event_summary.dart';
import '../domain/event_detail.dart';

/// What the event screens read and change. Tests replace it; [SupabaseEventRepository] is the real one.
abstract class EventRepository {
  /// Every upcoming or live event near [at], soonest first (events.list_all).
  Future<List<EventSummary>> listAll(String category, LatLng at, int km);

  /// The cards for known ids, ended events included (events.cards).
  Future<List<EventSummary>> cards(List<String> ids, LatLng at);

  /// One event page, or null when the event is a draft, cancelled or unknown.
  Future<EventDetail?> detail(String id, LatLng at);

  /// The ids the signed-in user has hearted.
  Future<Set<String>> savedIds();

  /// The hearted events (ended ones included), soonest first; distance is measured on the phone from [at].
  Future<List<EventSummary>> saved(LatLng at);

  /// Hearts or un-hearts; returns the new state.
  Future<bool> toggleSave(String id);

  /// The chat thread between the user and a host about an event (chat.open_thread).
  Future<String> openThread(String hostId, String eventId);
}

final eventRepositoryProvider = Provider<EventRepository>((ref) => SupabaseEventRepository(ref));

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _db => _ref.read(supabaseClientProvider);

  @override
  Future<List<EventSummary>> listAll(String category, LatLng at, int km) async {
    final rows = await _db.schema('events').rpc('list_all', params: {
      'p_lat': at.lat, 'p_lng': at.lng, 'p_category': category, 'p_km': km,
    }) as List;
    return [for (final r in rows) EventSummary.fromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<List<EventSummary>> cards(List<String> ids, LatLng at) async {
    final rows = await _db.schema('events').rpc('cards', params: {'p_ids': ids, 'p_lat': at.lat, 'p_lng': at.lng}) as List;
    return [for (final r in rows) EventSummary.fromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<EventDetail?> detail(String id, LatLng at) async {
    final rows = await _db.schema('events').rpc('event_detail', params: {
      'p_event_id': id, 'p_lat': at.lat, 'p_lng': at.lng,
    }) as List;
    return rows.isEmpty ? null : EventDetail.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<Set<String>> savedIds() async {
    final rows = await _db.schema('identity').from('saved_events').select('event_id') as List;
    return {for (final r in rows) r['event_id'] as String};
  }

  @override
  Future<List<EventSummary>> saved(LatLng at) async {
    final ids = await savedIds();
    if (ids.isEmpty) return const [];
    final rows = await _db.schema('events').from('events')
        .select('id, title, glyph, color_a, color_b, starts_at, ends_at, price_sen, area, lat, lng, status, categories')
        .inFilter('id', ids.toList()) as List;
    final now = DateTime.now().toUtc();
    final list = <EventSummary>[
      for (final r in rows)
        EventSummary.fromJson({
          ...r as Map<String, dynamic>,
          'event_id': r['id'],
          'price_sen': r['price_sen'] ?? 0,
          'distance_km': r['lat'] == null ? null : _km(at, r['lat'] as num, r['lng'] as num),
          'is_live': DateTime.parse(r['starts_at'] as String).isBefore(now) && DateTime.parse(r['ends_at'] as String).isAfter(now),
          'spots_left': 0, // a saved poster shows no seat count
          'score': 0,
        }),
    ];
    list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  @override
  Future<bool> toggleSave(String id) async =>
      await _db.schema('identity').rpc('toggle_save', params: {'event_id': id}) as bool;

  @override
  Future<String> openThread(String hostId, String eventId) async =>
      await _db.schema('chat').rpc('open_thread', params: {'p_host_id': hostId, 'p_event_id': eventId}) as String;
}

// great-circle distance, enough for "1.2 km away"
double _km(LatLng a, num lat, num lng) {
  const r = 6371.0, p = math.pi / 180;
  final dLat = (lat - a.lat) * p, dLng = (lng - a.lng) * p;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(a.lat * p) * math.cos(lat * p) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

/// Every upcoming or live event near the user, for View all. The chips and sections filter this one list.
final viewAllProvider = FutureProvider.autoDispose<List<EventSummary>>((ref) async {
  final at = await ref.watch(homeCentreProvider.future);
  return ref.watch(eventRepositoryProvider).listAll('all', at, ref.watch(areaSelectionProvider).km);
});

final eventDetailProvider = FutureProvider.autoDispose.family<EventDetail?, String>((ref, id) async {
  final at = await ref.watch(homeCentreProvider.future);
  return ref.watch(eventRepositoryProvider).detail(id, at);
});
