import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/models/event_summary.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/people_stack.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../domain/event_labels.dart';
import '../domain/saved_controller.dart';

String priceText(EventSummary e) => e.isFree ? 'Free' : formatMoney(e.priceSen);

/// "Happening now" (green dot) or when it starts: "in 22 min" today, else "Sat 24 Oct".
String badgeText(EventSummary e, DateTime now) {
  if (e.isLive) return 'Happening now';
  return dayLabel(e.startsAt, now) == 'Today'
      ? relativeStart(e.startsAt, e.endsAt, now)
      : dayLabel(e.startsAt, now);
}

class _Badge extends StatelessWidget {
  const _Badge(this.e, this.now);
  final EventSummary e;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('event-badge'),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e.isLive) ...[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Calm.ok,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          badgeText(e, now),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: e.isLive ? Calm.ok : Calm.ink,
          ),
        ),
      ],
    ),
  );
}

/// The round heart on a card; one tap saves or un-saves (and asks to sign in first).
class HeartButton extends ConsumerWidget {
  const HeartButton({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(savedProvider).value?.contains(eventId) ?? false;
    return GestureDetector(
      key: Key('heart-${on ? 'on' : 'off'}:$eventId'),
      onTap: () => toggleHeart(ref, context, eventId),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          shape: BoxShape.circle,
        ),
        child: Icon(
          on ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: on ? Calm.badge : Calm.ink,
        ),
      ),
    );
  }
}

class _Host extends StatelessWidget {
  const _Host(this.e);
  final EventSummary e;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          e.hostName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Calm.mut),
        ),
      ),
      if (e.hostVerified) ...[const SizedBox(width: 4), const VerifiedBadge()],
    ],
  );
}

/// A card in a horizontal carousel (262 wide): the illustration with its badge and heart, then title, host and the
/// price line.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event, now = ref.read(nowProvider)();
    return GestureDetector(
      key: Key('event-card-${e.id}'),
      onTap: () => context.push('/event/${e.id}'),
      child: Container(
        width: 262,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Calm.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Calm.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 136,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventArt(
                    posterUrl: e.posterUrl,
                    kind: artKindFor(e.id, e.categories),
                  ),
                  Positioned(left: 12, top: 12, child: _Badge(e, now)),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: HeartButton(eventId: e.id),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: Calm.serif,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _Host(e),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 11),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Calm.line)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PeopleStack(count: e.going),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: priceText(e),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Calm.ink,
                                  ),
                                ),
                                if (e.spotsLeft > 0 && e.spotsLeft <= 20)
                                  TextSpan(text: ' · ${e.spotsLeft} left')
                                else if (e.going > 0)
                                  TextSpan(text: ' · ${e.going} going'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Calm.mut,
                            ),
                          ),
                        ),
                      ],
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

/// A row in a list (Near you, View all, Saved): a small illustration, title, host, when and where, and the price.
/// [ended] dims it and says "Ended" instead of when; [heart] adds the save heart (Saved, where it un-saves).
class EventRow extends ConsumerWidget {
  const EventRow({
    super.key,
    required this.event,
    this.ended = false,
    this.heart = false,
  });
  final EventSummary event;
  final bool ended, heart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event, now = ref.read(nowProvider)();
    final when = ended
        ? 'Ended'
        : [
            whenLabel(e.startsAt, now),
            if (e.distanceKm != null) '${e.distanceKm!.toStringAsFixed(1)} km',
          ].join(' · ');
    return GestureDetector(
      key: Key('event-row-${e.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/event/${e.id}'),
      child: Opacity(
        opacity: ended ? .55 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
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
                child: SizedBox(
                  height: 72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          height: 1.25,
                        ),
                      ),
                      _Host(e),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              when,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Calm.mut,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            priceText(e),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Calm.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (heart) ...[
                const SizedBox(width: 8),
                HeartButton(eventId: e.id),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
