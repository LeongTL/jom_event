import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/app.dart';
import 'package:jom/core/clock.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/notifications/data/notification_repository.dart';
import 'package:jom/features/reviews/data/review_repository.dart';
import 'package:jom/shared/models/event_summary.dart';

import 'fake_auth.dart';
import 'fake_bookings.dart';
import 'fake_chat.dart';
import 'fake_events.dart';
import 'fake_notifications.dart';
import 'fake_reviews.dart';

Finder key(String k) => find.byKey(Key(k));

// the top of the stack: a pushed screen does not move the router's own location
String where(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

/// The whole app on fakes, at [location]. Wider than a phone on purpose: the test font's letters are so wide that
/// tab names would wrap.
Future<GoRouter> pumpApp(
  WidgetTester t, {
  required String location,
  FakeAuthRepository? auth,
  FakeReviews? reviews,
  FakeBookings? bookings,
  FakeEvents? events,
}) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = createRouter(initialLocation: location);
  final start = t.binding.clock.now();
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository(initial: fakeSession(name: 'Mei Tan'))),
      reviewRepositoryProvider.overrideWithValue(reviews ?? FakeReviews()),
      notificationRepositoryProvider.overrideWithValue(FakeNotifications()),
      eventRepositoryProvider.overrideWithValue(events ?? FakeEvents()),
      chatRepositoryProvider.overrideWithValue(FakeChat()),
      bookingRepositoryProvider.overrideWithValue(bookings ?? FakeBookings()),
      nowProvider.overrideWithValue(() => clock.add(t.binding.clock.now().difference(start))),
      weekendProvider.overrideWith((ref, a) async => <EventSummary>[]),
      nearYouProvider.overrideWith((ref, q) async => <EventSummary>[]),
      deviceLocationProvider.overrideWithValue(() async => null),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
  return router;
}
