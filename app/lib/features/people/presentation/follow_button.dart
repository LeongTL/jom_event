import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/jom_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_gate.dart';
import '../data/people_repository.dart';

/// Follow / Following. Signed-out visitors get the sign-in sheet first. Hidden on my own page.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy =
      false; // one call at a time, so a double tap cannot follow and unfollow

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await requireAuth(ref, context, AuthReason.follow)) return;
      final counts = followCountsProvider(widget.userId);
      ref.invalidate(counts); // after a sign-in the answer may differ
      final following = (await ref.read(counts.future)).iFollow;
      final repo = ref.read(peopleRepositoryProvider);
      following
          ? await repo.unfollow(widget.userId)
          : await repo.follow(widget.userId);
      ref.invalidate(counts);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value?.user.id == widget.userId) {
      return const SizedBox.shrink();
    }
    final following =
        ref.watch(followCountsProvider(widget.userId)).value?.iFollow ?? false;
    return SizedBox(
      width: 160,
      child: KeyedSubtree(
        key: const Key('follow-button'),
        child: JomButton(
          label: following ? 'Following' : 'Follow',
          primary: !following,
          onPressed: _tap,
        ),
      ),
    );
  }
}
