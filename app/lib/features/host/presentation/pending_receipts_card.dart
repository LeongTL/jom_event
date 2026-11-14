import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../data/host_repository.dart';

/// "3 receipts to check", for all events or one. Hidden when nothing waits. Opens the receipts list.
class PendingReceiptsCard extends ConsumerWidget {
  const PendingReceiptsCard({super.key, this.eventId});
  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pendingReceiptsProvider(eventId)).value?.length ?? 0;
    if (n == 0) return const SizedBox.shrink();
    return GestureDetector(
      key: const Key('pending-receipts-card'),
      onTap: () => context.push(
        eventId == null
            ? '/host-mode/receipts'
            : '/host-mode/receipts?event=$eventId',
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Calm.warnSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: Calm.warn),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                n == 1 ? '1 receipt to check' : '$n receipts to check',
                style: const TextStyle(
                  color: Calm.warn,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Calm.warn),
          ],
        ),
      ),
    );
  }
}
