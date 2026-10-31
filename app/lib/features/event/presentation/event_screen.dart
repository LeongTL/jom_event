import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/launcher.dart';
import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/people_stack.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../auth/domain/auth_gate.dart';
import '../data/event_repository.dart';
import '../domain/event_detail.dart';
import '../domain/event_labels.dart';
import 'event_cards.dart';

/// One event, free or paid, in one layout (the Calm prototype's detail screen). Read-only for visitors: only the
/// heart, the button and Message ask for an account.
class EventScreen extends ConsumerWidget {
  const EventScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    key: const Key('event-screen'),
    backgroundColor: Calm.bg,
    body: ref
        .watch(eventDetailProvider(id))
        .when(
          loading: () => SafeArea(child: Skeleton.page()),
          error: (_, _) => _Notice(
            text: 'Could not load this event. Check your connection.',
          ),
          data: (d) => d == null
              ? _Notice(text: "This event isn't available")
              : _Page(d),
        ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
      Positioned(
        left: 20,
        top: MediaQuery.paddingOf(context).top + 5,
        child: const _Back(),
      ),
    ],
  );
}

/// The round glass back button over the hero.
class _Back extends StatelessWidget {
  const _Back();
  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('event-back'),
    onTap: () => context.canPop() ? context.pop() : context.go('/explore'),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.chevron_left, size: 24, color: Calm.ink),
    ),
  );
}

class _Page extends ConsumerWidget {
  const _Page(this.d);
  final EventDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = d.summary;
    final free = e.isFree;
    final host = d.hostName ?? 'the host';
    final now = ref.read(nowProvider)();
    final live = !d.isEnded && !e.startsAt.isAfter(now);
    final category = primaryCategory(e.categories);
    final when = live ? 'Now' : whenLabel(e.startsAt, now);
    final where = [
      e.area ?? '—',
      if (e.distanceKm != null) '${e.distanceKm!.toStringAsFixed(1)} km',
    ].join(' · ');
    final refundable = !free && d.cancelPolicy != 'none';
    final rating = d.ratingAvg == null
        ? 'New host'
        : '${d.ratingAvg!.toStringAsFixed(1)} · ${d.ratingCount} reviews';
    final hosted =
        '${d.hostEventCount} ${d.hostEventCount == 1 ? 'event' : 'events'} hosted';

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              SizedBox(
                key: const Key('event-hero'),
                height: 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventArt(
                      posterUrl: e.posterUrl,
                      kind: artKindFor(e.id, e.categories),
                    ),
                    Positioned(
                      left: 20,
                      top: MediaQuery.paddingOf(context).top + 5,
                      child: const _Back(),
                    ),
                    Positioned(
                      right: 20,
                      top: MediaQuery.paddingOf(context).top + 5,
                      child: KeyedSubtree(
                        key: const Key('hero-heart'),
                        child: HeartButton(eventId: e.id),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  decoration: const BoxDecoration(
                    color: Calm.bg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        live
                            ? 'Happening now'
                            : '${category[0].toUpperCase()}${category.substring(1)} · $when',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Calm.acc,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontFamily: Calm.serif,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Hosted by $host',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Calm.mut,
                              ),
                            ),
                          ),
                          if (e.hostVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(),
                            const SizedBox(width: 4),
                            const Text(
                              'Verified host',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Calm.acc,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _Fact(label: 'When', value: when),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Fact(
                                key: const Key('directions'),
                                label: 'Where',
                                value: where,
                                onTap: () => _directions(ref),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      CardBox(
                        key: const Key('going-card'),
                        child: Row(
                          children: [
                            PeopleStack(count: e.going, size: 30),
                            if (e.going > 0) const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.going} going',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    d.isBookable
                                        ? '${e.spotsLeft} ${e.spotsLeft == 1 ? 'spot' : 'spots'} left'
                                        : 'Open to everyone',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Calm.mut,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Policy(
                        key: const Key('policy-card'),
                        good: refundable,
                        title: policyTitle(d.cancelPolicy, free: free),
                        sub: free
                            ? 'You can cancel any time.'
                            : refundable
                            ? 'Refunds take 3 to 7 working days.'
                            : 'Your spot is final once you book.',
                      ),
                      if ((d.description ?? '').isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Calm.acc, width: 3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.description!,
                                style: const TextStyle(
                                  fontFamily: Calm.serif,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '— $host, your host',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Calm.mut,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (d.sourceUrl != null)
                        CardBox(
                          key: const Key('source-card'),
                          onTap: () => ref.read(launchUrlProvider)(
                            Uri.parse(d.sourceUrl!),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      'Source: $host${Uri.tryParse(d.sourceUrl!)?.host.contains('instagram') == true ? ' on Instagram' : ''} · ',
                                ),
                                const TextSpan(
                                  text: 'View original post ↗',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      CardBox(
                        key: const Key('host-row'),
                        onTap: () => context.push('/host/${d.hostId}'),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Calm.accSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                host.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: Calm.acc,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          host,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (e.hostVerified) ...[
                                        const SizedBox(width: 4),
                                        const VerifiedBadge(),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '$rating · $hosted',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Calm.mut,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              key: const Key('message'),
                              onTap: () => _message(context, ref),
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Calm.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Calm.line),
                                ),
                                child: const Text(
                                  'Message',
                                  style: TextStyle(
                                    fontSize: 13.5,
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
                ),
              ),
            ],
          ),
        ),
        CtaBar(
          children: [
            if (d.isEnded)
              const Expanded(
                child: JomButton(
                  label: 'This event has ended',
                  onPressed: null,
                  primary: false,
                ),
              )
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    free ? 'Entry' : 'Per person',
                    style: const TextStyle(fontSize: 12.5, color: Calm.mut),
                  ),
                  Text(
                    formatMoney(e.priceSen),
                    style: const TextStyle(
                      fontFamily: Calm.serif,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: KeyedSubtree(
                  key: const Key('join'),
                  child: JomButton(
                    label: free ? 'Join for free' : 'Book a spot',
                    onPressed: () => _join(context, ref),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _directions(WidgetRef ref) {
    final destination = d.lat != null && d.lng != null
        ? '${d.lat},${d.lng}'
        : [d.venue, d.summary.area].whereType<String>().join(' ');
    if (destination.isEmpty) return;
    ref.read(launchUrlProvider)(
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': destination,
      }),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    if (!await requireAuth(ref, context, AuthReason.join) || !context.mounted) {
      return;
    }
    context.push('/event/${d.summary.id}/checkout');
  }

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    if (!await requireAuth(ref, context, AuthReason.chat) || !context.mounted) {
      return;
    }
    final thread = await ref
        .read(eventRepositoryProvider)
        .openThread(d.hostId, d.summary.id);
    if (context.mounted) context.push('/chats/$thread');
  }
}

/// A "When" or "Where" tile (prototype .fc).
class _Fact extends StatelessWidget {
  const _Fact({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });
  final String label, value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Calm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Calm.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Calm.mut)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// The refund promise (prototype .policy): green when the guest can get money back, neutral otherwise.
class _Policy extends StatelessWidget {
  const _Policy({
    super.key,
    required this.good,
    required this.title,
    required this.sub,
  });
  final bool good;
  final String title, sub;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: good ? Calm.okSoft : Calm.soft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 20, color: good ? Calm.ok : Calm.mut),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: good ? Calm.ok : Calm.mut,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 13,
                  color: good ? const Color(0xFF2F5C45) : Calm.mut,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
