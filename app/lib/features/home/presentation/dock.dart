import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/event_summary.dart';
import '../domain/home_feed.dart';

/// The row of event cards under the map. The card in the middle is lifted and its neighbours step aside; that
/// look is driven by the scroll position alone, so scrolling or selecting a pin never rebuilds the cards.
class Dock extends StatelessWidget {
  const Dock({super.key, required this.events, required this.controller, required this.onPage, required this.onOpen});

  final List<EventSummary> events;
  final PageController controller;
  final ValueChanged<int> onPage;
  final ValueChanged<EventSummary> onOpen;

  double get _page => controller.hasClients && controller.position.haveDimensions ? controller.page! : controller.initialPage.toDouble();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: PageView.builder(
        key: const Key('dock'),
        controller: controller,
        itemCount: events.length,
        onPageChanged: onPage,
        clipBehavior: Clip.none,
        itemBuilder: (context, i) => AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final d = i - _page;
            final near = 1 - d.abs().clamp(0.0, 1.0); // 1 in the middle, 0 a page away
            final scale = .9 + .1 * near;
            return Transform(
              key: Key('card-lift-${events[i].id}'),
              alignment: Alignment.center,
              transform: Matrix4.translationValues(d.sign * 14 * (1 - near), -10 * near, 0)..scaleByDouble(scale, scale, scale, 1),
              child: child,
            );
          },
          child: _Card(
            event: events[i],
            onTap: () => (controller.page ?? controller.initialPage).round() == i
                ? onOpen(events[i])
                : controller.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.event, required this.onTap});
  final EventSummary event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: GestureDetector(
        key: Key('card-${event.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: k.glass, borderRadius: BorderRadius.circular(18), border: Border.all(color: k.glassBorder)),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [event.colorA, event.colorB], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Text(event.glyph, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: k.ink, fontWeight: FontWeight.w800, fontSize: 15)),
                Text.rich(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  TextSpan(style: TextStyle(color: k.sub, fontSize: 12), children: [
                    if (event.isLive) const TextSpan(text: '● ', style: TextStyle(color: Color(0xFFFF6B7A))),
                    TextSpan(text: event.isLive ? 'Happening now' : shortWhen(event.startsAt, DateTime.now())),
                  ]),
                ),
                Text(
                  '${formatMoney(event.priceSen)}${event.distanceKm == null ? '' : ' · ${event.distanceKm!.toStringAsFixed(1)} km'}',
                  style: TextStyle(color: k.ink, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
