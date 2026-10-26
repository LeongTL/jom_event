import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
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
            decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: k.line)),
            child: Icon(Icons.notifications_none, size: 22, color: k.sheetInk),
          ),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                key: const Key('bell-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Calm.badge, borderRadius: BorderRadius.circular(9), border: Border.all(color: Calm.bg, width: 2)),
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
