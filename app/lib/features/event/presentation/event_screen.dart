import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/launcher.dart';
import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../auth/domain/auth_gate.dart';
import '../data/event_repository.dart';
import '../domain/event_detail.dart';
import '../domain/event_labels.dart';
import 'poster_card.dart';
import '../../../shared/widgets/skeleton.dart';

/// One event. Paid events (bookable) get the paid page with the host row and the refund policy; the rest get the
/// free page with directions and the source of the listing. Both are read-only for visitors: only the heart,
/// Join and Message ask for an account.
class EventScreen extends ConsumerWidget {
  const EventScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    return Scaffold(
      key: const Key('event-screen'),
      backgroundColor: k.sheet,
      body: ref.watch(eventDetailProvider(id)).when(
            loading: () => SafeArea(child: Skeleton.page()),
            error: (_, _) => _Notice(text: 'Could not load this event. Check your connection.'),
            data: (d) => d == null ? _Notice(text: "This event isn't available") : _Page(d),
          ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Stack(children: [
        Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center))),
        Positioned(left: 20, top: MediaQuery.paddingOf(context).top + 5, child: const _Round(glyph: '‹', key: Key('event-back'))),
      ]);
}

/// The 40-point round button (prototype .rb). On the hero it is dark glass; elsewhere the card colour.
class _Round extends StatelessWidget {
  const _Round({super.key, required this.glyph});
  final String glyph;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.canPop() ? context.pop() : context.go('/explore'),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0x47000000), shape: BoxShape.circle),
          child: Text(glyph, style: const TextStyle(color: Colors.white, fontSize: 20, height: 1)),
        ),
      );
}

class _Page extends ConsumerWidget {
  const _Page(this.d);
  final EventDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final e = d.summary;
    final paid = d.isBookable;
    final host = d.hostName ?? 'the host';
    final top = MediaQuery.paddingOf(context).top;
    final now = ref.read(nowProvider)();
    final live = !d.isEnded && !e.startsAt.isAfter(now);
    final kind = e.categories.contains('make') ? 'Workshop' : e.categories.contains('move') ? 'Fitness' : 'Social';
    final km = e.distanceKm == null ? (e.area ?? '') : '${e.distanceKm!.toStringAsFixed(1)} km away';

