import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/theme/tokens.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/home/domain/home_feed.dart';
import 'package:jom/features/home/presentation/home_screen.dart';
import 'package:jom/features/home/presentation/odometer.dart';
import 'package:jom/shared/models/event_summary.dart';

import '../../helpers/fake_auth.dart';

EventSummary ev(int i, {bool live = false}) => EventSummary.fromJson({
      'event_id': 'e$i', 'title': 'Event $i', 'glyph': '🎉', 'color_a': '#11998e', 'color_b': '#38ef7d',
      'starts_at': '2030-01-10T12:00:00+00:00', 'ends_at': '2030-01-10T14:00:00+00:00',
      'price_sen': i.isEven ? 0 : 2500, 'area': 'Bangsar', 'distance_km': 1.0 + i, 'is_live': live, 'spots_left': 5, 'score': 3.0 - i,
    });

final nine = [for (var i = 0; i < 9; i++) ev(i, live: i == 0)];
const stats9 = HeroStats(total: 9, live: 1, free: 5, closestKm: 1.0);

HomeFeed feedFor(HomeQuery q, {List<EventSummary>? events, HeroStats? stats}) =>
    HomeFeed(tab: q.tab, top9: events ?? nine, stats: stats ?? stats9);

/// HomeScreen on its own: '/explore' is Home, '/event/:id' and '/all' just say where they are.
Future<void> pumpHome(
  WidgetTester t, {
  List<EventSummary>? events,
  HeroStats? stats,
  List<HomeQuery>? queries,
  LatLng? device,
  int unread = 0,
  String? name = 'Mei',
  List<Override> extra = const [],
}) async {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final router = GoRouter(initialLocation: '/explore', routes: [
    GoRoute(path: '/explore', builder: (c, s) => const Scaffold(body: HomeScreen())),
    GoRoute(path: '/event/:id', builder: (c, s) => Text('EVENT ${s.pathParameters['id']}')),
    GoRoute(path: '/all', builder: (c, s) => const Text('VIEW ALL')),
    GoRoute(path: '/notifications', builder: (c, s) => const Text('NOTIFICATIONS')),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [
      homeFeedProvider.overrideWith((ref, q) async {
        queries?.add(q);
        return feedFor(q, events: events, stats: stats);
      }),
      deviceLocationProvider.overrideWithValue(() async => device),
      unreadCountProvider.overrideWith((ref) async => unread),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(initial: name == null ? null : fakeSession(name: name))),
      ...extra,
    ],
    child: Consumer(builder: (context, ref, _) => MaterialApp.router(theme: jomThemeData(ref.watch(jomThemeProvider)), routerConfig: router)),
  ));
  await t.pumpAndSettle();
}

// The headline is one line of rich text: the odometer tiles, then these words.
Finder hero(String words) => find.textContaining(words, findRichText: true);
Finder pin(int i) => find.byKey(Key('pin-e$i'));
Finder card(int i) => find.byKey(Key('card-e$i'));
// A side card is mostly off-screen, so tap its visible left edge rather than its centre.
Future<void> tapSide(WidgetTester t, int i) => t.tapAt(t.getTopLeft(card(i)) + const Offset(20, 20));
Transform lift(WidgetTester t, int i) => t.widget<Transform>(find.byKey(Key('card-lift-e$i')));
double scaleOf(WidgetTester t, int i) => lift(t, i).transform.getMaxScaleOnAxis();
// the feed is sorted by distance, so event i is the i-th card

