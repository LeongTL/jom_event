import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/models/event_summary.dart';
import '../domain/home_feed.dart';

/// One tab for one place: the top nine events (events.feed) and the headline numbers (events.hero_stats).
final homeFeedProvider = FutureProvider.autoDispose.family<HomeFeed, HomeQuery>((ref, q) async {
  final events = ref.watch(supabaseClientProvider).schema('events');
  final params = {'p_tab': q.tab.name, 'p_lat': q.lat, 'p_lng': q.lng, 'p_km': q.km};
  final results = await Future.wait([events.rpc('feed', params: params), events.rpc('hero_stats', params: params)]);
  return HomeFeed(
    tab: q.tab,
    top9: [for (final row in results[0] as List) EventSummary.fromJson(row as Map<String, dynamic>)],
    stats: HeroStats.fromJson((results[1] as List).first as Map<String, dynamic>),
  );
});
