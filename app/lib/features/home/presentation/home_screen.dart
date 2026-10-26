import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/location.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/models/event_summary.dart';
import '../../../shared/widgets/category_art.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/domain/ticket.dart';
import '../../booking/presentation/boarding_pass_tile.dart';
import '../../event/domain/event_labels.dart';
import '../../event/presentation/event_cards.dart';
import '../../notifications/presentation/bell_button.dart';
import '../data/home_repository.dart';
import '../domain/home_query.dart';
import 'area_sheet.dart';
import 'map_preview_card.dart';

const _tiles = [('make', 'Make', ArtKind.make), ('move', 'Move', ArtKind.move), ('meet', 'Meet', ArtKind.meet), ('free', 'Free', ArtKind.free)];

/// Explore (Calm): area and bell, the day's title, your tickets, search, four category tiles, This weekend, the map
/// card and Near you.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(homeFilterProvider.notifier).setQuery(text));
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(nowProvider)();
    final sel = ref.watch(areaSelectionProvider);
    final centre = ref.watch(homeCentreProvider);
    final filter = ref.watch(homeFilterProvider);
    final signedIn = ref.watch(sessionProvider).value != null;
    return Scaffold(
      key: const Key('home-screen'),
      backgroundColor: Calm.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 40),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              key: const Key('area-pill'),
              onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Calm.bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => const AreaSheet()),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place_outlined, size: 20),
                const SizedBox(width: 6),
                Text('${sel.area}, KL ▾', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              ]),
            ),
            const BellButton(),
          ]),
          const SizedBox(height: 18),
          Text(eyebrow(now), key: const Key('eyebrow'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.15, color: Calm.faint)),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
            child: Text(homeTitle(now, sel.area), key: const Key('home-title'), style: const TextStyle(fontFamily: Calm.serif, fontSize: 32, fontWeight: FontWeight.w500, height: 1.1, letterSpacing: -.5)),
          ),
          if (signedIn) const _TicketRow(),
          _SearchBar(controller: _search, onChanged: _onSearch),
          _Tiles(selected: filter.category),
          centre.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('Could not work out where to look'))),
            data: (c) => _Feed(area: (lat: c.lat, lng: c.lng, km: sel.km), filter: filter, usingDevice: sel.useDevice),
          ),
        ],
      ),
    );
  }
}

class _TicketRow extends ConsumerWidget {
  const _TicketRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(nowProvider)();
    final tickets = ref.watch(ticketsProvider(TicketScope.upcoming)).value ?? const <Ticket>[];
    if (tickets.isEmpty) return const SizedBox.shrink();
    final shown = ([...tickets]..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt))).take(5).toList();
    return SingleChildScrollView(
      key: const Key('ticket-row'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(children: [
        for (final t in shown) Padding(padding: const EdgeInsets.only(right: 12), child: BoardingPassTile(ticket: t, now: now, onTap: () => context.go('/tickets'))),
      ]),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Calm.line)),
              child: Row(children: [
                const Icon(Icons.search, size: 20, color: Calm.faint),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('home-search'),
                    controller: controller,
                    onChanged: onChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Search events, hosts, places', hintStyle: TextStyle(color: Calm.faint)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            key: const Key('filter-button'),
            onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Calm.bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => const AreaSheet()),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Calm.line)),
              child: const Icon(Icons.tune, size: 20),
            ),
          ),
        ]),
      );
}

class _Tiles extends ConsumerWidget {
  const _Tiles({required this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (key, label, kind) in _tiles)
            GestureDetector(
              key: Key('tile-$key'),
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(homeFilterProvider.notifier).toggleCategory(key),
              child: SizedBox(
                width: 76,
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: selected == key ? Calm.acc : Calm.line, width: 2)),
                    child: CategoryArt(kind: kind),
                  ),
                  const SizedBox(height: 7),
                  Text(label, style: TextStyle(fontSize: 12.5, fontWeight: selected == key ? FontWeight.w600 : FontWeight.w500, color: selected == key ? Calm.acc : Calm.ink)),
                ]),
              ),
            ),
        ]),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.more, this.onMore);
  final String title, more;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(title, style: const TextStyle(fontFamily: Calm.serif, fontSize: 18, fontWeight: FontWeight.w600, height: 1.2)),
          GestureDetector(onTap: onMore, child: Text(more, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Calm.acc))),
        ]),
      );
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.area, required this.filter, required this.usingDevice});
  final HomeArea area;
  final HomeFilter filter;
  final bool usingDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = (lat: area.lat, lng: area.lng, km: area.km, category: filter.category, query: filter.query);
    final weekend = ref.watch(weekendProvider(area));
    final near = ref.watch(nearYouProvider(q));
    String allRoute() => filter.category == null ? '/explore/all' : '/explore/all?category=${filter.category}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((weekend.value ?? const <EventSummary>[]).isNotEmpty) ...[
        _Header('This weekend', 'View all ›', () => context.push('/explore/all')),
        SingleChildScrollView(
          key: const Key('weekend-carousel'),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(bottom: 26),
          child: Row(children: [for (final e in weekend.value!) Padding(padding: const EdgeInsets.only(right: 12), child: EventCard(event: e))]),
        ),
      ],
      _Header('On the map', 'Open map ›', () => context.push('/explore/map')),
      Padding(padding: const EdgeInsets.only(bottom: 26), child: MapPreviewCard(count: near.value?.length ?? 0, km: area.km)),
      _Header('Near you', 'View all ›', () => context.push(allRoute())),
      near.when(
        loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Center(child: CircularProgressIndicator())),
        error: (_, _) => const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Center(child: Text('Could not load events. Check your connection.', style: TextStyle(color: Calm.mut)))),
        data: (list) => list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Center(child: Text(filter.category == null && filter.query.isEmpty ? 'Nothing right now' : 'Nothing matches yet. Try another word or category.', textAlign: TextAlign.center, style: const TextStyle(color: Calm.mut, fontSize: 14))),
              )
            : Column(children: [
                for (final e in list.take(4)) EventRow(event: e),
                GestureDetector(
                  key: const Key('view-all-button'),
                  onTap: () => context.push(allRoute()),
                  child: Container(
                    height: 46,
                    margin: const EdgeInsets.only(top: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Calm.line)),
                    child: Text('View all ${list.length} events', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Calm.acc)),
                  ),
                ),
              ]),
      ),
      if (!usingDevice) const SizedBox.shrink(),
    ]);
  }
}
