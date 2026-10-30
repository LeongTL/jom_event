import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../event/domain/event_labels.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import 'host_parts.dart';

/// Host mode, Home tab: payout card, the next event with its fill bar, and two numbers.
class HostHomeScreen extends ConsumerWidget {
  const HostHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider)();
    final hour = now.toUtc().add(const Duration(hours: 8)).hour;
    final hello = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return Scaffold(
      key: const Key('host-home'),
      backgroundColor: Calm.bg,
      body: ref
          .watch(hostDashboardProvider)
          .when(
            loading: hostLoading,
            error: (_, _) => hostFailed('your dashboard'),
            data: (d) => Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.paddingOf(context).top + 8,
                    20,
                    100,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hello,
                                style: const TextStyle(color: Calm.mut),
                              ),
                              Text(
                                d.profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: Calm.serif,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Calm.accSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'HOST',
                            style: TextStyle(
                              color: Calm.acc,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PayoutCard(d),
                    _NextEvent(d.next),
                    Row(
                      children: [
                        Expanded(
                          child: _Tile(
                            const Key('tile-guests'),
                            '${d.guests}',
                            'guests booked',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Tile(
                            const Key('tile-rating'),
                            d.profile.ratingAvg == null
                                ? 'New'
                                : '${d.profile.ratingAvg} ★',
                            'average rating',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const NewEventButton(),
              ],
            ),
          ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard(this.d);
  final HostDashboard d;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('payout-card'),
    onTap: () => context.go('/host-mode/payouts'),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Calm.acc,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming payout',
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          Text(
            d.upcomingPayoutSen == 0
                ? 'RM 0'
                : formatMoney(d.upcomingPayoutSen),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: Calm.serif,
              fontSize: 34,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '→ ${d.profile.accountLabel}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    ),
  );
}

class _NextEvent extends ConsumerWidget {
  const _NextEvent(this.e);
  final HostEventRow? e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = this.e;
    if (e == null) {
      return const CardBox(
        child: Text(
          'No upcoming events. Create one with the button below.',
          style: TextStyle(color: Calm.mut),
        ),
      );
    }
    final now = ref.watch(nowProvider)();
    final cap = e.capacity ?? 1;
    return CardBox(
      key: const Key('next-event'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CategoryArt(kind: artKindFor(e.id, e.categories)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEXT EVENT',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Calm.faint,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                      ),
                    ),
                    Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${dayLabel(e.startsAt!, now)} ${timeLabel(e.startsAt!)}',
                      style: const TextStyle(color: Calm.mut, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('fill-bar'),
            height: 6,
            decoration: BoxDecoration(
              color: Calm.chip,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (e.seatsSold / cap).clamp(0, 1).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: Calm.acc,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${e.seatsSold} of $cap ${(e.priceSen ?? 0) == 0 ? 'joined' : 'paid'} · ${cap - e.seatsSold} spots left',
            style: const TextStyle(color: Calm.mut, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: JomButton(
                  label: 'Guest list',
                  primary: false,
                  onPressed: () =>
                      context.push('/host-mode/events/${e.id}/guests'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: JomButton(
                  label: 'Scan',
                  onPressed: () =>
                      context.push('/host-mode/events/${e.id}/scan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.k, this.big, this.small);
  final Key k;
  final String big, small;

  @override
  Widget build(BuildContext context) => Container(
    key: k,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Calm.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Calm.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          big,
          style: const TextStyle(
            fontFamily: Calm.serif,
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(small, style: const TextStyle(color: Calm.mut, fontSize: 13)),
      ],
    ),
  );
}
