import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../event/domain/event_labels.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import 'host_parts.dart';

/// Host mode, Payouts tab: upcoming and paid out, then the fee lines of each completed event.
class PayoutsScreen extends ConsumerWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider)();
    final me = ref.watch(hostMeProvider).value;
    return Scaffold(
      key: const Key('payouts'),
      backgroundColor: Calm.bg,
      body: ref
          .watch(hostPayoutsProvider)
          .when(
            loading: hostLoading,
            error: (_, _) => hostFailed('your payouts'),
            data: (p) => ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 8,
                20,
                100,
              ),
              children: [
                const Text(
                  'Payouts',
                  style: TextStyle(
                    fontFamily: Calm.serif,
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        const Key('payouts-upcoming'),
                        rm(p.upcomingSen),
                        'Upcoming',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        const Key('payouts-paid'),
                        rm(p.paidSen),
                        'Paid out',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final r in p.rows) _EventCard(r, now),
                const Padding(
                  padding: EdgeInsets.fromLTRB(2, 0, 2, 14),
                  child: Text(
                    'Illustrative numbers. Real fees depend on the gateway agreement.',
                    style: TextStyle(color: Calm.mut, fontSize: 13),
                  ),
                ),
                if (me != null)
                  CardBox(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payout account',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${me.accountLabel}${me.verifiedAt == null ? '' : ' · verified'}',
                                style: const TextStyle(color: Calm.mut),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: JomButton(
                            label: 'Edit',
                            primary: false,
                            onPressed: () =>
                                context.push('/host-mode/payout-account'),
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
}

class _EventCard extends StatelessWidget {
  const _EventCard(this.r, this.now);
  final PayoutRow r;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final e = r.earnings;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${r.startsAt == null ? '' : '${dayLabel(r.startsAt!, now)} · '}${r.paid ? 'paid' : 'pays'} ${dayLabel(r.dueAt, now)}',
              style: const TextStyle(color: Calm.mut, fontSize: 13),
            ),
          ),
          MoneyLine('Gross', rm(e.gross)),
          MoneyLine('Gateway fees', '−${rm(e.gateway)}'),
          MoneyLine('Platform fee (10%)', '−${rm(e.platform)}'),
          MoneyLine('You receive', rm(e.receives), total: true),
        ],
      ),
    );
  }
}
