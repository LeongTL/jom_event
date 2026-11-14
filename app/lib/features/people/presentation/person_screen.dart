import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/people_repository.dart';
import '../domain/person.dart';
import 'follow_button.dart';
import 'person_row.dart';

/// A guest's small public page: who they are, Follow, and the follower counts. A host id goes to the host page.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    key: const Key('person-screen'),
    backgroundColor: Calm.bg,
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const BookingNav(title: 'Profile'),
        ref
            .watch(personProvider(userId))
            .when(
              loading: () => Skeleton.rows(2),
              error: (_, _) => const Text(
                'Could not load this profile. Check your connection.',
                style: TextStyle(color: Calm.mut),
              ),
              data: (p) {
                if (p == null) {
                  return const Text(
                    'This profile is not available.',
                    style: TextStyle(color: Calm.mut),
                  );
                }
                if (p.isHost) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => context.pushReplacement('/host/$userId'),
                  );
                  return const SizedBox.shrink();
                }
                return _Page(p);
              },
            ),
      ],
    ),
  );
}

class _Page extends ConsumerWidget {
  const _Page(this.p);
  final Person p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(followCountsProvider(p.userId)).value;
    Widget count(String id, String label, int? n, String path) => Expanded(
      child: GestureDetector(
        key: Key(id),
        onTap: () => context.push('/people/${p.userId}/$path'),
        child: Text(
          '${n ?? 0} $label',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
    return Column(
      children: [
        const SizedBox(height: 10),
        PersonAvatar(p, size: 84),
        const SizedBox(height: 10),
        Text(
          p.name,
          style: const TextStyle(
            fontFamily: Calm.serif,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text('@${p.username}', style: const TextStyle(color: Calm.mut)),
        const SizedBox(height: 16),
        FollowButton(userId: p.userId),
        const SizedBox(height: 16),
        Row(
          children: [
            count(
              'person-followers',
              'Followers',
              counts?.followers,
              'followers',
            ),
            count(
              'person-following',
              'Following',
              counts?.following,
              'following',
            ),
          ],
        ),
      ],
    );
  }
}