    Widget fact(String glyph, String big, String small) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Text(glyph, style: const TextStyle(fontSize: 20, height: 1.2)),
              const SizedBox(height: 2),
              Text(big, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(small, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: k.sheetInk.withValues(alpha: .6))),
            ]),
          ),
        );
    final when = live ? 'Now' : whenLabel(e.startsAt, now);
    final whenSmall = live ? 'until ${whenLabel(e.endsAt, now).split(' ').skip(1).join(' ')}' : durationText(e.endsAt.difference(e.startsAt));

    Widget soft(Widget child, {Key? key, VoidCallback? onTap}) => GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(16)),
            child: child,
          ),
        );

    final body = <Widget>[
      Text(
        (paid ? '$kind · ${e.spotsLeft} spots left' : 'Free · Join to save your spot').toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: k.sheetInk.withValues(alpha: .6)),
      ),
      const SizedBox(height: 6),
      Text(e.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -.6)),
      if (paid) ...[
        const SizedBox(height: 12),
        GestureDetector(
          key: const Key('host-row'),
          onTap: () => context.push('/host/${d.hostId}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFF9A62), Color(0xFFD4467C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Text(host.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(d.ratingAvg == null ? 'New host' : '★ ${d.ratingAvg!.toStringAsFixed(1)} · ${d.ratingCount} reviews',
                      style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
                ]),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                key: const Key('message'),
                onTap: () => _message(context, ref),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(19)),
                  child: const Text('💬 Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              const Text('›'),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 18),
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        fact('🗓', when, whenSmall),
        const SizedBox(width: 8),
        fact('📍', e.area ?? '—', km),
        const SizedBox(width: 8),
        paid ? fact('🎟', formatMoney(e.priceSen), 'per person') : fact('🆓', 'Free', 'entry'),
      ])),
      const SizedBox(height: 18),
      if (!paid)
        Opacity(
          opacity: .8,
          child: Text("A free community event, hosted by $host. Join to get your ticket and the host's updates."),
        ),
      if ((d.description ?? '').isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4), child: Opacity(opacity: .8, child: Text(d.description!))),
      if (!paid) ...[
        const SizedBox(height: 12),
        _Directions(d: d, km: km),
        if (d.sourceUrl != null)
          soft(
            key: const Key('source-card'),
            onTap: () => ref.read(launchUrlProvider)(Uri.parse(d.sourceUrl!)),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Source: $host${Uri.tryParse(d.sourceUrl!)?.host.contains('instagram') == true ? ' on Instagram' : ''} · '),
              const TextSpan(text: 'View original post ↗', style: TextStyle(decoration: TextDecoration.underline)),
            ]), style: const TextStyle(fontSize: 13)),
          ),
      ] else
        soft(Text('${d.cancelPolicy == 'none' ? 'ⓘ' : '✓'} ${cancelPolicyText(d.cancelPolicy)}', style: const TextStyle(fontSize: 13))),
    ];

    return Stack(children: [
      Positioned.fill(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            SizedBox(
              height: 300,
              child: Stack(children: [
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [e.colorA, e.colorB], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
                const Positioned.fill(
                  child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(-.5, -.6), radius: .9, colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)], stops: [0, .45]))),
                ),
                Align(
                  alignment: const Alignment(0, .04),
                  child: Transform.rotate(angle: -8 * 3.14159 / 180, child: Text(e.glyph, style: const TextStyle(fontSize: 150, height: 1))),
                ),
                Positioned(left: 20, top: top + 5, child: const _Round(key: Key('event-back'), glyph: '‹')),
                Positioned(right: 20, top: top + 5, child: HeartButton(key: const Key('hero-heart'), eventId: e.id, style: HeartStyle.hero)),
              ]),
            ),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                decoration: BoxDecoration(color: k.sheet, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: k.sheetInk),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
                ),
              ),
            ),
          ],
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [k.sheet.withValues(alpha: 0), k.sheet], stops: const [0, .38])),
          child: d.isEnded
              ? const _EndedBar()
              : Row(children: [
                  HeartButton(key: const Key('bar-heart'), eventId: e.id, style: HeartStyle.bar),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('join'),
                      child: JomButton(label: 'Join · ${formatMoney(e.priceSen)}', onPressed: () => _join(context, ref)),
                    ),
                  ),
                ]),
        ),
      ),
    ]);
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    if (!await requireAuth(ref, context, AuthReason.join) || !context.mounted) return;
    context.push('/event/${d.summary.id}/checkout');
  }

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    if (!await requireAuth(ref, context, AuthReason.chat) || !context.mounted) return;
    final thread = await ref.read(eventRepositoryProvider).openThread(d.hostId, d.summary.id);
    if (context.mounted) context.push('/chats/$thread');
  }
}

class _EndedBar extends StatelessWidget {
  const _EndedBar();
  @override
  Widget build(BuildContext context) => const JomButton(label: 'This event has ended', onPressed: null, primary: false);
}

class _Directions extends ConsumerWidget {
  const _Directions({required this.d, required this.km});
  final EventDetail d;
  final String km;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final destination = d.lat != null && d.lng != null ? '${d.lat},${d.lng}' : [d.venue, d.summary.area].whereType<String>().join(' ');
    if (destination.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      key: const Key('directions'),
      onTap: () => ref.read(launchUrlProvider)(Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination})),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          const Text('📍'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Get directions', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('${d.summary.area ?? ''} · $km', style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
            ]),
          ),
          const Text('›'),
        ]),
      ),
    );
  }
}
