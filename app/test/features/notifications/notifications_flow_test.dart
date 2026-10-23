import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/app.dart';
import 'package:jom/core/clock.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/core/theme/tokens.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/chat/domain/chat.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/home/domain/home_feed.dart';
import 'package:jom/features/notifications/data/notification_repository.dart';
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/features/notifications/domain/notification.dart';
import 'package:jom/features/notifications/presentation/bell_button.dart';
import 'package:jom/shared/widgets/jom_switch.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_chat.dart';
import '../../helpers/fake_events.dart';
import '../../helpers/fake_notifications.dart';

// the shared fake clock: 14:00 in Kuala Lumpur on Wednesday 9 January 2030
final n1 = note('n1', 'payment', 'Booking confirmed', clock.subtract(const Duration(minutes: 2)), refType: 'booking', refId: 'b1', body: 'Beginner Mat Pilates');
final n2 = note('n2', 'chat_message', 'Mei Studio replied', clock.subtract(const Duration(hours: 1)), refType: 'thread', refId: 't1', body: 'Yes, mats are provided');
final n3 = note('n3', 'payout', 'Payout scheduled', clock.subtract(const Duration(days: 1)), refType: 'event', refId: 'e1', body: 'RM 25', read: true);
final n4 = note('n4', 'event_cancelled', 'Salsa Social was cancelled', clock.subtract(const Duration(days: 2)), refType: 'event', refId: 'e1', body: 'RM25 is on its way back', read: true);

Future<GoRouter> pumpApp(WidgetTester t, {String location = '/notifications', FakeNotifications? repo, bool signedIn = true, FakeChat? chat}) async {
  // wider than a phone on purpose: the test font's letters are so wide that tab names would wrap
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = createRouter(initialLocation: location);
  final start = t.binding.clock.now();
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(initial: signedIn ? fakeSession(name: 'Mei') : null)),
      notificationRepositoryProvider.overrideWithValue(repo ?? FakeNotifications()),
      eventRepositoryProvider.overrideWithValue(FakeEvents(details: {'e1': detailOf(sum('e1', title: 'Batik Workshop'))})),
      chatRepositoryProvider.overrideWithValue(chat ?? FakeChat(infos: {'t1': const ThreadInfo(id: 't1', iAmHost: false, otherName: 'Mei Studio')})),
      bookingRepositoryProvider.overrideWithValue(FakeBookings()..byId['b1'] = bk('b1', status: 'confirmed')),
      nowProvider.overrideWithValue(() => clock.add(t.binding.clock.now().difference(start))),
      homeFeedProvider.overrideWith((ref, q) async => HomeFeed(tab: q.tab, top9: const [], stats: const HeroStats(total: 0, live: 0, free: 0, closestKm: null))),
      deviceLocationProvider.overrideWithValue(() async => null),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
  return router;
}

