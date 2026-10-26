import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../domain/saved_controller.dart';
import 'poster_card.dart';

/// The Saved tab: a two-column grid of hearted events. Ended ones stay, dimmed and tagged "Ended".
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final now = ref.read(nowProvider)();
    return Scaffold(
      key: const Key('saved-screen'),
      backgroundColor: k.sheet,
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 5, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 14),
            child: Text('Saved', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.2, height: 40 / 20)),
          ),
          Expanded(
            child: ref.watch(savedEventsProvider).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(child: Text('Could not load your saved events. Check your connection.')),
                  data: (list) => list.isEmpty
                      ? const Center(child: Text('Nothing saved yet'))
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 120),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 200),
                          itemCount: list.length,
                          itemBuilder: (_, i) => PosterCard(
                            event: list[i],
                            ended: list[i].endsAt.isBefore(now),
                            onTap: () => context.push('/event/${list[i].id}'),
                          ),
                        ),
                ),
          ),
        ]),
      ),
    );
  }
}
