import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/host_repository.dart';
import 'host_parts.dart';

/// Host mode: receipts waiting for a decision (/host-mode/receipts, optionally with an event query).
class PendingReceiptsScreen extends ConsumerWidget {
  const PendingReceiptsScreen({super.key, this.eventId});
  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    key: const Key('receipts-screen'),
    backgroundColor: Calm.bg,
    body: ref
        .watch(pendingReceiptsProvider(eventId))
        .when(
          loading: hostLoading,
          error: (_, _) => hostFailed('the receipts'),
          data: (rows) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              const BookingNav(title: 'Receipts to check'),
              if (rows.isEmpty)
                const Text(
                  'No receipts waiting',
                  style: TextStyle(color: Calm.mut),
                ),
              for (final r in rows)
                CardBox(
                  key: Key('receipt-row-${r.id}'),
                  gap: 8,
                  onTap: () => context.push('/host-mode/receipts/${r.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.guestName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${r.eventTitle} · ${rm(r.amountSen)}',
                              style: const TextStyle(
                                color: Calm.mut,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (r.late)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Calm.warnSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Late',
                            style: TextStyle(
                              color: Calm.warn,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
  );
}