Finder key(String k) => find.byKey(Key(k));
// the top of the stack: a pushed screen does not move the router's own location
String where(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('the list', () {
    testWidgets('list_shows_icon_title_body_time_and_unread_dot', (t) async {
      await pumpApp(t, repo: FakeNotifications(items: [n1, n2, n3, n4]));
      expect(key('notifications-screen'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      for (final s in ['✅', '💬', '💸', '↩️', 'Booking confirmed', 'Beginner Mat Pilates', 'Mei Studio replied', 'Yes, mats are provided', 'Payout scheduled']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      for (final w in ['2 min ago', '1 h ago', 'Yesterday', 'Mon']) {
        expect(find.text(w), findsOneWidget, reason: w);
      }
      expect(key('notif-dot-n1'), findsOneWidget);
      expect(key('notif-dot-n2'), findsOneWidget);
      expect(key('notif-dot-n3'), findsNothing);
      expect(key('notif-dot-n4'), findsNothing);
    });

    testWidgets('an empty list says so, and the switches are still there', (t) async {
      await pumpApp(t);
      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('SHOW ME'), findsOneWidget);
    });

    testWidgets('a notice that arrives while the screen is open shows at the top and is marked read', (t) async {
      final repo = FakeNotifications(items: [n3]);
      await pumpApp(t, repo: repo);
      repo.push(n1);
      await t.pumpAndSettle();
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(t.getTopLeft(key('notif-n1')).dy, lessThan(t.getTopLeft(key('notif-n3')).dy));
      expect(repo.marked, ['n1']);
    });

    testWidgets('signed_out visitors get the sign-in prompt, with a way back', (t) async {
      await pumpApp(t, signedIn: false);
      expect(find.text('Sign in to see your notifications'), findsOneWidget);
      expect(key('notifications-screen'), findsNothing);
      expect(key('nav-back'), findsOneWidget);
    });
  });

  group('reading', () {
    testWidgets('opening_screen_marks_visible_items_read_and_badge_drops', (t) async {
      final repo = FakeNotifications(items: [n1, n2, n3]);
      await pumpApp(t, location: '/explore', repo: repo);
      expect(find.descendant(of: key('bell-badge'), matching: find.text('2')), findsOneWidget);

      await t.tap(key('bell'));
      await t.pumpAndSettle();
      expect(key('notifications-screen'), findsOneWidget);
      expect(repo.marked, unorderedEquals(['n1', 'n2']), reason: 'only the unread ones are sent');
      expect(key('notif-dot-n1'), findsOneWidget, reason: 'the dots stay for this visit so you can see what was new');

      await t.tap(key('nav-back'));
      await t.pumpAndSettle();
      expect(key('home-screen'), findsOneWidget);
      expect(key('bell-badge'), findsNothing, reason: 'the bell badge dropped to nothing');
    });

    testWidgets('a failure to mark read is quiet: the screen still works', (t) async {
      final repo = FakeNotifications(items: [n1])..markError = Exception('offline');
      await pumpApp(t, repo: repo);
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('tapping a row', () {
    for (final c in [
      ('n1', '/booking/b1/ticket', 'ticket-screen'),
      ('n2', '/chats/t1', 'thread-screen'),
      ('n4', '/event/e1', 'event-screen'),
      ('n3', '/host-mode/payouts', 'screen-title'),
    ]) {
      testWidgets('tap_routes_by_ref_type: ${c.$1} opens ${c.$2}', (t) async {
        final router = await pumpApp(t, repo: FakeNotifications(items: [n1, n2, n3, n4]));
        await t.tap(key('notif-${c.$1}'));
        await t.pumpAndSettle();
        expect(key(c.$3), findsOneWidget);
        expect(where(router), c.$2);
      });
    }

    testWidgets('a notice with nothing to open stays where it is', (t) async {
      final router = await pumpApp(t, repo: FakeNotifications(items: [note('n9', 'payment', 'Hello', clock)]));
      await t.tap(key('notif-n9'));
      await t.pumpAndSettle();
      expect(where(router), '/notifications');
    });
  });

  group('Show me', () {
    testWidgets('show_me_switches_chat_and_review_requests_toggle_prefs', (t) async {
      final repo = FakeNotifications();
      await pumpApp(t, repo: repo);
      expect(t.widget<JomSwitch>(key('switch-chat')).value, true);
      expect(t.widget<JomSwitch>(key('switch-review')).value, true);

      await t.tap(key('switch-chat'));
      await t.pumpAndSettle();
      expect(t.widget<JomSwitch>(key('switch-chat')).value, false);
      expect(repo.saved.last, const NotificationPrefs(chat: false, reviewRequests: true));

      await t.tap(key('switch-review'));
      await t.pumpAndSettle();
      expect(repo.saved.last, const NotificationPrefs(chat: false, reviewRequests: false), reason: 'both are saved together');

      await t.tap(key('switch-chat'));
      await t.pumpAndSettle();
      expect(repo.saved.last, const NotificationPrefs(chat: true, reviewRequests: false), reason: 'turning one back on keeps the other as it is');
    });

    testWidgets('the switches start where the account has them', (t) async {
      await pumpApp(t, repo: FakeNotifications(prefsValue: const NotificationPrefs(chat: false, reviewRequests: true)));
      expect(t.widget<JomSwitch>(key('switch-chat')).value, false);
      expect(t.widget<JomSwitch>(key('switch-review')).value, true);
    });

    testWidgets('a switch that cannot be saved flips back and says so', (t) async {
      final repo = FakeNotifications()..saveError = Exception('offline');
      await pumpApp(t, repo: repo);
      await t.tap(key('switch-chat'));
      await t.pumpAndSettle();
      expect(t.widget<JomSwitch>(key('switch-chat')).value, true);
      expect(find.text('Could not save that. Try again.'), findsOneWidget);
    });

    testWidgets('booking_payment_and_event_change_rows_are_always_on_and_not_toggleable', (t) async {
      final repo = FakeNotifications();
      await pumpApp(t, repo: repo);
      expect(find.text('Always on'), findsNWidgets(2));
      for (final k in ['switch-booking', 'switch-event']) {
        expect(t.widget<JomSwitch>(key(k)).value, true, reason: k);
        await t.tap(key(k));
        await t.pumpAndSettle();
        expect(t.widget<JomSwitch>(key(k)).value, true, reason: k);
      }
      expect(repo.saved, isEmpty);
    });

    testWidgets('footer_says_no_push_notifications_yet', (t) async {
      await pumpApp(t);
      expect(find.text("Notifications show inside Jom only. We don't send push notifications yet."), findsOneWidget);
    });
  });

  group('the bell', () {
    Future<void> pumpBell(WidgetTester t, int count) => t.pumpWidget(ProviderScope(
          overrides: [bellCountProvider.overrideWith((ref) => Stream.value(count))],
          child: MaterialApp(
            theme: ThemeData(extensions: [JomTokens.of(JomTheme.now)]),
            home: const Scaffold(body: Center(child: BellButton())),
          ),
        ));

    testWidgets('bell_on_host_home_also_shows_count: the same button, wherever it is put', (t) async {
      await pumpBell(t, 3);
      await t.pump();
      expect(find.descendant(of: key('bell-badge'), matching: find.text('3')), findsOneWidget);
    });

    testWidgets('a signed-out visitor sees no badge and the backend is never asked', (t) async {
      final repo = FakeNotifications(items: [n1]);
      await pumpApp(t, location: '/explore', repo: repo, signedIn: false);
      expect(key('bell'), findsOneWidget);
      expect(key('bell-badge'), findsNothing);
      expect(repo.unreadCalls, 0);
    });

    testWidgets('no badge when nothing is unread', (t) async {
      await pumpBell(t, 0);
      await t.pump();
      expect(key('bell'), findsOneWidget);
      expect(key('bell-badge'), findsNothing);
    });
  });
}
