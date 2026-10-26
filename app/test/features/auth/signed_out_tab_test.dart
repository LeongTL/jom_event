import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/app.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/features/home/domain/home_feed.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_events.dart';

Future<GoRouter> pumpApp(WidgetTester t, FakeAuthRepository repo, {String location = '/explore'}) async {
  final router = createRouter(initialLocation: location);
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(repo),
      eventRepositoryProvider.overrideWithValue(FakeEvents()),
      bookingRepositoryProvider.overrideWithValue(FakeBookings()),
      homeFeedProvider.overrideWith((ref, q) async => HomeFeed(tab: q.tab, top9: const [], stats: const HeroStats(total: 0, live: 0, free: 0, closestKm: null))),
      deviceLocationProvider.overrideWithValue(() async => null),
      bellCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
  return router;
}

Future<void> openTab(WidgetTester t, String label) async {
  await t.tap(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text(label)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('signed_out_saved_bookings_chat_profile_show_sign_in_prompt_with_the_two_buttons', (t) async {
    await pumpApp(t, FakeAuthRepository());
    const prompts = {
      'Saved': 'Sign in to see your saved events',
      'Tickets': 'Sign in to see your tickets',
      'Chat': 'Sign in to see your chats',
      'Profile': 'Sign in to see your profile',
    };
    for (final e in prompts.entries) {
      await openTab(t, e.key);
      expect(find.text(e.value), findsOneWidget, reason: e.key);
      expect(find.text('Continue with Google'), findsOneWidget, reason: e.key);
      expect(find.text('Continue with phone number'), findsOneWidget, reason: e.key);
      expect(find.byKey(const Key('screen-title')), findsNothing, reason: '${e.key} must not show its screen while signed out');
    }
  });

  testWidgets('browsing_explore_and_event_pages_needs_no_account', (t) async {
    final repo = FakeAuthRepository();
    await pumpApp(t, repo);
    expect(find.text('Explore'), findsWidgets);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);

    await pumpApp(t, repo, location: '/event/e1');
    expect(find.byKey(const Key('event-screen')), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('the phone button on a tab opens the sign-in; once signed in the tab shows its screen', (t) async {
    final repo = FakeAuthRepository(newUserHasName: true);
    await pumpApp(t, repo);
    await openTab(t, 'Saved');
    await t.tap(find.text('Continue with phone number'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('phone-field')), '0123456789');
    await t.tap(find.text('Send code'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('otp-field')), '123456');
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('saved-screen')), findsOneWidget);
    expect(find.text('Sign in to see your saved events'), findsNothing);
  });

  testWidgets('the Google button on a tab signs in with Google', (t) async {
    final repo = FakeAuthRepository();
    await pumpApp(t, repo);
    await openTab(t, 'Tickets');
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(repo.googleCalls, 1);
    expect(find.byKey(const Key('tickets-screen')), findsOneWidget);
  });

  testWidgets('a failed Google sign-in on a tab says so and keeps the prompt', (t) async {
    final repo = FakeAuthRepository()..googleError = const GoogleNotConfigured();
    await pumpApp(t, repo);
    await openTab(t, 'Chat');
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text("Google sign-in isn't set up on this device yet. Use your phone number instead."), findsOneWidget);
    expect(find.text('Sign in to see your chats'), findsOneWidget);
  });

  testWidgets('signed in, Profile shows who you are and lets you sign out', (t) async {
    final repo = FakeAuthRepository(initial: fakeSession(name: 'Mei Tan'));
    await pumpApp(t, repo);
    await openTab(t, 'Profile');
    expect(find.text('Mei Tan'), findsOneWidget);
    expect(find.text('+60 12 345 6789'), findsOneWidget);
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    expect(repo.signOutCalls, 1);
    expect(find.text('Sign in to see your profile'), findsOneWidget);
  });

  testWidgets('while the session is still loading, nothing flashes the sign-in prompt', (t) async {
    // a repository whose first answer is slow
    final slow = _SlowAuth();
    final router = createRouter(initialLocation: '/saved');
    await t.pumpWidget(ProviderScope(
      overrides: [routerProvider.overrideWithValue(router), authRepositoryProvider.overrideWithValue(slow), eventRepositoryProvider.overrideWithValue(FakeEvents()), deviceLocationProvider.overrideWithValue(() async => null)],
      child: const JomApp(),
    ));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Sign in to see your saved events'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('saved-screen')), findsOneWidget); // signed in after all
  });
}

class _SlowAuth extends FakeAuthRepository {
  _SlowAuth() : super(initial: fakeSession(name: 'Mei'));
  @override
  Stream<Session?> get session async* {
    await Future<void>.delayed(const Duration(seconds: 1));
    yield* super.session;
  }
}
