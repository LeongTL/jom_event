import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/app.dart';
import 'package:jom/core/clock.dart';
import 'package:jom/core/launcher.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/chat/domain/chat.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/event/domain/event_detail.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/home/domain/home_feed.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_chat.dart';
import '../../helpers/fake_events.dart';

late FakeEvents events;
late FakeAuthRepository auth;
final launched = <Uri>[];

Future<GoRouter> pumpApp(WidgetTester t, {String location = '/all', bool signedIn = true, FakeEvents? repo}) async {
  // wider than a phone on purpose: the test font's letters are so wide that tab names would wrap
  t.view.physicalSize = const Size(800, 1700);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  events = repo ?? FakeEvents();
  auth = FakeAuthRepository(initial: signedIn ? fakeSession(name: 'Mei') : null, newUserHasName: true);
  launched.clear();
  final start = t.binding.clock.now();
  final router = createRouter(initialLocation: location);
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(auth),
      eventRepositoryProvider.overrideWithValue(events),
      bookingRepositoryProvider.overrideWithValue(FakeBookings()),
      chatRepositoryProvider.overrideWithValue(FakeChat(infos: {'t1': const ThreadInfo(id: 't1', iAmHost: false, otherName: 'Mei Studio')})),
      nowProvider.overrideWithValue(() => clock.add(t.binding.clock.now().difference(start))), // the test's clock starts at 14:00 KL
      launchUrlProvider.overrideWithValue((u) async {
        launched.add(u);
        return true;
      }),
      homeFeedProvider.overrideWith((ref, q) async => HomeFeed(tab: q.tab, top9: const [], stats: const HeroStats(total: 0, live: 0, free: 0, closestKm: null))),
      deviceLocationProvider.overrideWithValue(() async => null),
      unreadCountProvider.overrideWith((ref) async => 0),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
  return router;
}

Finder poster(String id) => find.byKey(Key('poster-$id'));
Finder heartOn(String id) => find.byKey(Key('heart-on:$id'));
Finder heartOff(String id) => find.byKey(Key('heart-off:$id'));
Future<void> signInWithPhone(WidgetTester t) async {
  await t.tap(find.text('Continue with phone number'));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('phone-field')), '0123456789');
  await t.tap(find.text('Send code'));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('otp-field')), '123456');
  await t.tap(find.text('Verify'));
  await t.pumpAndSettle();
}

final a = sum('a', title: 'Batik Workshop', cats: ['make']);
final b = sum('b', title: 'Sunrise Run', cats: ['move'], price: 0);
final c = sum('c', title: 'Board Games', cats: ['meet', 'make'], price: 1500);

