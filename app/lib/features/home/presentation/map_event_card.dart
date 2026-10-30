import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/launcher.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/models/event_summary.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../event/presentation/event_cards.dart';

/// The sheet at the bottom of the map: the selected event, Directions and View event. [event] is null when nothing
/// matches the filter.
class MapEventCard extends ConsumerWidget {
  const MapEventCard({super.key, required this.event, required this.count});
  final EventSummary? event;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event, now = ref.read(nowProvider)();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Calm.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x261B2430),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Calm.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (e == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No events match this filter.',
                style: TextStyle(color: Calm.mut),
              ),
            )
          else ...[
            GestureDetector(
              key: const Key('map-card-event'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/event/${e.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
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
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Calm.accSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText(e, now),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Calm.acc,
                            ),
                          ),
                        ),
                        Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (e.hostName != null)
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  e.hostName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Calm.mut,
                                  ),
                                ),
                              ),
                              if (e.hostVerified) ...[
                                const SizedBox(width: 4),
                                const VerifiedBadge(),
                              ],
                            ],
                          ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: [
                                  if (e.area != null) e.area!,
                                  if (e.distanceKm != null)
                                    '${e.distanceKm!.toStringAsFixed(1)} km',
                                ].join(' · '),
                              ),
                              if (e.cancelPolicy != null &&
                                  e.cancelPolicy != 'none')
                                const TextSpan(
                                  text: ' · ✓ Free cancel',
                                  style: TextStyle(color: Calm.ok),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Calm.mut,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    priceText(e),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: KeyedSubtree(
                    key: const Key('map-directions'),
                    child: JomButton(
                      label: 'Directions',
                      primary: false,
                      onPressed: () {
                        final dest = e.lat != null && e.lng != null
                            ? '${e.lat},${e.lng}'
                            : (e.area ?? '');
                        if (dest.isNotEmpty)
                          ref.read(launchUrlProvider)(
                            Uri.https('www.google.com', '/maps/dir/', {
                              'api': '1',
                              'destination': dest,
                            }),
                          );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KeyedSubtree(
                    key: const Key('map-view-event'),
                    child: JomButton(
                      label: 'View event',
                      onPressed: () => context.push('/event/${e.id}'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$count ${count == 1 ? 'event' : 'events'} in this area',
              style: const TextStyle(fontSize: 12.5, color: Calm.mut),
            ),
          ],
        ],
      ),
    );
  }
}
