import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/app.dart';
import 'package:jom/core/clock.dart';
import 'package:jom/core/launcher.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/core/config/app_config.dart';
import 'package:jom/core/supabase_client.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/booking/domain/booking.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/map_repository.dart';
import 'package:jom/features/home/presentation/map_screen.dart';
import 'package:jom/features/home/presentation/price_pin.dart';
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/shared/models/event_summary.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_chat.dart';
import '../../helpers/fake_events.dart';

/// Draws every tile as one transparent pixel so no test touches the network.
class _BlankTiles extends TileProvider {
  static final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(_png);
}

class _FakeMap implements MapRepository {
  _FakeMap(this.all);
  final List<EventSummary> all;
  final queries = <MapQuery>[];

  @override
  Future<List<EventSummary>> pins(MapQuery q) async {
    queries.add(q);
    return all.where((e) => q.category == 'all' || e.categories.contains(q.category)).toList();
  }
}

late _FakeMap fakeMap;
final launched = <Uri>[];

Future<void> pumpMap(WidgetTester t, List<EventSummary> events, {List<Booking> tickets = const [], LatLng? device}) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  fakeMap = _FakeMap(events);
  launched.clear();
  final router = createRouter(initialLocation: '/explore/map');
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      appConfigProvider.overrideWithValue(const AppConfig(flavor: 'dev', supabaseUrl: 'http://x', supabaseAnonKey: 'k')),
      mapTileProvider.overrideWithValue(_BlankTiles()),
      mapRepositoryProvider.overrideWithValue(fakeMap),
      launchUrlProvider.overrideWithValue((u) async {
        launched.add(u);
        return true;
      }),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(initial: fakeSession(name: 'Mei'))),
      eventRepositoryProvider.overrideWithValue(FakeEvents(all: events, details: {for (final e in events) e.id: detailOf(e)})),
      bookingRepositoryProvider.overrideWithValue(FakeBookings(upcoming: tickets)),
      chatRepositoryProvider.overrideWithValue(FakeChat()),
      nowProvider.overrideWithValue(() => clock),
      deviceLocationProvider.overrideWithValue(() async => device),
      bellCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
}

// Bangsar is the map's centre when there is no phone position; b is 2 km north of a.
final a = sum('a', title: 'Batik', price: 3000);
final b = sum('b', title: 'Salsa', price: 4500, lat: 3.1470, cats: const ['move']);
final free = sum('f', title: 'Picnic', price: 0, lat: 3.1290, lng: 101.6910, cats: const ['meet']);

PricePin pin(WidgetTester t, String id) => t.widget<PricePin>(find.descendant(of: find.byKey(Key('pin-$id')), matching: find.byType(PricePin)));

