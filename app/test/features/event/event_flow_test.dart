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
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/shared/models/event_summary.dart';
import 'package:jom/shared/widgets/category_art.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_chat.dart';
import '../../helpers/fake_events.dart';

late FakeEvents events;
late FakeAuthRepository auth;
final launched = <Uri>[];

Future<GoRouter> pumpApp(WidgetTester t, {String location = '/explore/all', bool signedIn = true, FakeEvents? repo}) async {
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
      weekendProvider.overrideWith((ref, a) async => events.all),
      nearYouProvider.overrideWith((ref, q) async => events.all),
      deviceLocationProvider.overrideWithValue(() async => null),
      bellCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
  return router;
}

Finder poster(String id) => find.byKey(Key('poster-$id'));
Finder card(String id) => find.byKey(Key('event-card-$id'));
Finder row(String id) => find.byKey(Key('event-row-$id'));
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
    testWidgets('view_all_has_category_chips_the_count_and_nearest_first_rows', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a, b, c]));
      expect(find.byKey(const Key('view-all')), findsOneWidget);
      expect(find.text('All events'), findsOneWidget);
      expect(find.text('3 events · nearest first'), findsOneWidget);
      for (final key in ['all', 'make', 'move', 'meet', 'free']) {
        expect(find.byKey(Key('chip-$key')), findsOneWidget, reason: key);
      }
      for (final id in ['a', 'b', 'c']) {
        expect(row(id), findsOneWidget, reason: id);
      }
    });

    testWidgets('selecting_a_chip_shows_only_that_category_and_All_brings_everything_back', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a, b, c]));
      await t.tap(find.byKey(const Key('chip-move')));
      await t.pumpAndSettle();
      expect(row('b'), findsOneWidget);
      expect(row('a'), findsNothing);
      expect(find.text('1 event · nearest first'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip-free')));
      await t.pumpAndSettle();
      expect(row('b'), findsOneWidget, reason: 'free means price 0');
      await t.tap(find.byKey(const Key('chip-make')));
      await t.pumpAndSettle();
      expect(row('a'), findsOneWidget);
      expect(row('c'), findsOneWidget, reason: 'c is meet and make');
      await t.tap(find.byKey(const Key('chip-all')));
      await t.pumpAndSettle();
      expect(row('b'), findsOneWidget);
    });

    testWidgets('a_section_link_opens_View_all_on_its_category', (t) async {
      await pumpApp(t, location: '/explore/all?category=move', repo: FakeEvents(all: [a, b, c]));
      expect(row('b'), findsOneWidget);
      expect(row('a'), findsNothing);
    });

    testWidgets('the close button goes back', (t) async {
      final router = await pumpApp(t, location: '/explore');
      router.push('/explore/all');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('view-all-close')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('view-all')), findsNothing);
    });

    testWidgets('an empty list says so', (t) async {
      await pumpApp(t);
      expect(find.text('Nothing right now'), findsOneWidget);
    });

    testWidgets('a row opens its event', (t) async {
      await pumpApp(t, repo: FakeEvents(all: [a], details: {'a': detailOf(a)}));
      await t.tap(row('a'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('event-screen')), findsOneWidget);
      expect(find.text('Book a spot'), findsOneWidget);
    });

    testWidgets('a long title ends with an ellipsis instead of overflowing', (t) async {
      final long = sum('long', title: 'A' * 120);
      await pumpApp(t, repo: FakeEvents(all: [long]));
      expect(t.takeException(), isNull);
      expect(t.widget<Text>(find.descendant(of: row('long'), matching: find.text('A' * 120))).overflow, TextOverflow.ellipsis);
    });
  });

  group('event cards', () {
    testWidgets('badge_says_Happening_now_or_how_soon_or_which_day', (t) async {
      final live = sum('l', live: true, starts: clock.subtract(const Duration(minutes: 30)));
      final soon = sum('s', starts: clock.add(const Duration(minutes: 17, seconds: 42)));
      final hour = sum('h', starts: clock.add(const Duration(hours: 1, minutes: 32, seconds: 5)));
      final later = sum('x', starts: DateTime.utc(2030, 1, 12, 1));
      await pumpApp(t, location: '/explore', repo: FakeEvents(all: [live, soon, hour, later]));
      String tag(String id) => t.widget<Text>(find.descendant(of: card(id), matching: find.descendant(of: find.byKey(const Key('event-badge')), matching: find.byType(Text)))).data!;
      expect(tag('l'), 'Happening now');
      expect(tag('s'), 'in 17 min');
      expect(tag('h'), 'in 92 min');
      expect(tag('x'), 'Sat 12 Jan');
    });

    testWidgets('a card shows price, title, host with a tick only when verified, and spots or going', (t) async {
      final verified = EventSummary.fromJson({
        'event_id': 'v', 'title': 'Verified Fun', 'starts_at': '2030-01-12T01:00:00Z', 'ends_at': '2030-01-12T03:00:00Z', 'price_sen': 0,
        'area': 'Bangsar', 'is_live': false, 'spots_left': 7, 'score': 0, 'host_name': 'Aina Crew', 'host_verified': true, 'going': 5,
      });
      final plain = EventSummary.fromJson({
        'event_id': 'p', 'title': 'Plain Fun', 'starts_at': '2030-01-12T01:00:00Z', 'ends_at': '2030-01-12T03:00:00Z', 'price_sen': 3000,
        'area': 'Bangsar', 'is_live': false, 'spots_left': 100, 'score': 0, 'host_name': 'Bob Crew', 'host_verified': false, 'going': 5,
      });
      await pumpApp(t, location: '/explore', repo: FakeEvents(all: [verified, plain]));
      expect(find.descendant(of: card('v'), matching: find.textContaining('Free', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: card('v'), matching: find.textContaining('7 left', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: card('p'), matching: find.textContaining('RM 30 · 5 going', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: card('v'), matching: find.byKey(const Key('verified-badge'))), findsOneWidget);
      expect(find.descendant(of: card('p'), matching: find.byKey(const Key('verified-badge'))), findsNothing);
      expect(find.descendant(of: card('v'), matching: find.byKey(const Key('people-stack'))), findsOneWidget);
    });

    testWidgets('tapping_heart_signed_out_opens_sign_in_save_then_saves_after_signing_in', (t) async {
      await pumpApp(t, location: '/explore', signedIn: false, repo: FakeEvents(all: [a]));
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
      await pumpApp(t, location: '/explore', signedIn: false, repo: FakeEvents(all: [a]));
      await t.tap(find.byKey(const Key('heart-off:a')).first);
      await t.pumpAndSettle();
      await t.tapAt(const Offset(10, 10)); // the dim area above the sheet
      await t.pumpAndSettle();
      expect(events.toggles, isEmpty);
      expect(heartOff('a'), findsWidgets);
    });

    testWidgets('double_tap_does_not_duplicate', (t) async {
      await pumpApp(t, location: '/explore', repo: FakeEvents(all: [a], saveDelay: const Duration(milliseconds: 200)));
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
      await pumpApp(t, location: '/explore', repo: FakeEvents(all: [a, b], hearts: {'b'}));
      expect(heartOn('b'), findsWidgets);
      expect(heartOff('a'), findsWidgets);
    });
  });

  group('event pages', () {
    testWidgets('heart_state_is_shared_between_card_and_hero', (t) async {
      final repo = FakeEvents(all: [a], details: {'a': detailOf(a)});
      await pumpApp(t, location: '/explore', repo: repo);
      await t.tap(find.byKey(const Key('heart-off:a')).first);
      await t.pumpAndSettle();
      await t.tap(card('a'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('hero-heart')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('hero-heart')), matching: find.byKey(const Key('heart-on:a'))), findsOneWidget);
      await t.tap(find.byKey(const Key('heart-on:a')));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('hero-heart')), matching: find.byKey(const Key('heart-off:a'))), findsOneWidget);
      await t.tap(find.byKey(const Key('event-back')));
      await t.pumpAndSettle();
      expect(heartOff('a'), findsWidgets, reason: 'the card behind agrees');
      expect(heartOn('a'), findsNothing);
    });

    testWidgets('detail_shows_when_where_going_and_spots_left', (t) async {
      final going = sum('a', title: 'Batik Workshop', going: 5);
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(going)}));
      expect(find.byKey(const Key('event-screen')), findsOneWidget);
      expect(find.text('Batik Workshop'), findsOneWidget);
      expect(find.text('Sat 9:00 AM'), findsOneWidget);
      expect(find.text('Bangsar · 1.2 km'), findsOneWidget);
      expect(find.text('5 going'), findsOneWidget);
      expect(find.text('7 spots left'), findsOneWidget);
    });

    testWidgets('one_layout_serves_free_and_paid_with_the_right_button_text', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a)}));
      expect(find.text('Book a spot'), findsOneWidget);
      expect(find.text('Per person'), findsOneWidget);
      expect(find.text('RM 30'), findsOneWidget);
      await pumpApp(t, location: '/event/b', repo: FakeEvents(details: {'b': detailOf(b, bookable: false, policy: 'none')}));
      expect(find.text('Join for free'), findsOneWidget);
      expect(find.text('Entry'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      for (final key in ['join', 'host-row', 'going-card', 'policy-card']) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: '$key is on the free page too');
      }
    });

    testWidgets('policy_card_text_per_policy', (t) async {
      for (final (policy, text) in [
        ('24h', 'Full refund up to 24 hours before it starts'),
        ('48h', 'Full refund up to 48 hours before it starts'),
        ('7d', 'Full refund up to 7 days before it starts'),
        ('none', 'No refunds once booked'),
      ]) {
        await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a, policy: policy)}));
        expect(find.descendant(of: find.byKey(const Key('policy-card')), matching: find.text(text)), findsOneWidget, reason: policy);
      }
      await pumpApp(t, location: '/event/b', repo: FakeEvents(details: {'b': detailOf(b, bookable: false, policy: 'none')}));
      expect(find.descendant(of: find.byKey(const Key('policy-card')), matching: find.text('Free event')), findsOneWidget);
    });

    testWidgets('going_card_shows_a_count_and_no_names_or_initials', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(sum('a', title: 'Batik Workshop', going: 5))}));
      final card = find.byKey(const Key('going-card'));
      expect(find.descendant(of: card, matching: find.text('5 going')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byKey(const Key('people-stack'))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('M')), findsNothing, reason: 'no initials of the host or anyone');
    });

    testWidgets('host_card_shows_rating_reviews_events_hosted_and_message_button', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a)}));
      final card = find.byKey(const Key('host-row'));
      expect(find.descendant(of: card, matching: find.text('Mei Studio')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('4.8 · 36 reviews · 38 events hosted')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Message')), findsOneWidget);
    });

    testWidgets('hero_uses_the_poster_when_present_else_the_category_art', (t) async {
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(a)}));
      expect(find.descendant(of: find.byKey(const Key('event-hero')), matching: find.byType(CategoryArt)), findsOneWidget);
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': detailOf(sum('a', poster: 'https://x.test/p.jpg'))}));
      expect(find.descendant(of: find.byKey(const Key('event-hero')), matching: find.byType(Image)), findsOneWidget);
    });

    testWidgets('a host with no reviews yet shows no rating line', (t) async {
      final d = detailOf(a);
      await pumpApp(t, location: '/event/a', repo: FakeEvents(details: {'a': EventDetail(
        summary: d.summary, hostId: 'h1', hostName: 'Mei Studio', ratingAvg: null, ratingCount: 0, description: null, venue: null,
        lat: null, lng: null, cancelPolicy: '24h', sourceUrl: null, isBookable: true, isEnded: false, hostEventCount: 1)}));
      expect(find.textContaining('★'), findsNothing);
      expect(find.text('New host · 1 event hosted'), findsOneWidget);
    });

    testWidgets('free_page_shows_source_card_and_opens_url', (t) async {
      final d = detailOf(b, bookable: false, policy: 'none', source: 'https://instagram.com/p/x');
      await pumpApp(t, location: '/event/b', repo: FakeEvents(details: {'b': d}));
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
      expect(find.byKey(const Key('host-public-screen')), findsOneWidget);
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
    testWidgets('saved_uses_event_rows_and_the_empty_text_is_Nothing_saved_yet', (t) async {
      final upcoming = sum('a', title: 'Batik Workshop');
      final past = sum('p', title: 'Old Concert', starts: DateTime.utc(2029, 12, 1, 12));
      await pumpApp(t, location: '/saved', repo: FakeEvents(hearts: {'a', 'p'}, savedList: [past, upcoming]));
      expect(find.text('Batik Workshop'), findsOneWidget);
      expect(find.text('Old Concert'), findsOneWidget);
      expect(row('a'), findsOneWidget);
      expect(row('p'), findsOneWidget);
      expect(find.descendant(of: row('p'), matching: find.text('Ended')), findsOneWidget);
      expect(find.descendant(of: row('a'), matching: find.text('Ended')), findsNothing);
      double dim(String id) => t.widget<Opacity>(find.descendant(of: row(id), matching: find.byType(Opacity))).opacity;
      expect(dim('p'), lessThan(1));
      expect(dim('a'), 1);
      await t.tap(row('a'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('event-screen')), findsOneWidget, reason: 'a row opens its event');
    });

    testWidgets('an ended saved event can still be un-hearted', (t) async {
      final past = sum('p', starts: DateTime.utc(2029, 12, 1, 12));
      await pumpApp(t, location: '/saved', repo: FakeEvents(hearts: {'p'}, savedList: [past]));
      await t.tap(find.descendant(of: row('p'), matching: find.byKey(const Key('heart-on:p'))));
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
