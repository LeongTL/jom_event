import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/app.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/core/theme/calm.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/chat/domain/chat.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/host/data/host_repository.dart';
import 'package:jom/features/notifications/data/notification_repository.dart';
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/shared/models/event_summary.dart';
import 'package:jom/shared/widgets/skeleton.dart';
import 'package:jom/features/reviews/data/review_repository.dart';
import 'package:jom/shared/widgets/shell.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_bookings.dart';
import 'helpers/fake_chat.dart';
import 'helpers/fake_events.dart';
import 'helpers/fake_host.dart';
import 'helpers/fake_notifications.dart';
import 'helpers/fake_reviews.dart';

final yoga = EventSummary.fromJson({
  'event_id': 'e1',
  'title': 'Sunset Yoga Deck',
  'glyph': '🧘',
  'color_a': '#11998e',
  'color_b': '#38ef7d',
  'starts_at': '2026-10-15T14:22:00+00:00',
  'ends_at': '2026-10-15T15:37:00+00:00',
  'price_sen': 2500,
  'area': 'Bangsar',
  'distance_km': 0.93,
  'is_live': false,
  'spots_left': 16,
  'score': 1.67,
});

Future<GoRouter> pumpApp(
  WidgetTester t, {
  String location = '/explore',
  Future<List<EventSummary>> Function()? near,
  List<Override> extra = const [],
  bool settle = true, // the Processing screen spins forever, so a route that shows it cannot settle
}) async {
  final router = createRouter(initialLocation: location);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initial: fakeSession(name: 'Mei')),
        ), // signed in: these tests are about the app shell
        eventRepositoryProvider.overrideWithValue(FakeEvents()),
        chatRepositoryProvider.overrideWithValue(
          FakeChat(
            infos: {
              't1': const ThreadInfo(
                id: 't1',
                iAmHost: false,
                otherName: 'Mei Studio',
              ),
            },
          ),
        ),
        bookingRepositoryProvider.overrideWithValue(
          FakeBookings()..byId['b1'] = bk('b1', status: 'processing'),
        ),
        notificationRepositoryProvider.overrideWithValue(FakeNotifications()),
        reviewRepositoryProvider.overrideWithValue(FakeReviews()),
        hostRepositoryProvider.overrideWithValue(FakeHost(profile: hostMe())),
        weekendProvider.overrideWith((ref, a) async => <EventSummary>[]),
        nearYouProvider.overrideWith(
          (ref, q) => (near ?? () async => [yoga])(),
        ),
        deviceLocationProvider.overrideWithValue(() async => null),
        bellCountProvider.overrideWith((ref) => Stream.value(0)),
        ...extra,
      ],
      child: const JomApp(),
    ),
  );
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }
  return router;
}

String title(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('screen-title'))).data!;
String where(GoRouter r) => r.routeInformationProvider.value.uri.path;

