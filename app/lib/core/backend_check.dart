import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/event_summary.dart';
import 'supabase_client.dart';

/// What the app reads from the backend right now. Temporary: it lets the Explore placeholder prove the app is
/// connected and that EventSummary matches real rows; Task 15 replaces the screen and this goes with it.
class BackendCheck {
  const BackendCheck({required this.totalEvents, required this.now});
  final int totalEvents;
  final List<EventSummary> now;
}

// Bangsar, 50 km: the whole of KL and Selangor. Fixed on purpose: this check never asks the phone for its location.
const _bangsar = {'p_lat': 3.129, 'p_lng': 101.671, 'p_km': 50};

final backendCheckProvider = FutureProvider.autoDispose<BackendCheck>((ref) async {
  final events = ref.watch(supabaseClientProvider).schema('events');
  final counts = await events.rpc('tab_counts', params: _bangsar) as List;
  final feed = await events.rpc('feed', params: {'p_tab': 'now', ..._bangsar}) as List;
  return BackendCheck(
    totalEvents: counts.cast<Map<String, dynamic>>().firstWhere((r) => r['tab'] == 'all')['n'] as int,
    now: [for (final row in feed) EventSummary.fromJson(row as Map<String, dynamic>)],
  );
});
