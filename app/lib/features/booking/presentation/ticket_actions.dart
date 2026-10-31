import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/launcher.dart';
import '../../../core/theme/calm.dart';
import '../../event/data/event_repository.dart';
import '../data/calendar.dart';
import '../domain/ticket.dart';
import 'cancel_sheet.dart';

/// Directions and Add to calendar side by side, and a quiet "Cancel booking" link while the free window is open.
class TicketActions extends ConsumerWidget {
  const TicketActions({super.key, required this.ticket, this.onCancelled});
  final Ticket ticket;
  final VoidCallback? onCancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ticket.booking, e = ticket.event;
    final now = ref.read(nowProvider)();
    final canCancel =
        b.status == 'confirmed' &&
        b.cancelCutoffAt != null &&
        now.isBefore(b.cancelCutoffAt!);
    Widget button(Key key, IconData icon, String label, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            key: key,
            onTap: onTap,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Calm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Calm.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Calm.acc),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        children: [
          Row(
            children: [
              button(
                const Key('ticket-directions'),
                Icons.place_outlined,
                'Directions',
                () {
                  final dest = e.lat != null && e.lng != null
                      ? '${e.lat},${e.lng}'
                      : [e.area].whereType<String>().join(' ');
                  if (dest.isNotEmpty) {
                    ref.read(launchUrlProvider)(
                      Uri.https('www.google.com', '/maps/dir/', {
                        'api': '1',
                        'destination': dest,
                      }),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              button(
                const Key('ticket-calendar'),
                Icons.calendar_today_outlined,
                'Add to calendar',
                () async {
                  final d = await ref.read(eventDetailProvider(e.id).future);
                  if (d != null) await ref.read(addToCalendarProvider)(d);
                },
              ),
            ],
          ),
          if (canCancel)
            GestureDetector(
              key: const Key('ticket-cancel'),
              onTap: () async {
                if (await showCancelSheet(context, b) == true) {
                  onCancelled?.call();
                }
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Text(
                  'Cancel booking',
                  style: TextStyle(
                    color: Calm.faint,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Calm.faint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
