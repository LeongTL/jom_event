import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../event/domain/event_labels.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import 'complete_sheet.dart';
import 'delete_sheet.dart';
import 'host_parts.dart';

/// Host mode: one event (/host-mode/events/:id). Numbers, scan and guest list, details, complete and delete.
class HostEventScreen extends ConsumerWidget {
  const HostEventScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    key: const Key('host-event'),
    backgroundColor: Calm.bg,
    body: ref
        .watch(hostEventProvider(id))
        .when(
          loading: hostLoading,
          error: (_, _) => hostFailed('this event'),
          data: (e) => e == null ? hostFailed('this event') : _Body(e),
        ),
  );
}

class _Body extends ConsumerWidget {
  const _Body(this.e);
  final HostEventRow e;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (await showDeleteSheet(context, e) != true) return;
    ref.invalidate(hostEventsProvider);
    ref.invalidate(hostDashboardProvider);
    if (context.mounted) context.go('/host-mode/events');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider)();
    final cap = e.capacity ?? 1;
    final guests = ref.watch(hostGuestsProvider(e.id)).value ?? const <Guest>[];
    final earnings = ref.watch(hostEarningsProvider(e.id)).value;
    final checked = guests
        .where((g) => g.checkedIn)
        .fold(0, (n, g) => n + g.people);
    final isEnded = e.status == 'ended';
    final over = e.endsAt != null && !now.isBefore(e.endsAt!);
    final started = e.startsAt != null && !now.isBefore(e.startsAt!);
    final free = (e.priceSen ?? 0) == 0;
    final noShows = guests.where((g) => !g.checkedIn).length;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: CategoryArt(kind: artKindFor(e.id, e.categories)),
                ),
                Positioned(
                  left: 20,
                  top: MediaQuery.paddingOf(context).top + 5,
                  child: GestureDetector(
                    key: const Key('nav-back'),
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/host-mode/events'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chevron_left, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Pill(
                        isEnded ? 'Ended' : 'Published',
                        Calm.okSoft,
                        Calm.ok,
                      ),
                      _Pill(
                        '${e.seatsSold} / $cap ${free ? 'joined' : 'paid'}',
                        Calm.chip,
                        Calm.mut,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.title,
                    style: const TextStyle(
                      fontFamily: Calm.serif,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (e.startsAt != null)
                    Text(
                      '${dayLabel(e.startsAt!, now)} · ${timeLabel(e.startsAt!)} – ${timeLabel(e.endsAt!)}\n${e.area ?? ''} · ${e.venue ?? ''}',
                      style: const TextStyle(color: Calm.mut, height: 1.4),
                    ),
                  const SizedBox(height: 14),
                  FillBar((e.seatsSold / cap).clamp(0, 1).toDouble()),
                  const SizedBox(height: 6),
                  Text(
                    e.seatsSold >= cap
                        ? 'Full'
                        : '${cap - e.seatsSold} spots left',
                    style: const TextStyle(color: Calm.mut, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          const Key('tile-joined'),
                          '${e.seatsSold}',
                          'joined',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          const Key('tile-checked'),
                          '$checked',
                          'checked in',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          const Key('tile-gross'),
                          rm(earnings?.gross ?? 0),
                          'gross',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (!isEnded) ...[
                        Expanded(
                          child: KeyedSubtree(
                            key: const Key('scan-button'),
                            child: JomButton(
                              label: 'Scan tickets',
                              onPressed: () => context.push(
                                '/host-mode/events/${e.id}/scan',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: JomButton(
                          label: 'Guest list',
                          primary: false,
                          onPressed: () =>
                              context.push('/host-mode/events/${e.id}/guests'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CardBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Event details',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (!isEnded)
                              GestureDetector(
                                key: const Key('edit-event'),
                                onTap: () => context.push(
                                  '/host-mode/events/${e.id}/edit',
                                ),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Calm.acc,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if ((e.description ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(e.description!),
                          ),
                        MoneyLine(
                          'Price',
                          free ? 'Free' : '${rm(e.priceSen!)} per person',
                        ),
                        MoneyLine('Refunds', _refund(e.cancelPolicy)),
                        KeyedSubtree(
                          key: const Key('payout-line'),
                          child: MoneyLine(
                            'Payout',
                            '${rm(earnings?.receives ?? 0)} · 3 days after',
                          ),
                        ),
                      ],
                    ),
                  ),
                  CardBox(
                    onTap: () => context.go('/host-mode/chats'),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Messages',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('›', style: TextStyle(color: Calm.mut)),
                      ],
                    ),
                  ),
                  if (!isEnded)
                    const SoftNote(
                      "Once the event ends, tap Mark as completed. If you don't, it completes automatically 24 hours after the end time.",
                    ),
                  if (!isEnded && !started)
                    Center(
                      child: TextButton(
                        key: const Key('delete-event'),
                        onPressed: () => _delete(context, ref),
                        child: const Text(
                          'Delete this event',
                          style: TextStyle(
                            color: Calm.bad,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (!isEnded)
          CtaBar(
            column: true,
            children: [
              KeyedSubtree(
                key: const Key('complete-button'),
                child: JomButton(
                  label: 'Mark as completed',
                  onPressed: over
                      ? () => completeAndLeave(context, ref, e, noShows)
                      : null,
                ),
              ),
              if (!over && e.endsAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'You can mark it completed after it ends at ${timeLabel(e.endsAt!)}.',
                    style: const TextStyle(color: Calm.mut, fontSize: 12.5),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

String _refund(String policy) => switch (policy) {
  '24h' => 'Up to 24 hours before',
  '48h' => 'Up to 48 hours before',
  '7d' => 'Up to 7 days before',
  _ => 'No refunds',
};

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
    ),
  );
}