void main() {
  test('pinLabel_booked_free_and_paid', () {
    expect(pinLabel(a, {'a'}), '✓ Booked');
    expect(pinLabel(free, {'a'}), 'Free');
    expect(pinLabel(a, {}), 'RM 30');
  });

  test('user_position_sent_to_the_server_is_rounded_to_0_01_degrees', () {
    final p = mapPinsParams((lat: 3.129049, lng: 101.671651, km: 5, category: 'all', tonight: false));
    expect(p['p_lat'], 3.13);
    expect(p['p_lng'], 101.67);
  });

  group('Map', () {
    testWidgets('shows_a_price_pin_per_event_the_first_selected_and_its_card', (t) async {
      await pumpMap(t, [a, b]);
      expect(find.text('RM 30'), findsWidgets);
      expect(find.text('RM 45'), findsWidgets);
      expect(pin(t, 'a').selected, isTrue);
      expect(find.descendant(of: find.byKey(const Key('map-card-event')), matching: find.text('Batik')), findsOneWidget);
      expect(find.text('2 events in this area'), findsOneWidget);
    });

    testWidgets('selecting_a_pin_updates_the_bottom_card_and_highlights_the_pin', (t) async {
      await pumpMap(t, [a, b]);
      await t.tap(find.byKey(const Key('pin-b')));
      await t.pumpAndSettle();
      expect(pin(t, 'b').selected, isTrue);
      expect(pin(t, 'a').selected, isFalse);
      expect(find.descendant(of: find.byKey(const Key('map-card-event')), matching: find.text('Salsa')), findsOneWidget);
    });

    testWidgets('a_booked_event_shows_a_dark_booked_pin', (t) async {
      await pumpMap(t, [a, b], tickets: [bk('t1', event: 'b')]);
      expect(find.text('✓ Booked'), findsOneWidget);
      expect(pin(t, 'b').booked, isTrue);
      expect(pin(t, 'a').booked, isFalse);
    });

    testWidgets('category_chips_refetch_and_Tonight_sets_the_tonight_flag', (t) async {
      await pumpMap(t, [a, b]);
      expect(fakeMap.queries.last.category, 'all');
      await t.tap(find.byKey(const Key('map-chip-move')));
      await t.pumpAndSettle();
      expect((fakeMap.queries.last.category, fakeMap.queries.last.tonight), ('move', false));
      expect(find.byKey(const Key('pin-a')), findsNothing);
      await t.drag(find.byType(ListView), const Offset(-300, 0));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('map-chip-tonight')));
      await t.pumpAndSettle();
      expect((fakeMap.queries.last.category, fakeMap.queries.last.tonight), ('all', true));
    });

    testWidgets('search_this_area_appears_only_after_the_map_moves_and_refetches_once_at_the_centre', (t) async {
      await pumpMap(t, [a, b]);
      expect(find.byKey(const Key('map-search-area')), findsNothing);
      final before = fakeMap.queries.length;
      await t.drag(find.byType(FlutterMap), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('map-search-area')), findsOneWidget);
      expect(fakeMap.queries.length, before); // moving alone does not search
      await t.tap(find.byKey(const Key('map-search-area')));
      await t.pumpAndSettle();
      expect(fakeMap.queries.length, before + 1);
      expect(fakeMap.queries.last.lat, greaterThan(3.1290)); // dragging the map down moves the centre north
      expect(find.byKey(const Key('map-search-area')), findsNothing);
    });

    testWidgets('locate_with_a_position_recentres_and_searches_there', (t) async {
      await pumpMap(t, [a], device: (lat: 3.1579, lng: 101.7116));
      expect(find.byKey(const Key('map-me')), findsOneWidget);
      expect(fakeMap.queries.first.lat, 3.1579);
      await t.drag(find.byType(FlutterMap), const Offset(0, 300));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('map-locate')));
      await t.pumpAndSettle();
      expect(fakeMap.queries.last.lat, 3.1579);
      expect(find.byKey(const Key('map-search-area')), findsNothing);
    });

    testWidgets('locate_with_permission_denied_says_showing_the_selected_area', (t) async {
      await pumpMap(t, [a]);
      await t.tap(find.byKey(const Key('map-locate')));
      await t.pumpAndSettle();
      expect(find.text('Showing the selected area'), findsOneWidget);
      expect(find.byKey(const Key('map-me')), findsNothing);
    });

    testWidgets('no_results_shows_an_empty_card_and_no_pins', (t) async {
      await pumpMap(t, []);
      expect(find.byType(PricePin), findsNothing);
      expect(find.text('No events match this filter.'), findsOneWidget);
      expect(find.byKey(const Key('map-directions')), findsNothing);
    });

    testWidgets('directions_opens_a_maps_uri_with_the_event_lat_lng', (t) async {
      await pumpMap(t, [a]);
      await t.tap(find.byKey(const Key('map-directions')));
      await t.pumpAndSettle();
      expect(launched.single.host, 'www.google.com');
      expect(launched.single.queryParameters['destination'], '3.129,101.671');
    });

    testWidgets('attribution_openstreetmap_contributors_is_visible', (t) async {
      await pumpMap(t, [a]);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('view_event_opens_the_event_and_back_keeps_the_selection', (t) async {
      await pumpMap(t, [a, b]);
      await t.tap(find.byKey(const Key('pin-b')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('map-view-event')));
      await t.pumpAndSettle();
      expect(find.byType(MapScreen), findsNothing);
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await t.pumpAndSettle();
      expect(pin(t, 'b').selected, isTrue);
    });
  });
}
