import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/people_repository.dart';

/// "12 Followers  3 Following", each opening its list. Shows 0 until the numbers arrive or if they fail.
class FollowStats extends ConsumerWidget {
  const FollowStats({super.key, required this.userId, required this.idPrefix});
  final String userId;

  /// Keys become `<idPrefix>-followers` and `<idPrefix>-following`.
  final String idPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(followCountsProvider(userId)).value;
    Widget count(String id, String label, int? n, String path) => Expanded(
      child: GestureDetector(
        key: Key('$idPrefix-$id'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/people/$userId/$path'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${n ?? 0} $label',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
    return Row(
      children: [
        count('followers', 'Followers', counts?.followers, 'followers'),
        count('following', 'Following', counts?.following, 'following'),
      ],
    );
  }
}
