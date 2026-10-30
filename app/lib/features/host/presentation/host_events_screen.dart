import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../event/domain/event_labels.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import 'host_parts.dart';

const _tabs = [
  ('draft', 'Draft'),
  ('published', 'Published'),
  ('ended', 'Ended'),
];

/// Host mode, Events tab: Draft / Published / Ended.
class HostEventsScreen extends ConsumerStatefulWidget {
  const HostEventsScreen({super.key});

  @override
  ConsumerState<HostEventsScreen> createState() => _HostEventsScreenState();
}

class _HostEventsScreenState extends ConsumerState<HostEventsScreen> {
  var _status = 'published';

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('host-events'),
      backgroundColor: Calm.bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 8,
              20,
              100,
            ),
            children: [
              const Text(
                'Events',
                style: TextStyle(
                  fontFamily: Calm.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Calm.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    for (final (status, label) in _tabs)
                      Expanded(
                        child: GestureDetector(
                          key: Key('seg-$status'),
                          onTap: () => setState(() => _status = status),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _status == status ? Calm.surface : null,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: _status == status ? Calm.ink : Calm.mut,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...ref
                  .watch(hostEventsProvider(_status))
                  .when(
                    loading: () => [
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: Calm.acc),
                        ),
                      ),
                    ],
                    error: (_, _) => [
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'Could not load your events. Check your connection.',
                            style: TextStyle(color: Calm.mut),
                          ),
                        ),
                      ),
                    ],
                    data: (rows) => rows.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Center(
                                child: Text(
                                  'Nothing here yet.',
                                  style: TextStyle(color: Calm.mut),
                                ),
                              ),
                            ),
                          ]
                        : [for (final e in rows) _Row(e, now)],
                  ),
            ],
          ),
          const NewEventButton(),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.e, this.now);
  final HostEventRow e;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final when = e.startsAt == null
        ? 'No date yet'
        : '${dayLabel(e.startsAt!, now)} · ${timeLabel(e.startsAt!)}';
    final (pill, tone) = switch (e.status) {
      'published' => (
        '${e.seatsSold} / ${e.capacity} ${(e.priceSen ?? 0) == 0 ? 'joined' : 'paid'}',
        e.seatsSold >= (e.capacity ?? 1),
      ),
      'draft' => ('Draft', false),
      _ => ('Ended', false),
    };
    return CardBox(
      key: Key('host-event-${e.id}'),
      gap: 8,
      onTap: () => context.push(
        e.status == 'draft'
            ? '/host-mode/events/${e.id}/edit'
            : '/host-mode/events/${e.id}',
      ),
      child: Row(
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
                Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  when,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Calm.mut, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tone ? Calm.okSoft : Calm.chip,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              pill,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tone ? Calm.ok : Calm.mut,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
