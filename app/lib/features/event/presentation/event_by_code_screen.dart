import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/event_repository.dart';
import '../domain/event_detail.dart';
import 'event_screen.dart';

final eventByCodeProvider = FutureProvider.autoDispose
    .family<EventDetail?, String>((ref, code) async {
      final at = await ref.watch(homeCentreProvider.future);
      return ref.watch(eventRepositoryProvider).byCode(code, at);
    });

/// `/e/:code`: a host's link. Shows the event (private or public) the code opens, or says it is not there.
class EventByCodeScreen extends ConsumerWidget {
  const EventByCodeScreen({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(eventByCodeProvider(code))
      .when(
        loading: () => Scaffold(
          backgroundColor: Calm.bg,
          body: SafeArea(child: Skeleton.page()),
        ),
        error: (_, _) => const _NotFound(
          text: 'Could not load this event. Check your connection.',
        ),
        data: (d) => d == null
            ? const _NotFound(text: 'This event is not available.')
            : EventScreen(id: d.summary.id),
      );
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('event-not-found'),
    backgroundColor: Calm.bg,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Event not found',
              style: TextStyle(
                fontFamily: Calm.serif,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/explore'),
              child: const Text('Back to Explore'),
            ),
          ],
        ),
      ),
    ),
  );
}
