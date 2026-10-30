import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/models/event_summary.dart';
import '../domain/home_query.dart';

/// "This weekend": the best nine events of the weekend (events.feed).
final weekendProvider = FutureProvider.autoDispose
    .family<List<EventSummary>, HomeArea>((ref, a) async {
      final rows =
          await ref
                  .watch(supabaseClientProvider)
                  .schema('events')
                  .rpc(
                    'feed',
                    params: {
                      'p_tab': 'weekend',
                      'p_lat': a.lat,
                      'p_lng': a.lng,
                      'p_km': a.km,
                    },
                  )
              as List;
      return [
        for (final r in rows) EventSummary.fromJson(r as Map<String, dynamic>),
      ];
    });

/// "Near you": every upcoming or live event around the user, nearest first, narrowed by the category tile and the
/// search text (events.list_all).
final nearYouProvider = FutureProvider.autoDispose
    .family<List<EventSummary>, HomeQuery>((ref, q) async {
      final rows =
          await ref
                  .watch(supabaseClientProvider)
                  .schema('events')
                  .rpc(
                    'list_all',
                    params: {
                      'p_lat': q.lat,
                      'p_lng': q.lng,
                      'p_category': q.category ?? 'all',
                      'p_km': q.km,
                      if (q.query.trim().isNotEmpty) 'p_query': q.query.trim(),
                    },
                  )
              as List;
      final list = [
        for (final r in rows) EventSummary.fromJson(r as Map<String, dynamic>),
      ];
      list.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
      return list;
    });

/// The category tile and search text Home is filtered by.
typedef HomeFilter = ({String? category, String query});

class HomeFilterController extends Notifier<HomeFilter> {
  @override
  HomeFilter build() => (category: null, query: '');

  /// Tapping the tile that is already on clears it.
  void toggleCategory(String c) =>
      state = (category: state.category == c ? null : c, query: state.query);
  void setQuery(String q) => state = (category: state.category, query: q);
}

final homeFilterProvider = NotifierProvider<HomeFilterController, HomeFilter>(
  HomeFilterController.new,
);
