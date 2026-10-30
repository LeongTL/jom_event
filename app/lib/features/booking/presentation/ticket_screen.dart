import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../event/data/event_repository.dart';
import '../data/booking_repository.dart';
import '../domain/ticket.dart';
import 'ticket_actions.dart';
import 'ticket_card.dart';
import '../../../shared/widgets/skeleton.dart';

/// The QR the host scans: the booking's signed token, fetched for its owner.
final ticketTokenProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, id) => ref.watch(bookingRepositoryProvider).ticketToken(id),
);

/// "You're booked" with the ticket under it; for a booking that is already over or cancelled it just says "Your
/// ticket" and the status.
class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.bookingId, this.fresh = false});
  final String bookingId;
  final bool fresh; // just booked: Done must not step back into the checkout still under this screen

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      key: const Key('ticket-screen'),
      backgroundColor: Calm.bg,
      body: booking.when(
        loading: () => _Plain(Skeleton.box(220)),
        error: (_, _) => const _Plain(
          Text('Could not load this ticket. Check your connection.'),
        ),
        data: (b) => ref
            .watch(eventDetailProvider(b.eventId))
            .when(
              loading: () => _Plain(Skeleton.box(220)),
              error: (_, _) => const _Plain(
                Text('Could not load this ticket. Check your connection.'),
              ),
              // a cancelled booking outlives its event: say that, rather than a bare "not available"
              data: (d) => d == null
                  ? _Plain(
                      Text(
                        b.status == 'cancelled'
                            ? 'This booking was cancelled'
                            : "This event isn't available",
                      ),
                    )
                  : _Ticket(Ticket(b, d.summary), fresh: fresh),
            ),
      ),
    );
  }
}

/// A message in the middle of the screen, under the back bar, so there is always a way out.
class _Plain extends StatelessWidget {
  const _Plain(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        const BookingNav(title: 'Ticket'),
        Expanded(child: Center(child: child)),
      ],
    ),
  );
}

class _Ticket extends StatelessWidget {
  const _Ticket(this.ticket, {required this.fresh});
  final Ticket ticket;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final active = ticket.booking.status == 'confirmed';
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 62, bottom: 18),
                child: Column(
                  children: [
                    if (active) ...[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Calm.okSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 34,
                          color: Calm.ok,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "You're booked",
                        style: TextStyle(
                          fontFamily: Calm.serif,
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Confirmation sent to your email',
                        style: TextStyle(fontSize: 13, color: Calm.mut),
                      ),
                    ] else ...[
                      const Text(
                        'Your ticket',
                        style: TextStyle(
                          fontFamily: Calm.serif,
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TicketCard(ticket: ticket),
              TicketActions(ticket: ticket),
            ],
          ),
        ),
        CtaBar(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: const Key('ticket-done'),
                child: JomButton(
                  label: 'Done',
                  onPressed: () => fresh
                      ? context.go('/tickets')
                      : context.canPop()
                      ? context.pop()
                      : context.go('/explore'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
