import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../domain/bell_provider.dart';

/// The round bell with the unread number, at the top of Explore (and of host Home). Opens Notifications.
class BellButton extends ConsumerWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final unread = ref.watch(bellCountProvider).value ?? 0;
    return GestureDetector(
      key: const Key('bell'),
      onTap: () => context.push('/notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: k.glass, shape: BoxShape.circle, border: Border.all(color: k.glassBorder)),
            child: const Icon(Icons.notifications_none, size: 22),
          ),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                key: const Key('bell-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFFF4D6A), borderRadius: BorderRadius.circular(10)),
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}
