import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/safety_repository.dart';

/// Profile > Blocked users: who I blocked, each with Unblock.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(blockedUsersProvider);
    return Scaffold(
      key: const Key('blocked-users-screen'),
      backgroundColor: Calm.bg,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const BookingNav(title: 'Blocked users'),
          list.when(
            loading: () => Skeleton.rows(2),
            error: (_, _) => const Text(
              'Could not load this list. Check your connection.',
              style: TextStyle(color: Calm.mut),
            ),
            data: (rows) => rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'You have not blocked anyone.',
                      style: TextStyle(color: Calm.mut),
                    ),
                  )
                : Column(
                    children: [
                      for (final b in rows)
                        CardBox(
                          key: Key('blocked-users-row-${b.userId}'),
                          gap: 8,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (b.username != null)
                                      Text(
                                        '@${b.username}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Calm.mut,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                key: Key('unblock-${b.userId}'),
                                onPressed: () async {
                                  await ref
                                      .read(safetyRepositoryProvider)
                                      .unblock(b.userId);
                                  ref.invalidate(blockedUsersProvider);
                                },
                                child: const Text('Unblock'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
