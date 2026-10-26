import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/app.dart';
import 'package:jom/core/clock.dart';
import 'package:jom/core/config/app_config.dart';
import 'package:jom/core/supabase_client.dart';
import 'package:jom/features/home/data/map_repository.dart';
import 'package:jom/features/home/presentation/map_screen.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/booking/domain/booking.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/home/domain/home_query.dart';
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/shared/models/event_summary.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_chat.dart';
import '../../helpers/fake_events.dart';
import '../../helpers/fake_map.dart';

final queries = <HomeQuery>[];
final weekendAreas = <HomeArea>[];

Future<GoRouter> pumpHome(
  WidgetTester t, {
  List<EventSummary> near = const [],
  List<EventSummary> weekend = const [],
  List<Booking> tickets = const [],
  bool signedIn = true,
  int unread = 0,
  LatLng? device,
  DateTime? now,
}) async {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  queries.clear();
  weekendAreas.clear();
  final router = createRouter(initialLocation: '/explore');
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      appConfigProvider.overrideWithValue(const AppConfig(flavor: 'dev', supabaseUrl: 'http://x', supabaseAnonKey: 'k')),
      mapTileProvider.overrideWithValue(BlankTiles()),
      mapRepositoryProvider.overrideWithValue(FakeMap(const [])),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(initial: signedIn ? fakeSession(name: 'Mei') : null)),
      eventRepositoryProvider.overrideWithValue(FakeEvents(all: [...near, ...weekend])),
      bookingRepositoryProvider.overrideWithValue(FakeBookings(upcoming: tickets)),
      chatRepositoryProvider.overrideWithValue(FakeChat()),
      nowProvider.overrideWithValue(() => now ?? clock),
      weekendProvider.overrideWith((ref, a) async {
        weekendAreas.add(a);
        return weekend;
      }),
      nearYouProvider.overrideWith((ref, q) async {
        queries.add(q);
        return near.where((e) => (q.category == null || e.categories.contains(q.category)) && e.title.toLowerCase().contains(q.query.toLowerCase())).toList();
      }),
      deviceLocationProvider.overrideWithValue(() async => device),
      bellCountProvider.overrideWith((ref) => Stream.value(unread)),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
  return router;
}

EventSummary at(String id, {String title = 'Event', List<String> cats = const ['make']}) => sum(id, title: '$title $id', cats: cats);

