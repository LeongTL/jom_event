import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location.dart';
import '../../../shared/models/event_summary.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_gate.dart';
import '../data/event_repository.dart';

/// Every heart in the app (posters, event hero, bottom bar, Saved tab) reads this one set. Signed out it is empty.
final savedProvider = AsyncNotifierProvider<SavedController, Set<String>>(
  SavedController.new,
);

class SavedController extends AsyncNotifier<Set<String>> {
  final _inFlight = <String>{};

  @override
  Future<Set<String>> build() async {
    if (await ref.watch(sessionProvider.future) == null) return {};
    return ref.watch(eventRepositoryProvider).savedIds();
  }

  /// Flips one heart. A second tap on the same event while the first is still travelling is ignored, so a
  /// double tap cannot save then immediately un-save. Callers ask for sign-in first (see [toggleHeart]).
  Future<void> toggle(String eventId) async {
    if (!_inFlight.add(eventId)) return;
    try {
      final saved = await ref.read(eventRepositoryProvider).toggleSave(eventId);
      state = AsyncData(
        {...(state.value ?? <String>{})}..update(eventId, saved),
      );
    } finally {
      _inFlight.remove(eventId);
    }
  }
}

extension on Set<String> {
  void update(String id, bool present) => present ? add(id) : remove(id);
}

/// What a tap on any heart does: ask for sign-in if needed ("Sign in to save"), then flip the heart.
Future<void> toggleHeart(
  WidgetRef ref,
  BuildContext context,
  String eventId,
) async {
  if (!await requireAuth(ref, context, AuthReason.save)) return;
  await ref.read(
    savedProvider.future,
  ); // right after signing in the set is still loading
  await ref.read(savedProvider.notifier).toggle(eventId);
}

/// The hearted events for the Saved tab; refetches when a heart changes.
final savedEventsProvider = FutureProvider.autoDispose<List<EventSummary>>((
  ref,
) async {
  ref.watch(savedProvider);
  final at = await ref.watch(homeCentreProvider.future);
  return ref.watch(eventRepositoryProvider).saved(at);
});
