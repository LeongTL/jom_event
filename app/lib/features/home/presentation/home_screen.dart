import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location.dart';
import '../../../core/theme/grain.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/data/auth_repository.dart';
import '../data/home_repository.dart';
import '../domain/home_feed.dart';
import 'area_sheet.dart';
import 'dock.dart';
import 'odometer.dart';
import 'pin_map.dart';
import 'sky.dart';

/// Explore: the area pill and bell, the big number, the pin map, the dock of cards and the Now / Night /
/// Weekend / All tabs. The tab picks the sky (jomThemeProvider); All opens View all.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(jomThemeProvider);
    final k = context.jom;
    final sel = ref.watch(areaSelectionProvider);
    final centre = ref.watch(homeCentreProvider);
    return DefaultTextStyle.merge(
      style: TextStyle(color: k.ink),
      child: Stack(
        key: const Key('home-screen'),
        children: [
          Positioned.fill(child: HomeSky(tab: tab)),
          Positioned.fill(
            child: GrainBackground(
              child: SafeArea(
                bottom: false,
                // 96 at the bottom: the dial ends just above the tab bar (prototype .dial bottom:96px)
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  child: Column(
                    children: [
                      const _Header(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: centre.when(
                          loading: () => const _Wait(),
                          error: (e, _) => const _Message(
                            'Could not work out where to look',
                          ),
                          data: (c) => ref
                              .watch(
                                homeFeedProvider((
                                  tab: tab,
                                  lat: c.lat,
                                  lng: c.lng,
                                  km: sel.km,
                                )),
                              )
                              .when(
                                loading: () => const _Wait(),
                                error: (e, _) => const _Message(
                                  'Could not load events. Check your connection.',
                                ),
                                // too tall for a small phone: shrink the whole block, never overflow
                                data: (feed) => LayoutBuilder(
                                  builder: (context, box) => FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topCenter,
                                    // at least 520 tall: the spare height goes to the map, and a shorter
                                    // screen scales the block down instead of overflowing
                                    child: SizedBox(
                                      width: box.maxWidth,
                                      height: math.max(box.maxHeight, 520),
                                      child: _FeedBody(
                                        key: ValueKey((tab, c, sel.km)),
                                        feed: feed,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                      _Dial(tab: tab),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final user = ref.watch(sessionProvider).value?.user;
    final name =
        ((user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'])
                as String?)
            ?.trim() ??
        '';
    return Row(
      children: [
        GestureDetector(
          key: const Key('area-pill'),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AreaSheet(),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: k.glass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: k.glassBorder),
            ),
            child: Text(
              '📍 ${ref.watch(areaSelectionProvider).area}  ▾',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          key: const Key('bell'),
          onTap: () => context.push('/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: k.glass,
                  shape: BoxShape.circle,
                  border: Border.all(color: k.glassBorder),
                ),
                child: const Icon(Icons.notifications_none, size: 22),
              ),
              if (unread > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    key: const Key('bell-badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D6A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (user != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            key: const Key('avatar'),
            onTap: () => context.go('/profile'),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: k.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                name.isEmpty ? '•' : name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: k.accentInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One tab's content. Keyed by the query, so a new tab or area starts with a fresh dock and selection.
class _FeedBody extends ConsumerStatefulWidget {
  const _FeedBody({super.key, required this.feed});
  final HomeFeed feed;

  @override
  ConsumerState<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends ConsumerState<_FeedBody> {
  final _selected = ValueNotifier<int>(0);
  final _controller = PageController(viewportFraction: 208 / 390);
  late final _events = [...widget.feed.top9]
    ..sort((a, b) => (a.distanceKm ?? 99).compareTo(b.distanceKm ?? 99));

  @override
  void dispose() {
    _selected.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final stats = widget.feed.stats;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heroEyebrow(widget.feed.tab, DateTime.now()),
                key: const Key('eyebrow'),
                style: TextStyle(
                  color: k.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              // the number is part of the sentence, so it wraps with it ("22 things are / happening near you")
              Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Odometer(
                        key: const Key('odometer'),
                        value: stats.total,
                      ),
                    ),
                    TextSpan(
                      text: ' ${heroTail(widget.feed.tab, stats.total)}',
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                heroSub(stats, shown: _events.length),
                style: TextStyle(color: k.sub, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: PinMap(
            key: const Key('pin-map'),
            events: _events,
            selected: _selected,
            onTap: (i) => _controller.animateToPage(
              i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
          ),
        ),
        if (_events.isNotEmpty)
          Dock(
            events: _events,
            controller: _controller,
            onPage: (i) => _selected.value = i,
            onOpen: (e) => context.push('/event/${e.id}'),
          ),
      ],
    );
  }
}

class _Dial extends ConsumerWidget {
  const _Dial({required this.tab});
  final JomTheme tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    Widget label(String text, bool on, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? k.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: on ? k.accentInk : k.ink,
            ),
          ),
        ),
      ),
    );
    return Container(
      key: const Key('dial'),
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: k.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: k.glassBorder),
      ),
      child: Row(
        children: [
          label(
            'Now',
            tab == JomTheme.now,
            () => ref.read(jomThemeProvider.notifier).select(JomTheme.now),
          ),
          label(
            'Night',
            tab == JomTheme.night,
            () => ref.read(jomThemeProvider.notifier).select(JomTheme.night),
          ),
          label(
            'Weekend',
            tab == JomTheme.weekend,
            () => ref.read(jomThemeProvider.notifier).select(JomTheme.weekend),
          ),
          label('All', false, () => context.push('/all')),
        ],
      ),
    );
  }
}

class _Wait extends StatelessWidget {
  const _Wait();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, textAlign: TextAlign.center));
}
