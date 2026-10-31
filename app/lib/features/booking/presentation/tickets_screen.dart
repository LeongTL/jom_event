import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../event/domain/event_labels.dart';
import '../data/booking_repository.dart';
import '../domain/ticket.dart';
import 'ticket_actions.dart';
import 'ticket_card.dart';
import '../../../shared/widgets/skeleton.dart';

/// The Tickets tab: Upcoming tickets grouped by day, each a full ticket, and Previous bookings as plain rows.
class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final scope = _past ? TicketScope.past : TicketScope.upcoming;
    Widget seg(String label, bool past) => Expanded(
      child: GestureDetector(
        key: Key('seg-${past ? 'past' : 'upcoming'}'),
        onTap: () => setState(() => _past = past),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _past == past ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: _past == past
                ? const [
                    BoxShadow(
                      color: Color(0x1F1B2430),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: _past == past ? FontWeight.w600 : FontWeight.w500,
              color: _past == past ? Calm.ink : Calm.mut,
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      key: const Key('tickets-screen'),
      backgroundColor: Calm.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 12,
          20,
          40,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 2, 0, 14),
            child: Text(
              'Tickets',
              style: TextStyle(
                fontFamily: Calm.serif,
                fontSize: 30,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Calm.chip,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [seg('Upcoming', false), seg('Previous', true)],
            ),
          ),
          ref
              .watch(ticketsProvider(scope))
              .when(
                loading: () => Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Skeleton.rows(2),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      'Could not load your tickets. Check your connection.',
                    ),
                  ),
                ),
                data: (list) => _past
                    ? _Previous(list)
                    : _Upcoming(
                        list,
                        onChanged: () => ref.invalidate(ticketsProvider),
                      ),
              ),
        ],
      ),
    );
  }
}

class _Upcoming extends ConsumerWidget {
  const _Upcoming(this.tickets, {required this.onChanged});
  final List<Ticket> tickets;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tickets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            const Text(
              'No upcoming tickets.\nFind something to do tonight.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Calm.mut, fontSize: 14),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 170,
              child: JomButton(
                label: 'Explore events',
                onPressed: () => context.go('/explore'),
              ),
            ),
          ],
        ),
      );
    }
    final groups = groupByDay(tickets, ref.read(nowProvider)());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
            child: Text(
              g.key,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.15,
                color: Calm.faint,
              ),
            ),
          ),
          for (final t in g.value) ...[
            TicketCard(ticket: t),
            TicketActions(ticket: t, onCancelled: onChanged),
          ],
        ],
      ],
    );
  }
}

class _Previous extends StatelessWidget {
  const _Previous(this.tickets);
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: Text('No previous tickets', style: TextStyle(color: Calm.mut)),
        ),
      );
    }
    return Column(
      children: [
        for (final t in tickets) _PreviousRow(t),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Tap an attended event to write a review',
            style: TextStyle(fontSize: 13, color: Calm.mut),
          ),
        ),
      ],
    );
  }
}

class _PreviousRow extends StatelessWidget {
  const _PreviousRow(this.t);
  final Ticket t;

  @override
  Widget build(BuildContext context) {
    final e = t.event, b = t.booking;
    return GestureDetector(
      key: Key('booking-${b.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: b.status == 'attended'
          ? () => context.push('/review/${b.id}')
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Calm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Calm.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: EventArt(
                  posterUrl: e.posterUrl,
                  kind: artKindFor(e.id, e.categories),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      if (e.hostName != null) e.hostName!,
                      dateLabel(e.startsAt),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Calm.mut),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill.booking(b.status),
          ],
        ),
      ),
    );
  }
}