void main() {
  testWidgets('the app opens on Explore with the five attendee tabs', (
    t,
  ) async {
    final router = await pumpApp(t);
    expect(where(router), '/explore');
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    for (final label in ['Explore', 'Saved', 'Tickets', 'Chat', 'Profile']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets(
    'tapping each tab opens its screen, and Explore brings you back',
    (t) async {
      final router = await pumpApp(t);
      for (final entry in {
        'Saved': '/saved',
        'Tickets': '/tickets',
        'Chat': '/chats',
        'Profile': '/profile',
        'Explore': '/explore',
      }.entries) {
        await t.tap(
          find.descendant(
            of: find.byKey(const Key('tab-bar')),
            matching: find.text(entry.key),
          ),
        );
        await t.pumpAndSettle();
        expect(where(router), entry.value, reason: entry.key);
        if (entry.value == '/explore') {
          expect(find.byKey(const Key('home-screen')), findsOneWidget);
        } else if (entry.value == '/saved') {
          expect(find.byKey(const Key('saved-screen')), findsOneWidget);
        } else if (entry.value == '/tickets') {
          expect(find.byKey(const Key('tickets-screen')), findsOneWidget);
        } else if (entry.value == '/chats') {
          expect(find.byKey(const Key('chat-list-screen')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('profile-screen')), findsOneWidget);
        }
      }
    },
  );

  testWidgets('router_redirects_unknown_path_to_explore', (t) async {
    final router = await pumpApp(t, location: '/this/does/not/exist');
    expect(where(router), '/explore');
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
  });

  testWidgets('every route in the plan opens and is not bounced to Explore', (
    t,
  ) async {
    const paths = [
      '/explore',
      '/saved',
      '/tickets',
      '/chats',
      '/chats/t1',
      '/profile',
      '/event/e1',
      '/event/e1/checkout',
      '/booking/b1/gateway',
      '/booking/b1/processing',
      '/booking/b1/failed',
      '/booking/b1/ticket',
      '/review/b1',
      '/host/h1',
      '/notifications',
      '/host-mode/home',
      '/host-mode/events',
      '/host-mode/events/e1',
      '/host-mode/events/e1/edit',
      '/host-mode/events/e1/scan',
      '/host-mode/events/e1/checkin',
      '/host-mode/events/e1/guests',
      '/host-mode/new',
      '/host-mode/payouts',
      '/host-mode/payout-account',
      '/host-mode/chats',
      '/host-mode/profile',
      '/explore/all',
      '/my-reviews',
      '/help',
      '/legal',
    ];
    for (final p in paths) {
      final router = await pumpApp(
        t,
        location: p,
        settle: p != '/booking/b1/processing',
      );
      expect(where(router), p, reason: p);
      final screen =
          {
            '/explore': 'home-screen',
            '/saved': 'saved-screen',
            '/explore/all': 'view-all',
            '/event/e1': 'event-screen',
            '/tickets': 'tickets-screen',
            '/chats': 'chat-list-screen',
            '/chats/t1': 'thread-screen',
            '/host-mode/chats': 'chat-list-screen',
            '/event/e1/checkout': 'checkout-screen',
            '/booking/b1/gateway': 'gateway-screen',
            '/booking/b1/processing': 'processing-screen',
            '/booking/b1/failed': 'failed-screen',
            '/booking/b1/ticket': 'ticket-screen',
            '/notifications': 'notifications-screen',
            '/profile': 'profile-screen',
            '/review/b1': 'review-screen',
            '/host/h1': 'host-public-screen',
            '/my-reviews': 'my-reviews-screen',
            '/help': 'help-screen',
            '/legal': 'legal-screen',
            '/host-mode/home': 'host-home',
            '/host-mode/events': 'host-events',
            '/host-mode/profile': 'host-profile',
            '/host-mode/new': 'form-title',
            '/host-mode/payout-account': 'apply-name',
            '/host-mode/events/e1/edit': 'event-missing',
            '/host-mode/payouts': 'payouts',
            '/host-mode/events/e1': 'host-event',
            '/host-mode/events/e1/scan': 'scan-screen',
            '/host-mode/events/e1/checkin': 'checkin-screen',
            '/host-mode/events/e1/guests': 'guest-list',
          }[p] ??
          'screen-title';
      expect(find.byKey(Key(screen)), findsOneWidget, reason: p);
    }
  });

  testWidgets('screens that are not tabs hide the tab bar', (t) async {
    for (final p in [
      '/event/e1',
      '/event/e1/checkout',
      '/chats/t1',
      '/booking/b1/ticket',
      '/notifications',
      '/explore/all',
      '/host-mode/new',
      '/host-mode/events/e1/scan',
    ]) {
      await pumpApp(t, location: p);
      expect(find.byKey(const Key('tab-bar')), findsNothing, reason: p);
    }
    for (final p in [
      '/explore',
      '/saved',
      '/tickets',
      '/chats',
      '/profile',
      '/host-mode/home',
      '/host-mode/events',
      '/host-mode/payouts',
      '/host-mode/chats',
      '/host-mode/profile',
    ]) {
      await pumpApp(t, location: p);
      expect(find.byKey(const Key('tab-bar')), findsOneWidget, reason: p);
    }
  });

  testWidgets(
    'the tab bar is a full-width white bar flush with the bottom edge, above the home indicator',
    (t) async {
      // 852 points tall with the iPhone's 47 / 34 points of safe area. Wider than a phone on purpose: the test
      // font's letters are so wide that "Tickets" could wrap inside a phone-narrow tab.
      t.view.physicalSize = const Size(800, 852);
      t.view.devicePixelRatio = 1;
      t.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      t.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(t.view.reset);
      await pumpApp(t);
      expect(t.getBottomLeft(find.byKey(const Key('tab-bar'))).dy, 852);
      expect(t.getSize(find.byKey(const Key('tab-bar'))).width, 800);
      expect(t.getSize(find.byKey(const Key('tab-bar'))).height, 62 + 34);
    },
  );

  testWidgets('host mode has its own five tabs', (t) async {
    final router = await pumpApp(t, location: '/host-mode/home');
    expect(find.byKey(const Key('host-home')), findsOneWidget);
    for (final label in ['Home', 'Events', 'Payouts', 'Chat', 'Profile']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('tab-bar')),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('tab-bar')),
        matching: find.text('Explore'),
      ),
      findsNothing,
    );

    await t.tap(
      find.descendant(
        of: find.byKey(const Key('tab-bar')),
        matching: find.text('Payouts'),
      ),
    );
    await t.pumpAndSettle();
    expect(where(router), '/host-mode/payouts');
  });

  testWidgets('the Chat tab shows the unread count it is given', (t) async {
    await pumpApp(t, extra: [chatBadgeCountProvider.overrideWithValue(4)]);
    expect(find.byKey(const Key('tab-badge')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(
      t.getSize(find.byKey(const Key('tab-badge'))).width,
      lessThan(30),
      reason: 'a small dot with the number, not a bar across the tab',
    );
  });

  testWidgets('the app is painted with the Now theme to start with', (t) async {
    await pumpApp(t);
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.extension<JomTokens>(), isNotNull);
    expect(app.title, 'Jom');
  });

  group('Home reads the backend through the app', () {
    testWidgets('it shows the nearby events with their price', (t) async {
      await pumpApp(t);
      expect(find.text('Sunset Yoga Deck'), findsOneWidget);
      expect(find.textContaining('RM 25'), findsOneWidget);
    });

    testWidgets('it says so when the backend cannot be reached', (t) async {
      await pumpApp(t, near: () async => throw Exception('offline'));
      expect(find.textContaining('Could not load events'), findsOneWidget);
    });

    testWidgets('it shows a skeleton while it waits', (t) async {
      final router = createRouter();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            routerProvider.overrideWithValue(router),
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(initial: fakeSession(name: 'Mei')),
            ),
            weekendProvider.overrideWith((ref, a) async => <EventSummary>[]),
            nearYouProvider.overrideWith(
              (ref, q) => Future<List<EventSummary>>.delayed(
                const Duration(seconds: 5),
                () => [yoga],
              ),
            ),
            deviceLocationProvider.overrideWithValue(() async => null),
            bellCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const JomApp(),
        ),
      );
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.pump(const Duration(seconds: 6));
    });
  });
}
