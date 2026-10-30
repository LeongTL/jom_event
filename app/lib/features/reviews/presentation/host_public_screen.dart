import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../event/presentation/event_cards.dart';
import '../data/review_repository.dart';
import '../domain/review.dart';

/// What anyone can see about a host: who they are, their numbers, what is coming up and what guests said.
class HostPublicScreen extends ConsumerWidget {
  const HostPublicScreen({super.key, required this.hostId});
  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top + 5;
    return Scaffold(
      key: const Key('host-public-screen'),
      backgroundColor: Calm.bg,
      body: ref.watch(hostPublicProvider(hostId)).when(
            loading: () => Padding(padding: EdgeInsets.fromLTRB(20, top + 60, 20, 0), child: Skeleton.rows(3)),
            error: (_, _) => const _Note('Could not load this host. Check your connection.'),
            data: (h) => h == null ? const _Note('This host page is not available.') : _Page(h, hostId, top),
          ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
        const BookingNav(title: 'Host'),
        Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text(text, style: const TextStyle(color: Calm.mut)))),
      ]);
}

class _Page extends StatelessWidget {
  const _Page(this.h, this.hostId, this.top);
  final HostPublic h;
  final String hostId;
  final double top;

  @override
  Widget build(BuildContext context) {
    final sub = [if (h.area != null) h.area!, 'hosting since ${h.since.year}', if (h.verified) 'Verified host'].join(' · ');
    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      SizedBox(
        key: const Key('host-hero'),
        height: 200,
        child: Stack(fit: StackFit.expand, children: [
          CategoryArt(kind: artKindFor(hostId, h.upcoming.firstOrNull?.categories ?? const [])),
          Positioned(
            left: 20,
            top: top,
            child: GestureDetector(
              key: const Key('host-back'),
              onTap: () => context.canPop() ? context.pop() : context.go('/explore'),
              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), shape: BoxShape.circle), child: const Icon(Icons.chevron_left, size: 24, color: Calm.ink)),
            ),
          ),
        ]),
      ),
      Transform.translate(
        offset: const Offset(0, -42),
        child: Column(children: [
          Container(
            key: const Key('host-avatar'),
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Calm.accSoft, shape: BoxShape.circle, border: Border.all(color: Calm.bg, width: 4)),
            child: Text(h.name.characters.first.toUpperCase(), style: const TextStyle(fontFamily: Calm.serif, fontSize: 32, color: Calm.acc)),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(key: const Key('host-name'), child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Calm.serif, fontSize: 24, fontWeight: FontWeight.w600))),
            if (h.verified) ...[const SizedBox(width: 6), const VerifiedBadge(size: 18)],
          ]),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: Calm.mut, fontSize: 13.5)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Transform.translate(
          offset: const Offset(0, -26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Stat('stat-rating', h.ratingAvg == null ? 'New' : h.ratingAvg!.toStringAsFixed(1), 'rating'),
              const SizedBox(width: 10),
              _Stat('stat-reviews', '${h.ratingCount}', 'reviews'),
              const SizedBox(width: 10),
              _Stat('stat-guests', '${h.guests}', 'guests'),
            ]),
            if (h.upcoming.isNotEmpty) ...[
              const _Heading('Coming up'),
              SingleChildScrollView(
                key: const Key('coming-up'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(children: [for (final e in h.upcoming) Padding(padding: const EdgeInsets.only(right: 12), child: EventCard(event: e))]),
              ),
            ],
            if (h.reviews.isNotEmpty) ...[
              const _Heading('What people said'),
              for (final r in h.reviews) _Said(r),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.id, this.value, this.label);
  final String id, value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          key: Key(id),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Calm.line)),
          child: Column(children: [
            Text(value, style: const TextStyle(fontFamily: Calm.serif, fontSize: 22, fontWeight: FontWeight.w500)),
            Text(label, style: const TextStyle(fontSize: 12, color: Calm.mut)),
          ]),
        ),
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
        child: Text(text, style: const TextStyle(fontFamily: Calm.serif, fontSize: 20, fontWeight: FontWeight.w600)),
      );
}

class _Said extends StatelessWidget {
  const _Said(this.r);
  final HostReview r;

  @override
  Widget build(BuildContext context) => CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [for (var i = 1; i <= 5; i++) Icon(i <= r.stars ? Icons.star : Icons.star_border, size: 16, color: const Color(0xFFD69A2D))]),
          if ((r.body ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.body!, style: const TextStyle(fontFamily: Calm.serif, fontSize: 15, height: 1.45))),
          const SizedBox(height: 8),
          Row(children: [
            Text(r.firstName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Text(' · ✓ Attended', style: TextStyle(fontSize: 13, color: Calm.ok)),
          ]),
        ]),
      );
}