void main() {
  test('title_switches_from_Today_to_Tonight_at_17_00_in_kuala_lumpur', () {
    expect(homeTitle(DateTime.utc(2030, 1, 9, 8, 59), 'Bangsar'), 'Today in Bangsar'); // 16:59 KL
    expect(homeTitle(DateTime.utc(2030, 1, 9, 9), 'Bangsar'), 'Tonight in Bangsar'); // 17:00 KL
    expect(homeTitle(DateTime.utc(2030, 1, 9, 15), 'KLCC'), 'Tonight in KLCC'); // 23:00 KL
  });

  group('Home', () {
    testWidgets('header_has_area_pill_title_eyebrow_and_the_bell_with_its_unread_badge', (t) async {
      await pumpHome(t, unread: 3);
      expect(find.text('Bangsar, KL ▾'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('home-title'))).data, 'Today in Bangsar');
      expect(t.widget<Text>(find.byKey(const Key('eyebrow'))).data, 'WED 9 JAN · 2:00 PM');
      expect(find.byKey(const Key('bell-badge')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('ticket_row_hidden_when_signed_out', (t) async {
      await pumpHome(t, signedIn: false, near: [at('a')], tickets: [bk('b1', event: 'a')]);
      expect(find.byKey(const Key('ticket-row')), findsNothing);
    });

    testWidgets('ticket_row_hidden_without_upcoming_tickets', (t) async {
      await pumpHome(t, near: [at('a')]);
      expect(find.byKey(const Key('ticket-row')), findsNothing);
    });

    testWidgets('ticket_row_shows_at_most_5_tickets_by_start_time_without_overflow', (t) async {
      final events = [for (var i = 0; i < 10; i++) sum('e$i', title: 'Very long title number $i ' * 8, starts: clock.add(Duration(hours: 10 - i)))];
      await pumpHome(t, near: events, tickets: [for (var i = 0; i < 10; i++) bk('b$i', event: 'e$i', code: 'KLS-0$i')]);
      expect(find.byKey(const Key('ticket-row')), findsOneWidget);
      expect(find.byType(Text).evaluate().where((e) => (e.widget as Text).data == 'Spots').length, lessThanOrEqualTo(5));
      expect(t.takeException(), isNull);
    });

    testWidgets('one_ticket_shows_one_boarding_pass', (t) async {
      await pumpHome(t, near: [at('a')], tickets: [bk('b1', event: 'a')]);
      expect(find.text('Spots'), findsOneWidget);
    });

    testWidgets('search_waits_300ms_then_asks_once', (t) async {
      await pumpHome(t, near: [at('a', title: 'Yoga'), at('b', title: 'Salsa')]);
      queries.clear();
      await t.enterText(find.byKey(const Key('home-search')), 'sal');
      await t.pump(const Duration(milliseconds: 200));
      expect(queries, isEmpty);
      await t.enterText(find.byKey(const Key('home-search')), 'salsa');
      await t.pump(const Duration(milliseconds: 299));
      expect(queries, isEmpty);
      await t.pumpAndSettle(const Duration(milliseconds: 400));
      expect(queries.map((q) => q.query), ['salsa']);
      expect(find.byKey(const Key('event-row-b')), findsOneWidget);
      expect(find.byKey(const Key('event-row-a')), findsNothing);
    });

    testWidgets('category_tile_filters_near_you_and_a_second_tap_clears_it', (t) async {
      await pumpHome(t, near: [at('a', cats: ['make']), at('b', cats: ['move'])]);
      await t.tap(find.byKey(const Key('tile-move')));
      await t.pumpAndSettle();
      expect(queries.last.category, 'move');
      expect(find.byKey(const Key('event-row-b')), findsOneWidget);
      expect(find.byKey(const Key('event-row-a')), findsNothing);
      await t.tap(find.byKey(const Key('tile-move')));
      await t.pumpAndSettle();
      expect(queries.last.category, isNull);
      expect(find.byKey(const Key('event-row-a')), findsOneWidget);
    });

    testWidgets('no_matches_says_Nothing_matches_yet', (t) async {
      await pumpHome(t, near: [at('a')]);
      await t.enterText(find.byKey(const Key('home-search')), 'zzz');
      await t.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('Nothing matches yet. Try another word or category.'), findsOneWidget);
    });

    testWidgets('weekend_section_is_hidden_when_empty', (t) async {
      await pumpHome(t, near: [at('a')]);
      expect(find.text('This weekend'), findsNothing);
    });

    testWidgets('weekend_section_shows_its_cards', (t) async {
      await pumpHome(t, near: [at('a')], weekend: [at('w')]);
      expect(find.text('This weekend'), findsOneWidget);
      expect(find.byKey(const Key('event-card-w')), findsOneWidget);
    });

    testWidgets('near_you_shows_4_nearest_and_the_button_counts_all_of_them', (t) async {
      await pumpHome(t, near: [for (var i = 0; i < 7; i++) at('n$i')]);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('event-row-n$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('event-row-n4')), findsNothing);
      expect(find.text('View all 7 events'), findsOneWidget);
    });

    testWidgets('map_card_says_N_events_within_km_and_opens_the_map', (t) async {
      await pumpHome(t, near: [at('a'), at('b')]);
      expect(find.text('2 events within 5 km'), findsOneWidget);
      await t.tap(find.byKey(const Key('map-card')));
      await t.pumpAndSettle();
      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets('view_all_links_pass_the_category', (t) async {
      await pumpHome(t, near: [at('a', cats: ['make']), at('b', cats: ['move'])]);
      await t.tap(find.byKey(const Key('tile-make')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('view-all-button')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('view-all')), findsOneWidget);
      expect(find.text('1 event · nearest first'), findsOneWidget, reason: 'opened on Make');
    });

    testWidgets('location_denied_searches_from_the_selected_area_centre', (t) async {
      await pumpHome(t, near: [at('a')], device: null);
      expect(queries.last.lat, kAreas['Bangsar']!.lat);
      expect(queries.last.lng, kAreas['Bangsar']!.lng);
      expect(find.byKey(const Key('event-row-a')), findsOneWidget);
    });

    testWidgets('no_events_at_all_shows_a_plain_empty_state', (t) async {
      await pumpHome(t);
      expect(find.text('Nothing right now'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