void main() {
  testWidgets('every_pin_has_a_dock_card_and_vice_versa', (t) async {
    await pumpHome(t);
    for (var i = 0; i < 9; i++) {
      expect(pin(i), findsOneWidget, reason: 'pin $i');
    }
    expect(t.widget<PageView>(find.byKey(const Key('dock'))).childrenDelegate.estimatedChildCount, 9);
    for (var i = 0; i < 9; i++) {
      await t.tap(pin(i)); // pin i brings its own card to the middle
      await t.pumpAndSettle();
      expect(card(i), findsOneWidget, reason: 'card $i');
      expect(scaleOf(t, i), closeTo(1.06, .001), reason: 'card $i is centred');
    }
  });

  testWidgets('tapping_a_pin_scrolls_dock_without_rebuilding_cards', (t) async {
    await pumpHome(t);
    final before = t.element(card(1));
    await t.tap(pin(1));
    await t.pumpAndSettle();
    expect(identical(t.element(card(1)), before), isTrue, reason: 'the same card element, not a rebuilt one');
    expect(scaleOf(t, 1), closeTo(1.06, .001));
    expect(scaleOf(t, 0), lessThan(1.0));
  });

  testWidgets('scrolling_dock_selects_pin', (t) async {
    await pumpHome(t);
    expect(find.byKey(const Key('pin-sel-e0')), findsOneWidget);
    await t.drag(find.byKey(const Key('dock')), const Offset(-300, 0));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pin-sel-e1')), findsOneWidget);
    expect(find.byKey(const Key('pin-sel-e0')), findsNothing);
  });

  testWidgets('centred_card_is_lifted_and_neighbours_step_aside', (t) async {
    await pumpHome(t);
    expect(scaleOf(t, 0), closeTo(1.06, .001));
    expect(scaleOf(t, 1), closeTo(.96, .001));
    expect(lift(t, 0).transform.getTranslation().y, closeTo(-12, .001), reason: 'the middle card is lifted 12');
    expect(lift(t, 1).transform.getTranslation().x, closeTo(10, .001), reason: 'the card on the right steps 10 further right');
    await t.tap(pin(2));
    await t.pumpAndSettle();
    expect(lift(t, 1).transform.getTranslation().x, lessThan(0), reason: 'now it is on the left, so it steps left');
  });

  testWidgets('tapping_centred_card_opens_event', (t) async {
    await pumpHome(t);
    await t.tap(card(0));
    await t.pumpAndSettle();
    expect(find.text('EVENT e0'), findsOneWidget);
  });

  testWidgets('tapping_side_card_centres_it', (t) async {
    await pumpHome(t);
    await tapSide(t, 1);
    await t.pumpAndSettle();
    expect(find.textContaining('EVENT'), findsNothing, reason: 'a side card only moves to the middle, it does not open');
    expect(scaleOf(t, 1), closeTo(1.06, .001));
    expect(find.byKey(const Key('pin-sel-e1')), findsOneWidget);
  });

  testWidgets('hero_wording_per_tab', (t) async {
    await pumpHome(t);
    expect(t.widget<Odometer>(find.byKey(const Key('odometer'))).value, 9);
    expect(hero('things are happening near you'), findsOneWidget);
    await t.tap(find.text('Night'));
    await t.pumpAndSettle();
    expect(hero('ways to spend your night'), findsOneWidget);
    await t.tap(find.text('Weekend'));
    await t.pumpAndSettle();
    expect(hero('things to do this weekend'), findsOneWidget);
    await t.tap(find.text('Now'));
    await t.pumpAndSettle();
    expect(hero('things are happening near you'), findsOneWidget);
  });

  testWidgets('hero says "thing" for exactly one event', (t) async {
    await pumpHome(t, events: [nine.first], stats: const HeroStats(total: 1, live: 1, free: 1, closestKm: 1.0));
    expect(hero('thing is happening near you'), findsOneWidget);
    expect(find.textContaining('1 happening now'), findsOneWidget);
  });

  testWidgets('empty_feed_shows_Nothing_right_now_and_no_dock', (t) async {
    await pumpHome(t, events: const [], stats: const HeroStats(total: 0, live: 0, free: 0, closestKm: null));
    expect(find.text('Nothing right now'), findsOneWidget);
    expect(find.byKey(const Key('dock')), findsNothing);
    expect(find.byKey(const Key('pin-map')), findsOneWidget, reason: 'the screen still has its map and tabs');
    expect(find.text('Weekend'), findsOneWidget);
  });

  testWidgets('location_denied_uses_selected_area_centre', (t) async {
    final queries = <HomeQuery>[];
    await pumpHome(t, queries: queries, device: null);
    expect((queries.last.lat, queries.last.lng), (3.129, 101.671), reason: 'Bangsar');
    expect(queries.last.km, 5);
  });

  testWidgets('a granted location is rounded to 0.01 degrees before it leaves the phone', (t) async {
    final queries = <HomeQuery>[];
    await pumpHome(t, queries: queries, device: (lat: 3.12345, lng: 101.67891));
    expect((queries.last.lat, queries.last.lng), (3.12, 101.68));
  });

  testWidgets('area_sheet_default_bangsar_5km_and_show_events_refetches', (t) async {
    final queries = <HomeQuery>[];
    await pumpHome(t, queries: queries, device: (lat: 3.2, lng: 101.7));
    await t.tap(find.byKey(const Key('area-pill')));
    await t.pumpAndSettle();
    expect(t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Bangsar')).selected, isTrue);
    expect(t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '5 km')).selected, isTrue);
    final fetched = queries.length;
    await t.tap(find.widgetWithText(ChoiceChip, 'KLCC'));
    await t.tap(find.widgetWithText(ChoiceChip, '10 km'));
    await t.pump();
    expect(queries.length, fetched, reason: 'choosing alone does not refetch');
    await t.tap(find.text('Show events'));
    await t.pumpAndSettle();
    expect((queries.last.lat, queries.last.lng), (3.1579, 101.7116), reason: 'KLCC, not the phone');
    expect(queries.last.km, 10);
    expect(find.byKey(const Key('area-pill')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('area-pill')), matching: find.textContaining('KLCC')), findsOneWidget);
  });

  testWidgets('all_tab_opens_view_all_page', (t) async {
    await pumpHome(t);
    await t.tap(find.text('All'));
    await t.pumpAndSettle();
    expect(find.text('VIEW ALL'), findsOneWidget);
  });

  testWidgets('the sky is the prototype\'s own gradient for each tab, not the theme colours', (t) async {
    await pumpHome(t);
    Color top() => ((t.widget<DecoratedBox>(find.byKey(const Key('home-sky'))).decoration as BoxDecoration).gradient as LinearGradient).colors.first;
    Color bottom() => ((t.widget<DecoratedBox>(find.byKey(const Key('home-sky'))).decoration as BoxDecoration).gradient as LinearGradient).colors.last;
    expect((top(), bottom()), (const Color(0xFF1A0F3D), const Color(0xFFFF9A62)), reason: 'Now: dark purple down to orange');
    await t.tap(find.text('Night'));
    await t.pumpAndSettle();
    expect((top(), bottom()), (const Color(0xFF050816), const Color(0xFF2A1F5C)), reason: 'Night');
    await t.tap(find.text('Weekend'));
    await t.pumpAndSettle();
    expect((top(), bottom()), (const Color(0xFF59B8FF), const Color(0xFFFFF0C9)), reason: 'Weekend: sky blue to cream');
  });

  testWidgets('the eyebrow line sits above the headline and follows the tab', (t) async {
    await pumpHome(t);
    expect(find.byKey(const Key('eyebrow')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('eyebrow'))).data, matches(RegExp(r'^[A-Z]{3} · \d{1,2}:\d{2} (AM|PM)$')));
    await t.tap(find.text('Night'));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.byKey(const Key('eyebrow'))).data, endsWith('TONIGHT'));
  });

  testWidgets('the stats line says "best 9 shown" when the area has more than nine events', (t) async {
    await pumpHome(t, stats: const HeroStats(total: 22, live: 7, free: 10, closestKm: .5));
    expect(find.textContaining('best 9 shown'), findsOneWidget);
  });

  testWidgets('a signed-in visitor sees their initial next to the bell; a signed-out one sees none', (t) async {
    await pumpHome(t, name: 'Mei');
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('avatar')), matching: find.byType(Text))).data, 'M');
    await pumpHome(t, name: null);
    expect(find.byKey(const Key('avatar')), findsNothing);
  });

  testWidgets('the tab dial is 44 tall and ends 96px above the bottom edge, just over the tab bar', (t) async {
    await pumpHome(t);
    final dial = find.byKey(const Key('dial'));
    expect(t.getSize(dial).height, 44);
    expect(t.getBottomLeft(dial).dy, 852 - 96);
  });

  testWidgets('the dock sits right on top of the dial, with the spare height going to the map (prototype)', (t) async {
    await pumpHome(t);
    final dockBottom = t.getBottomLeft(find.byKey(const Key('dock'))).dy;
    final dialTop = t.getTopLeft(find.byKey(const Key('dial'))).dy;
    expect(dockBottom, closeTo(dialTop, 1), reason: 'no empty band between the cards and the tab dial');
    expect(t.getSize(find.byKey(const Key('pin-map'))).height, greaterThan(250), reason: 'the map takes the spare height');
  });

  testWidgets('bell_shows_unread_badge', (t) async {
    await pumpHome(t, unread: 3);
    expect(find.descendant(of: find.byKey(const Key('bell')), matching: find.text('3')), findsOneWidget);
  });

  testWidgets('the bell has no badge when nothing is unread, and opens notifications', (t) async {
    await pumpHome(t, unread: 0);
    expect(find.byKey(const Key('bell-badge')), findsNothing);
    await t.tap(find.byKey(const Key('bell')));
    await t.pumpAndSettle();
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
  });
}
