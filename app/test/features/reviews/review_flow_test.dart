import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/reviews/domain/review.dart';

import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_events.dart';
import '../../helpers/fake_reviews.dart';
import '../../helpers/pump_app.dart';

final _past = [bk('b9', status: 'attended'), bk('b8', status: 'cancelled')];
final _events = FakeEvents(
  details: {'e1': detailOf(sum('e1', title: 'Batik Workshop'))},
);

HostPublic host({List<HostReview> reviews = const []}) => HostPublic(
  name: 'Mei Studio',
  area: 'Bangsar',
  since: DateTime.utc(2026, 3),
  verified: true,
  ratingAvg: 4.8,
  ratingCount: 36,
  guests: 120,
  upcoming: [
    sum('e2', title: 'Sunset Pilates'),
    sum('e3', title: 'Clay Night'),
  ],
  reviews: reviews,
);

void main() {
  group('writing a review', () {
    testWidgets(
      'review_has_five_tappable_stars_four_tags_and_verified_attendee_label',
      (t) async {
        await pumpApp(
          t,
          location: '/review/b9',
          bookings: FakeBookings(past: _past),
          events: _events,
        );
        expect(find.text('Batik Workshop'), findsOneWidget);
        for (var i = 1; i <= 5; i++) {
          expect(key('star-$i'), findsOneWidget);
        }
        for (final tag in [
          'Friendly host',
          'Good value',
          'Beginner-friendly',
          'Clean venue',
        ]) {
          expect(find.text(tag), findsOneWidget);
        }
        expect(find.text('✓ Verified attendee'), findsOneWidget);
        await t.tap(key('star-4'));
        await t.pump();
        expect(
          find.byIcon(Icons.star),
          findsNWidgets(4),
        ); // four filled, one outlined
      },
    );

    testWidgets('submit_requires_at_least_one_star_and_calls_repository_once', (
      t,
    ) async {
      final reviews = FakeReviews(
        submitDelay: const Duration(milliseconds: 50),
      );
      await pumpApp(
        t,
        location: '/review/b9',
        reviews: reviews,
        bookings: FakeBookings(past: _past),
        events: _events,
      );
      await t.tap(key('submit-review'));
      await t.pump();
      expect(reviews.submitted, isEmpty);
      expect(find.text('Tap a star to rate'), findsOneWidget);

      await t.tap(key('star-5'));
      await t.tap(key('tag-good_value'));
      await t.enterText(key('review-body'), 'Lovely class');
      await t.pump();
      await t.tap(key('submit-review'));
      await t.tap(
        key('submit-review'),
      ); // a second tap while sending does nothing
      await t.pumpAndSettle();
      expect(reviews.submitted.length, 1);
      final (id, stars, tags, body) = reviews.submitted.single;
      expect(
        [id, stars, tags.join(), body],
        ['b9', 5, 'good_value', 'Lovely class'],
      );
      expect(find.text('Thanks for your review'), findsOneWidget);
    });

    testWidgets('a_refusal_from_the_server_is_shown_in_words', (t) async {
      final reviews = FakeReviews(
        submitError: const ReviewError('already_reviewed'),
      );
      await pumpApp(
        t,
        location: '/review/b9',
        reviews: reviews,
        bookings: FakeBookings(past: _past),
        events: _events,
      );
      await t.tap(key('star-3'));
      await t.tap(key('submit-review'));
      await t.pumpAndSettle();
      expect(find.text('You already reviewed this event.'), findsOneWidget);
    });

    testWidgets('only_attended_booking_opens_review', (t) async {
      final router = await pumpApp(
        t,
        location: '/tickets',
        bookings: FakeBookings(past: _past),
        events: _events,
      );
      await t.tap(find.text('Previous'));
      await t.pumpAndSettle();
      await t.tap(key('booking-b8')); // cancelled
      await t.pumpAndSettle();
      expect(where(router), '/tickets');
      await t.tap(key('booking-b9')); // attended
      await t.pumpAndSettle();
      expect(where(router), '/review/b9');
      // and a booking that was not attended shows no form when its link is opened by hand
      router.go('/review/b8');
      await t.pumpAndSettle();
      expect(
        find.text('Only events you attended can be reviewed.'),
        findsOneWidget,
      );
      expect(key('submit-review'), findsNothing);
    });
  });

  group('my reviews', () {
    testWidgets('my_reviews_lists_stars_tags_text_and_the_event_name', (
      t,
    ) async {
      final mine = [
        Review(
          id: 'r1',
          bookingId: 'b9',
          stars: 4,
          tags: const ['friendly_host'],
          body: 'Kind teacher',
          createdAt: DateTime.utc(2030, 1, 5),
        ),
      ];
      await pumpApp(
        t,
        location: '/my-reviews',
        reviews: FakeReviews(mineList: mine),
        bookings: FakeBookings(past: _past),
        events: _events,
      );
      expect(find.text('Batik Workshop'), findsOneWidget);
      expect(find.text('Kind teacher'), findsOneWidget);
      expect(find.text('Friendly host'), findsOneWidget);
    });

    testWidgets('my_reviews_empty_says_so', (t) async {
      await pumpApp(t, location: '/my-reviews');
      expect(
        find.text('You have not written any reviews yet.'),
        findsOneWidget,
      );
    });
  });

  group('host public page', () {
    testWidgets(
      'host_public_shows_hero_avatar_tick_stats_coming_up_carousel_and_what_people_said',
      (t) async {
        final r = [
          HostReview(
            firstName: 'Nadia',
            stars: 5,
            body: 'Small group, kind teacher',
          ),
        ];
        await pumpApp(
          t,
          location: '/host/h1',
          reviews: FakeReviews(hosts: {'h1': host(reviews: r)}),
        );
        expect(key('host-hero'), findsOneWidget);
        expect(key('host-avatar'), findsOneWidget);
        expect(
          find.descendant(
            of: key('host-name'),
            matching: find.text('Mei Studio'),
          ),
          findsOneWidget,
        );
        expect(key('verified-badge'), findsOneWidget);
        expect(
          find.text('Bangsar · hosting since 2026 · Verified host'),
          findsOneWidget,
        );
        expect(
          find.descendant(of: key('stat-rating'), matching: find.text('4.8')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: key('stat-reviews'), matching: find.text('36')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: key('stat-guests'), matching: find.text('120')),
          findsOneWidget,
        );
        expect(find.text('Coming up'), findsOneWidget);
        expect(key('event-card-e2'), findsOneWidget);
        expect(key('event-card-e3'), findsOneWidget);
        expect(find.text('What people said'), findsOneWidget);
        expect(find.text('Small group, kind teacher'), findsOneWidget);
        expect(find.text('Nadia'), findsOneWidget);
      },
    );

    testWidgets(
      'a_new_host_shows_new_instead_of_a_rating_and_hides_empty_sections',
      (t) async {
        final h = HostPublic(
          name: 'Newbie',
          since: DateTime.utc(2030),
          verified: false,
          ratingCount: 0,
          guests: 0,
          upcoming: const [],
          reviews: const [],
        );
        await pumpApp(
          t,
          location: '/host/h2',
          reviews: FakeReviews(hosts: {'h2': h}),
        );
        expect(
          find.descendant(of: key('stat-rating'), matching: find.text('New')),
          findsOneWidget,
        );
        expect(key('verified-badge'), findsNothing);
        expect(find.text('Coming up'), findsNothing);
        expect(find.text('What people said'), findsNothing);
      },
    );

    testWidgets('an_unknown_host_says_so', (t) async {
      await pumpApp(t, location: '/host/nobody');
      expect(find.text('This host page is not available.'), findsOneWidget);
    });
  });
}