void main() {
  group('View all', () {
    testWidgets('view_all_has_category_chips_with_counts_and_sections_for_all', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a, b, c]));
      expect(find.byKey(const Key('view-all')), findsOneWidget);
      expect(find.text('All 3 events'), findsOneWidget);
      expect(find.text('EVERYTHING IN KL'), findsOneWidget);
      for (final (key, label, n) in [('all', '✨ All', 3), ('make', '🎨 Make', 2), ('move', '🏃 Move', 1), ('meet', '🫶 Meet', 1), ('free', '🆓 Free', 1)]) {
        final chip = find.byKey(Key('chip-$key'));
        expect(chip, findsOneWidget, reason: key);
        expect(t.widget<Text>(find.descendant(of: chip, matching: find.byType(Text))).textSpan!.toPlainText(), '$label $n', reason: key);
      }
      // sections: one header per category, an event under every category it belongs to
      for (final h in ['🎨 Make', '🏃 Move', '🫶 Meet', '🆓 Free']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      expect(poster('a'), findsOneWidget);
      expect(poster('c'), findsNWidgets(2)); // Meet and Make
    });

    testWidgets('a category nobody has gets no chip and no section', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a]));
      expect(find.byKey(const Key('chip-move')), findsNothing);
      expect(find.text('🏃 Move'), findsNothing);
    });

    testWidgets('selecting_a_chip_shows_only_that_grid', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a, b, c]));
      await t.tap(find.byKey(const Key('chip-move')));
      await t.pumpAndSettle();
      expect(poster('b'), findsOneWidget);
      expect(poster('a'), findsNothing);
      expect(poster('c'), findsNothing);
      expect(find.text('🏃 Move'), findsNothing, reason: 'one grid, no section headers');
      await t.tap(find.byKey(const Key('chip-all')));
      await t.pumpAndSettle();
      expect(poster('a'), findsOneWidget);
    });

    testWidgets('the close button goes back', (t) async {
      final router = await pumpApp(t, location: '/explore');
      router.push('/all');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('view-all-close')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('view-all')), findsNothing);
    });

    testWidgets('an empty list says so', (t) async {
      await pumpApp(t);
      expect(find.text('Nothing right now'), findsOneWidget);
    });

    testWidgets('a poster opens its event', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a], details: {'a': detailOf(a)}));
      await t.tap(poster('a').first);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('event-screen')), findsOneWidget);
      expect(find.text('Join · RM 30'), findsOneWidget);
    });
  });

  group('posters', () {
    testWidgets('poster_tags_happening_countdown_under_2h_clock_otherwise', (t) async {
      final live = sum('l', live: true, starts: clock.subtract(const Duration(minutes: 30)));
      final soon = sum('s', starts: clock.add(const Duration(minutes: 17, seconds: 42)));
      final hour = sum('h', starts: clock.add(const Duration(hours: 1, minutes: 32, seconds: 5)));
      final tonight = sum('t', starts: DateTime.utc(2030, 1, 9, 12)); // 8 PM KL
      final later = sum('x', starts: DateTime.utc(2030, 1, 12, 1));
      await pumpApp(t, repo: FakeEvents(all: [live, soon, hour, tonight, later]));
      String tag(String id) => t.widget<Text>(find.descendant(of: poster(id), matching: find.byKey(Key('tag-$id')))).data!;
      expect(tag('l'), 'HAPPENING');
      // pumping the app already moved the test clock a little, so read the second off the screen
      final shown = RegExp(r'^⏱ in 17:(\d\d)$').firstMatch(tag('s'))!;
      final sec = int.parse(shown.group(1)!);
      expect(sec, inInclusiveRange(38, 42));
      expect(tag('h'), startsWith('⏱ in 1h 3'));
      expect(tag('t'), '🌙 8:00 PM');
      expect(tag('x'), 'SAT 9:00 AM');
      await t.pump(const Duration(seconds: 1));
      expect(tag('s'), '⏱ in 17:${(sec - 1).toString().padLeft(2, '0')}', reason: 'the countdown ticks each second');
    });

    testWidgets('a poster shows price, title and distance', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a, b]));
      expect(find.descendant(of: poster('a').first, matching: find.text('RM 30')), findsOneWidget);
      expect(find.descendant(of: poster('b').first, matching: find.text('Free')), findsOneWidget);
      expect(find.descendant(of: poster('a').first, matching: find.text('Batik Workshop')), findsOneWidget);
      expect(find.descendant(of: poster('a').first, matching: find.textContaining('1.2 km')), findsOneWidget);
    });

    testWidgets('tapping_heart_signed_out_opens_sign_in_save_then_saves_after_signing_in', (t) async {
      await pumpApp(t, signedIn: false, repo: FakeEvents(all: [a]));
      await t.tap(find.byKey(const Key('heart-off:a')).first);
      await t.pumpAndSettle();
      expect(find.text('Sign in to save'), findsOneWidget);
      expect(events.toggles, isEmpty);
      await signInWithPhone(t);
      expect(events.toggles, ['a']);
      expect(heartOn('a'), findsWidgets);
      expect(heartOff('a'), findsNothing);
    });

    testWidgets('closing the sign-in sheet saves nothing', (t) async {
      await pumpApp(t, signedIn: false, repo: FakeEvents(all: [a]));
      await t.tap(find.byKey(const Key('heart-off:a')).first);
      await t.pumpAndSettle();
      await t.tapAt(const Offset(10, 10)); // the dim area above the sheet
      await t.pumpAndSettle();
      expect(events.toggles, isEmpty);
      expect(heartOff('a'), findsWidgets);
    });

    testWidgets('double_tap_does_not_duplicate', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a], saveDelay: const Duration(milliseconds: 200)));
      final h = find.byKey(const Key('heart-off:a')).first;
      await t.tap(h);
      await t.pump(const Duration(milliseconds: 20));
      await t.tap(find.byKey(const Key('heart-off:a')).first, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 400)); // nothing animates, so let the slow save finish by hand
      expect(events.toggles, ['a'], reason: 'the second tap was ignored while the first was travelling');
      expect(events.hearts, {'a'});
      expect(heartOn('a'), findsWidgets);
    });

    testWidgets('a hearted event starts out hearted', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a, b], hearts: {'b'}));
      expect(heartOn('b'), findsWidgets);
      expect(heartOff('a'), findsWidgets);
    });
  });

  group('event pages', () {
    testWidgets('heart_state_is_shared_between_poster_hero_and_bottom_bar', (t) async {
      final repo = FakeEvents(all: [a], details: {'a': detailOf(a)});
      await pumpApp(t, repo: repo);
      await t.tap(find.byKey(const Key('heart-off:a')).first);
      await t.pumpAndSettle();
      await t.tap(poster('a').first);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('hero-heart')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('hero-heart')), matching: find.byKey(const Key('heart-on:a'))), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('bar-heart')), matching: find.byKey(const Key('heart-on:a'))), findsOneWidget);
      await t.tap(find.byKey(const Key('bar-heart')));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('hero-heart')), matching: find.byKey(const Key('heart-off:a'))), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('bar-heart')), matching: find.byKey(const Key('heart-off:a'))), findsOneWidget);
      await t.tap(find.byKey(const Key('event-back')));
      await t.pumpAndSettle();
      expect(heartOff('a'), findsWidgets, reason: 'the poster behind agrees');
      expect(heartOn('a'), findsNothing);
    });

    testWidgets('paid page shows who, when, where, the rating and Join · RM 30', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a)}));
      expect(find.byKey(const Key('event-screen')), findsOneWidget);
      expect(find.text('Batik Workshop'), findsOneWidget);
      expect(find.text('Mei Studio'), findsOneWidget);
      expect(find.text('★ 4.8 · 36 reviews'), findsOneWidget);
      expect(find.text('Join · RM 30'), findsOneWidget);
      expect(find.text('WORKSHOP · 7 SPOTS LEFT'), findsOneWidget);
      expect(find.text('Bangsar'), findsOneWidget);
      expect(find.text('1.2 km away'), findsOneWidget);
      expect(find.text('Bring a mat.'), findsOneWidget);
      expect(find.text('Sat 9:00 AM'), findsOneWidget);
      expect(find.text('2 hours'), findsOneWidget);
    });

    testWidgets('paid_event_page_shows_cancel_policy_text_per_policy', (t) async {
      for (final (policy, text) in [
        ('24h', 'Free cancellation up to 24 hours before'),
        ('48h', 'Free cancellation up to 48 hours before'),
        ('7d', 'Free cancellation up to 7 days before'),
        ('none', 'No refunds once booked'),
      ]) {
        await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a, policy: policy)}));
        expect(find.textContaining(text), findsOneWidget, reason: policy);
      }
    });

    testWidgets('a host with no reviews yet shows no rating line', (t) async {
      final d = detailOf(a);
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': EventDetail(
        summary: d.summary, hostId: 'h1', hostName: 'Mei Studio', ratingAvg: null, ratingCount: 0, description: null, venue: null,
        lat: null, lng: null, cancelPolicy: '24h', sourceUrl: null, isBookable: true, isEnded: false)}));
      expect(find.textContaining('★'), findsNothing);
      expect(find.text('New host'), findsOneWidget);
    });

    testWidgets('free_page_shows_source_card_and_opens_url', (t) async {
      final d = detailOf(b, bookable: false, policy: 'none', source: 'https://instagram.com/p/x');
      await pumpApp(t, location: '/event/b', repo: FakeEvents(details: {'b': d}));
      expect(find.text('FREE · JOIN TO SAVE YOUR SPOT'), findsOneWidget);
      expect(find.text('Join · Free'), findsOneWidget);
      expect(find.textContaining('A free community event, hosted by Mei Studio'), findsOneWidget);
      expect(find.textContaining('Source:'), findsOneWidget);
      await t.tap(find.byKey(const Key('source-card')));
      await t.pumpAndSettle();
      expect(launched, [Uri.parse('https://instagram.com/p/x')]);
    });

    testWidgets('a free page without a source link has no source card', (t) async {
      await pumpApp(t, location: '/event/b', repo: FakeEvents(details: {'b': detailOf(b, bookable: false)}));
      expect(find.byKey(const Key('source-card')), findsNothing);
    });

    testWidgets('get_directions_launches_maps_uri', (t) async {
      await pumpApp(t, location: '/event/b', repo: FakeEvents(details: {'b': detailOf(b, bookable: false)}));
      await t.tap(find.byKey(const Key('directions')));
      await t.pumpAndSettle();
      expect(launched.single.toString(), 'https://www.google.com/maps/dir/?api=1&destination=3.129%2C101.671');
    });

    testWidgets('join_signed_out_opens_sign_in_join_then_goes_to_checkout', (t) async {
      await pumpApp(t, location: '/event/a', signedIn: false, repo: FakeEvents(details: {'a': detailOf(a)}));
      await t.tap(find.byKey(const Key('join')));
      await t.pumpAndSettle();
      expect(find.text('Sign in to join'), findsOneWidget);
      await signInWithPhone(t);
      expect(find.byKey(const Key('checkout-screen')), findsOneWidget);
    });

    testWidgets('join signed in goes straight to checkout', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a)}));
      await t.tap(find.byKey(const Key('join')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('checkout-screen')), findsOneWidget);
    });

    testWidgets('message_button_requires_sign_in_chat_then_opens_thread', (t) async {
      await pumpApp(t, location: '/event/a', signedIn: false, repo: FakeEvents(details: {'a': detailOf(a)}));
      await t.tap(find.byKey(const Key('message')));
      await t.pumpAndSettle();
      expect(find.text('Sign in to chat'), findsOneWidget);
      await signInWithPhone(t);
      expect(events.threads, [('h1', 'a')]);
      expect(find.byKey(const Key('thread-screen')), findsOneWidget);
    });

    testWidgets('the host row opens the host profile', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a)}));
      await t.tap(find.byKey(const Key('host-row')));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const Key('screen-title'))).data, 'Host profile');
    });

    testWidgets('an ended event cannot be joined', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a, ended: true)}));
      expect(find.text('This event has ended'), findsOneWidget);
      expect(find.byKey(const Key('join')), findsNothing);
    });

    testWidgets('an event that is not there says so', (t) async {
      await pumpApp(t, location: '/event/nope');
      expect(find.text("This event isn't available"), findsOneWidget);
    });

    testWidgets('a failed load says so', (t) async {
      await pumpApp(t, location: '/event/a', repo: _Failing());
      expect(find.textContaining('Could not load'), findsOneWidget);
    });
  });

  group('Saved', () {
    testWidgets('saved_tab_lists_hearted_events_and_greys_ended_with_Ended_tag', (t) async {
      final upcoming = sum('a', title: 'Batik Workshop');
      final past = sum('p', title: 'Old Concert', starts: DateTime.utc(2029, 12, 1, 12));
      await pumpApp(t, location: '/saved', repo: FakeEvents(hearts: {'a', 'p'}, savedList: [past, upcoming]));
      expect(find.text('Batik Workshop'), findsOneWidget);
      expect(find.text('Old Concert'), findsOneWidget);
      expect(find.descendant(of: poster('p'), matching: find.text('Ended')), findsOneWidget);
      expect(find.descendant(of: poster('a'), matching: find.text('Ended')), findsNothing);
      expect(t.widget<Opacity>(find.byKey(const Key('dim:p'))).opacity, lessThan(1));
      expect(t.widget<Opacity>(find.byKey(const Key('dim:a'))).opacity, 1);
    });

    testWidgets('an ended saved event can still be un-hearted', (t) async {
      final past = sum('p', starts: DateTime.utc(2029, 12, 1, 12));
      await pumpApp(t, location: '/saved', repo: FakeEvents(hearts: {'p'}, savedList: [past]));
      await t.tap(find.byKey(const Key('heart-on:p')));
      await t.pumpAndSettle();
      expect(events.toggles, ['p']);
    });

    testWidgets('nothing hearted yet says how to start', (t) async {
      await pumpApp(t, location: '/saved');
      expect(find.text('Nothing saved yet'), findsOneWidget);
    });
  });
}

class _Failing extends FakeEvents {
  @override
  Future<EventDetail?> detail(String id, LatLng at) async => throw Exception('offline');
}
