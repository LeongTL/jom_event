import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/app.dart';
import 'package:jom/core/backend_check.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/core/theme/tokens.dart';
import 'package:jom/shared/models/event_summary.dart';
import 'package:jom/shared/widgets/shell.dart';

final yoga = EventSummary.fromJson({
  'event_id': 'e1', 'title': 'Sunset Yoga Deck', 'glyph': '🧘', 'color_a': '#11998e', 'color_b': '#38ef7d',
  'starts_at': '2026-10-15T14:22:00+00:00', 'ends_at': '2026-10-15T15:37:00+00:00', 'price_sen': 2500,
  'area': 'Bangsar', 'distance_km': 0.93, 'is_live': false, 'spots_left': 16, 'score': 1.67,
});
final sample = BackendCheck(totalEvents: 87, now: [yoga]);

Future<GoRouter> pumpApp(
  WidgetTester t, {
  String location = '/explore',
  Future<BackendCheck> Function()? check,
  List<Override> extra = const [],
}) async {
  final router = createRouter(initialLocation: location);
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      backendCheckProvider.overrideWith((ref) => (check ?? () async => sample)()),
      ...extra,
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
  return router;
}

String title(WidgetTester t) => t.widget<Text>(find.byKey(const Key('screen-title'))).data!;
String where(GoRouter r) => r.routeInformationProvider.value.uri.path;

void main() {
  testWidgets('the app opens on Explore with the five attendee tabs', (t) async {
    final router = await pumpApp(t);
    expect(where(router), '/explore');
    expect(title(t), 'Explore');
    for (final label in ['Explore', 'Saved', 'Bookings', 'Chat', 'Profile']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('tapping each tab opens its screen, and Explore brings you back', (t) async {
    final router = await pumpApp(t);
    for (final entry in {'Saved': '/saved', 'Bookings': '/bookings', 'Chat': '/chats', 'Profile': '/profile', 'Explore': '/explore'}.entries) {
      await t.tap(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text(entry.key)));
      await t.pumpAndSettle();
      expect(where(router), entry.value, reason: entry.key);
      expect(title(t), entry.key);
    }
  });

  testWidgets('router_redirects_unknown_path_to_explore', (t) async {
    final router = await pumpApp(t, location: '/this/does/not/exist');
    expect(where(router), '/explore');
    expect(title(t), 'Explore');
  });

  testWidgets('every route in the plan opens and is not bounced to Explore', (t) async {
    const paths = [
      '/explore', '/saved', '/bookings', '/chats', '/chats/t1', '/profile', '/event/e1', '/event/e1/checkout',
      '/booking/b1/gateway', '/booking/b1/processing', '/booking/b1/failed', '/booking/b1/ticket', '/review/b1',
      '/host/h1', '/notifications', '/host-mode/home', '/host-mode/events', '/host-mode/events/e1',
      '/host-mode/events/e1/edit', '/host-mode/events/e1/scan', '/host-mode/events/e1/checkin',
      '/host-mode/events/e1/guests', '/host-mode/new', '/host-mode/payouts', '/host-mode/payout-account',
      '/host-mode/chats', '/host-mode/profile',
    ];
    for (final p in paths) {
      final router = await pumpApp(t, location: p);
      expect(where(router), p, reason: p);
      expect(find.byKey(const Key('screen-title')), findsOneWidget, reason: p);
    }
  });

  testWidgets('screens that are not tabs hide the tab bar', (t) async {
    for (final p in ['/event/e1', '/event/e1/checkout', '/chats/t1', '/booking/b1/ticket', '/notifications', '/host-mode/new', '/host-mode/events/e1/scan']) {
      await pumpApp(t, location: p);
      expect(find.byKey(const Key('tab-bar')), findsNothing, reason: p);
    }
    for (final p in ['/explore', '/saved', '/bookings', '/chats', '/profile', '/host-mode/home', '/host-mode/events', '/host-mode/payouts', '/host-mode/chats', '/host-mode/profile']) {
      await pumpApp(t, location: p);
      expect(find.byKey(const Key('tab-bar')), findsOneWidget, reason: p);
    }
  });

  testWidgets('host mode has its own five tabs', (t) async {
    final router = await pumpApp(t, location: '/host-mode/home');
    expect(title(t), 'Host home');
    for (final label in ['Home', 'Events', 'Payouts', 'Chat', 'Profile']) {
      expect(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text(label)), findsOneWidget, reason: label);
    }
    expect(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text('Explore')), findsNothing);

    await t.tap(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text('Payouts')));
    await t.pumpAndSettle();
    expect(where(router), '/host-mode/payouts');
  });

  testWidgets('the Chat tab shows the unread count it is given', (t) async {
    await pumpApp(t, extra: [chatBadgeCountProvider.overrideWithValue(4)]);
    expect(find.byKey(const Key('tab-badge')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('the app is painted with the Now theme to start with', (t) async {
    await pumpApp(t);
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.extension<JomTokens>(), JomTokens.of(JomTheme.now));
    expect(app.title, 'Jom');
  });

  group('the Explore placeholder proves the app can read the backend', () {
    testWidgets('it shows the live counts and the first events, priced with formatMoney', (t) async {
      await pumpApp(t);
      expect(find.text('Connected to the backend'), findsOneWidget);
      expect(find.textContaining('87 events'), findsOneWidget);
      expect(find.text('Sunset Yoga Deck'), findsOneWidget);
      expect(find.textContaining('RM 25'), findsOneWidget);
    });

    testWidgets('it says so when the backend cannot be reached', (t) async {
      await pumpApp(t, check: () async => throw Exception('offline'));
      expect(find.text('Could not reach the backend'), findsOneWidget);
    });

    testWidgets('it shows a spinner while it waits', (t) async {
      final router = createRouter();
      await t.pumpWidget(ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(router),
          backendCheckProvider.overrideWith((ref) => Future<BackendCheck>.delayed(const Duration(seconds: 5), () => sample)),
        ],
        child: const JomApp(),
      ));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
    });
  });
}
