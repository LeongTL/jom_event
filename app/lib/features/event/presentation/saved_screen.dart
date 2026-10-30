import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/skeleton.dart';
import '../domain/saved_controller.dart';
import 'event_cards.dart';

/// The Saved tab: the hearted events as rows. Ended ones stay, dimmed and tagged "Ended".
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(nowProvider)();
    return Scaffold(
      key: const Key('saved-screen'),
      backgroundColor: Calm.bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 5,
          20,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 14),
              child: Text(
                'Saved',
                style: TextStyle(
                  fontFamily: Calm.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ref
                  .watch(savedEventsProvider)
                  .when(
                    loading: () => Skeleton.rows(4),
                    error: (_, _) => const Center(
                      child: Text(
                        'Could not load your saved events. Check your connection.',
                      ),
                    ),
                    data: (list) => list.isEmpty
                        ? const Center(child: Text('Nothing saved yet'))
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 120),
                            children: [
                              for (final e in list)
                                EventRow(
                                  event: e,
                                  ended: e.endsAt.isBefore(now),
                                  heart: true,
                                ),
                            ],
                          ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
