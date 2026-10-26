import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/app.dart';
import 'package:jom/core/clock.dart';
import 'package:jom/core/launcher.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/booking/data/calendar.dart';
import 'package:jom/features/booking/data/payment_gateway_client.dart';
import 'package:jom/features/booking/domain/booking.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/features/home/domain/home_feed.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_events.dart';

late FakeBookings bookings;
late FakeGateway gateway;
final launched = <Uri>[];
final calendarAdds = <String>[];

final paid = sum('e1', title: 'Batik Workshop', price: 3000);
final free = sum('e2', title: 'Sunrise Run', price: 0, cats: ['move']);

Future<void> pumpApp(
  WidgetTester t, {
  required String location,
  int priceSen = 3000,
  Object? createError,
  List<Booking> upcoming = const [],
  List<Booking> past = const [],
  String policy = '48h',
  void Function(FakeBookings)? setup,
}) async {
  // wider than a phone on purpose: the test font's letters are so wide that tab names would wrap
  t.view.physicalSize = const Size(800, 1700);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final start = t.binding.clock.now();
  DateTime now() => clock.add(t.binding.clock.now().difference(start)); // the test's clock starts at 14:00 KL
  bookings = FakeBookings(now: now, priceSen: priceSen, createError: createError, upcoming: upcoming, past: past);
  setup?.call(bookings);
  gateway = FakeGateway();
  launched.clear();
  calendarAdds.clear();
  final router = createRouter(initialLocation: location);
  await t.pumpWidget(ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(initial: fakeSession(name: 'Mei'))),
      eventRepositoryProvider.overrideWithValue(FakeEvents(details: {
        'e1': detailOf(paid, policy: policy),
        'e2': detailOf(free, bookable: false, policy: 'none'),
      })),
      bookingRepositoryProvider.overrideWithValue(bookings),
      paymentGatewayClientProvider.overrideWithValue(gateway),
      nowProvider.overrideWithValue(now),
      launchUrlProvider.overrideWithValue((u) async {
        launched.add(u);
        return true;
      }),
      addToCalendarProvider.overrideWithValue((d) async {
        calendarAdds.add(d.summary.title);
        return true;
      }),
      homeFeedProvider.overrideWith((ref, q) async => HomeFeed(tab: q.tab, top9: const [], stats: const HeroStats(total: 0, live: 0, free: 0, closestKm: null))),
      deviceLocationProvider.overrideWithValue(() async => null),
      bellCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: const JomApp(),
  ));
  await t.pumpAndSettle();
}

Finder key(String k) => find.byKey(Key(k));
/// The Processing screen spins forever, so pumpAndSettle never finishes there: let a moment pass instead.
Future<void> moment(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

String textOf(WidgetTester t, String k) => t.widget<Text>(key(k)).data!;

void main() {
  group('checkout', () {
    testWidgets('paid_checkout_shows_hold_countdown_and_free_checkout_does_not', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      expect(key('checkout-screen'), findsOneWidget);
      expect(bookings.created, [('e1', 1, 'Mei', '60123456789')], reason: 'opening a paid checkout holds the seat');
      expect(find.textContaining('Spot held for 14:5'), findsOneWidget); // 15:00 minus the second or so the app took to settle
      await t.pump(const Duration(seconds: 3));
      expect(find.textContaining('Spot held for 14:5'), findsOneWidget);
      await t.pump(const Duration(seconds: 60));
      expect(find.textContaining('Spot held for 13:'), findsOneWidget, reason: 'it counts down');

      await pumpApp(t, location: '/event/e2/checkout', priceSen: 0);
      expect(key('hold-countdown'), findsNothing);
      expect(bookings.created, isEmpty, reason: 'a free event is booked only when you confirm');
    });

    testWidgets('people_stepper_stops_at_1_and_2', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      expect(textOf(t, 'people-count'), '1');
      await t.tap(key('people-minus'));
      await t.pumpAndSettle();
      expect(textOf(t, 'people-count'), '1');
      expect(bookings.created.length, 1, reason: 'nothing changed, so nothing is re-held');
      await t.tap(key('people-plus'));
      await t.pumpAndSettle();
      expect(textOf(t, 'people-count'), '2');
      await t.tap(key('people-plus'));
      await t.pumpAndSettle();
      expect(textOf(t, 'people-count'), '2');
      expect([for (final c in bookings.created) c.$2], [1, 2], reason: 'the hold is remade for two');
      expect(bookings.cancelled, ['b1'], reason: 'the old hold for one is released');
    });

    testWidgets('checkout_total_shows_Free_or_RM_total', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      expect(textOf(t, 'total'), 'RM 30');
      await t.tap(key('people-plus'));
      await t.pumpAndSettle();
      expect(textOf(t, 'total'), 'RM 60');
      expect(find.text('Pay RM 60'), findsOneWidget);
      await pumpApp(t, location: '/event/e2/checkout', priceSen: 0);
      expect(textOf(t, 'total'), 'Free');
      expect(find.text('Confirm my spot'), findsOneWidget);
    });

    testWidgets('checkout shows the contact, the policy and who accepts it', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      expect(find.text('Mei'), findsOneWidget);
      expect(find.text('+60 12 345 6789'), findsOneWidget);
      expect(find.text('Up to 2 per booking'), findsOneWidget);
      expect(find.textContaining('Free cancellation up to 48 hours before. Paying means you accept the host'), findsOneWidget);
      await pumpApp(t, location: '/event/e2/checkout', priceSen: 0);
      expect(find.textContaining('No refunds once booked. Joining means you accept the host'), findsOneWidget);
    });

    testWidgets('free_confirm_my_spot_creates_confirmed_booking_and_opens_ticket', (t) async {
      await pumpApp(t, location: '/event/e2/checkout', priceSen: 0);
      await t.tap(key('confirm'));
      await t.pumpAndSettle();
      expect(bookings.created, [('e2', 1, 'Mei', '60123456789')]);
      expect(key('ticket-screen'), findsOneWidget);
      expect(find.text("You're in!"), findsOneWidget);
    });

    testWidgets('sold_out_error_shows_friendly_message', (t) async {
      await pumpApp(t, location: '/event/e2/checkout', priceSen: 0, createError: BookingError('sold_out'));
      await t.tap(key('confirm'));
      await t.pumpAndSettle();
      expect(find.text('Sorry, that just sold out.'), findsOneWidget);
      expect(key('ticket-screen'), findsNothing);
    });

    testWidgets('a paid checkout that cannot hold the seat says why', (t) async {
      await pumpApp(t, location: '/event/e1/checkout', createError: BookingError('sold_out'));
      expect(find.text('Sorry, that just sold out.'), findsOneWidget);
      expect(key('pay'), findsNothing);
    });
  });

  group('payment', () {
    testWidgets('paid_pay_goes_to_gateway_then_processing_until_stream_confirms', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      expect(key('gateway-screen'), findsOneWidget);
      expect(bookings.payments, ['b1']);
      expect(find.textContaining('RM30.00'), findsWidgets);
      await t.tap(key('gateway-pay'));
      await moment(t);
      expect(gateway.calls.length, 1);
      expect(key('processing-screen'), findsOneWidget, reason: 'the webhook has not answered yet');
      expect(find.textContaining('Confirming your payment'), findsOneWidget);
      bookings.setStatus('b1', 'confirmed');
      await t.pumpAndSettle();
      expect(key('ticket-screen'), findsOneWidget);
    });

    testWidgets('gateway_lists_methods_and_pay_calls_client_once_on_double_tap', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      for (final m in ['Online banking (FPX)', 'Credit / debit card', 'E-wallet', 'DuitNow QR']) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      expect(find.textContaining('Session expires in'), findsOneWidget);
      await t.tap(key('method-2'));
      await t.pump();
      gateway.delay = const Duration(milliseconds: 300);
      await t.tap(key('gateway-pay'));
      await t.pump(const Duration(milliseconds: 20));
      await t.tap(key('gateway-pay'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 500));
      await moment(t);
      expect(gateway.calls.length, 1);
      expect(gateway.calls.single.$2, 'E-wallet', reason: 'the chosen method is what is paid with');
    });

    testWidgets('the mock gateway can be told to fail or answer slowly', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      await t.tap(key('sim-failed'));
      await t.pump();
      await t.tap(key('gateway-pay'));
      await moment(t);
      expect(gateway.calls.single.$3, 'failed');
    });

    testWidgets('without a choice the mock decides for itself', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      await t.tap(key('gateway-pay'));
      await moment(t);
      expect(gateway.calls.single.$3, isNull);
    });

    testWidgets('failed_screen_try_again_reuses_hold_and_give_up_releases_and_goes_home', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      gateway.onPay = () => bookings.setStatus('b1', 'payment_failed');
      await t.tap(key('gateway-pay'));
      await t.pumpAndSettle();
      expect(key('failed-screen'), findsOneWidget);
      expect(find.textContaining('Your spot is held for another 14:'), findsOneWidget);
      expect(find.textContaining("it's refunded automatically"), findsOneWidget);

      await t.tap(key('try-again'));
      await t.pumpAndSettle();
      expect(key('gateway-screen'), findsOneWidget);
      expect(bookings.created.length, 1, reason: 'Try again keeps the same booking and hold');
      expect(bookings.payments, ['b1', 'b1']);

      gateway.onPay = () => bookings.setStatus('b1', 'payment_failed');
      await t.tap(key('gateway-pay'));
      await t.pumpAndSettle();
      await t.tap(key('give-up'));
      await t.pumpAndSettle();
      expect(bookings.cancelled, ['b1']);
      expect(key('home-screen'), findsOneWidget);
    });

    testWidgets('expired_hold_shows_spot_released_message', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      gateway.onPay = () => bookings.setStatus('b1', 'expired');
      await t.tap(key('gateway-pay'));
      await t.pumpAndSettle();
      expect(find.text('Your spot was released because the time ran out.'), findsOneWidget);
      expect(key('try-again'), findsNothing);
    });

    testWidgets('a hold that ran out before the gateway says so instead of opening it', (t) async {
      await pumpApp(t, location: '/event/e1/checkout', setup: (b) {});
      bookings.payError = BookingError('hold_expired');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      expect(find.text('Your spot was released because the time ran out.'), findsOneWidget);
      expect(key('gateway-screen'), findsNothing);
    });

    testWidgets('the gateway shows who is paying what', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      expect(find.text('🔒 Secure payment'), findsOneWidget);
      expect(find.text('RM30.00'), findsOneWidget);
      expect(find.text('Ref KLS-4821-AB12'), findsOneWidget);
    });
  });

  group('ticket', () {
    Future<void> openTicket(WidgetTester t, {String policy = '48h', DateTime? cutoff, int amount = 3000, String status = 'confirmed'}) async {
      await pumpApp(t, location: '/booking/b9/ticket', policy: policy, setup: (b) {
        b.byId['b9'] = bk('b9', amount: amount, cutoff: cutoff ?? clock.add(const Duration(days: 3)), status: status);
      });
    }

    testWidgets('ticket_shows_qr_from_token_reference_and_buttons_directions_calendar_cancel_done', (t) async {
      await openTicket(t);
      expect(find.text("You're in!"), findsOneWidget);
      expect(find.text('A receipt was sent to your email.'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(bookings.tokenAsked, ['b9'], reason: 'the QR holds the booking\'s signed token, fetched for its owner');
      expect(find.text('KLS-4821'), findsOneWidget);
      expect(find.text('Show this to the host on arrival'), findsOneWidget);
      expect(find.text('Batik Workshop'), findsOneWidget);

      await t.tap(key('ticket-directions'));
      await t.pumpAndSettle();
      expect(launched.single.toString(), 'https://www.google.com/maps/dir/?api=1&destination=3.129%2C101.671');
      await t.tap(key('ticket-calendar'));
      await t.pumpAndSettle();
      expect(calendarAdds, ['Batik Workshop']);
      expect(key('ticket-cancel'), findsOneWidget);
      await t.tap(key('ticket-done'));
      await t.pumpAndSettle();
      expect(key('home-screen'), findsOneWidget);
    });

    testWidgets('cancel_button_hidden_after_cutoff_or_for_policy_none', (t) async {
      await openTicket(t, cutoff: clock.subtract(const Duration(hours: 1)));
      expect(key('ticket-cancel'), findsNothing, reason: 'the free window has passed');
      await pumpApp(t, location: '/booking/b9/ticket', policy: 'none', setup: (b) => b.byId['b9'] = bk('b9', cutoff: null));
      expect(key('ticket-cancel'), findsNothing, reason: 'the host gives no refunds');
      await openTicket(t, status: 'attended');
      expect(key('ticket-cancel'), findsNothing, reason: 'it is over');
    });

    testWidgets('cancel_sheet_says_RM_amount_and_3_to_7_working_days_then_marks_cancelled', (t) async {
      await openTicket(t);
      await t.tap(key('ticket-cancel'));
      await t.pumpAndSettle();
      expect(find.text('Cancel this booking?'), findsOneWidget);
      expect(find.textContaining("You're within the free cancellation window. RM 30 goes back to your original payment method in 3 to 7 working days."), findsOneWidget);
      await t.tap(key('cancel-keep'));
      await t.pumpAndSettle();
      expect(bookings.cancelled, isEmpty);
      await t.tap(key('ticket-cancel'));
      await t.pumpAndSettle();
      await t.tap(key('cancel-yes'));
      await t.pumpAndSettle();
      expect(bookings.cancelled, ['b9']);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(key('ticket-cancel'), findsNothing);
    });

    testWidgets('a free booking can be cancelled with no refund words', (t) async {
      await openTicket(t, amount: 0);
      await t.tap(key('ticket-cancel'));
      await t.pumpAndSettle();
      expect(find.textContaining('goes back to your original payment method'), findsNothing);
      expect(find.textContaining('Your spot will be released.'), findsOneWidget);
    });

    testWidgets('a cancel the database refuses says so', (t) async {
      await openTicket(t);
      await t.tap(key('ticket-cancel'));
      await t.pumpAndSettle();
      bookings.setStatus('b9', 'confirmed'); // no change; now make cancel fail
      // swap in a failing cancel through a payError-like flag: cancel() throws when cancelFails is set
      bookings.cancelFails = BookingError('cancel_not_allowed');
      await t.tap(key('cancel-yes'));
      await t.pumpAndSettle();
      expect(find.text('The free cancellation window has passed.'), findsOneWidget);
    });
  });

  group('bookings tab', () {
    final soon = clock.add(const Duration(days: 3));
    testWidgets('bookings_upcoming_past_with_status_pills', (t) async {
      await pumpApp(t, location: '/tickets',
          upcoming: [bk('c1', status: 'confirmed', title: 'Pottery', starts: soon), bk('p1', status: 'processing', title: 'Salsa', starts: soon)],
          past: [bk('a1', status: 'attended', title: 'Old Yoga', starts: clock), bk('x1', status: 'cancelled', title: 'Old Run', starts: clock)]);
      expect(key('bookings-screen'), findsOneWidget);
      expect(find.text('Pottery'), findsOneWidget);
      expect(find.descendant(of: key('booking-c1'), matching: find.text('Confirmed')), findsOneWidget);
      expect(find.descendant(of: key('booking-p1'), matching: find.text('Processing')), findsOneWidget);
      expect(find.text('Old Yoga'), findsNothing);
      await t.tap(key('seg-past'));
      await t.pumpAndSettle();
      expect(find.text('Old Yoga'), findsOneWidget);
      expect(find.descendant(of: key('booking-a1'), matching: find.text('Attended')), findsOneWidget);
      expect(find.descendant(of: key('booking-x1'), matching: find.text('Cancelled')), findsOneWidget);
      expect(find.text('Tap an attended event to write a review'), findsOneWidget);
      expect(find.text('Pottery'), findsNothing);
    });

    testWidgets('tapping_confirmed_booking_opens_ticket_and_attended_opens_review', (t) async {
      await pumpApp(t, location: '/tickets', upcoming: [bk('c1', title: 'Pottery', starts: soon)],
          past: [bk('a1', status: 'attended', title: 'Old Yoga', starts: clock), bk('x1', status: 'cancelled', title: 'Old Run', starts: clock)],
          setup: (b) => b.byId['c1'] = bk('c1', title: 'Pottery', starts: soon));
      await t.tap(key('booking-c1'));
      await t.pumpAndSettle();
      expect(key('ticket-screen'), findsOneWidget);
      await t.tap(key('ticket-done'));
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text('Tickets')));
      await t.pumpAndSettle();
      await t.tap(key('seg-past'));
      await t.pumpAndSettle();
      await t.tap(key('booking-x1'));
      await t.pumpAndSettle();
      expect(key('ticket-screen'), findsNothing, reason: 'a cancelled booking opens nothing');
      await t.tap(key('booking-a1'));
      await t.pumpAndSettle();
      expect(t.widget<Text>(key('screen-title')).data, 'Review');
    });

    testWidgets('nothing booked yet says so', (t) async {
      await pumpApp(t, location: '/tickets');
      expect(find.text('No upcoming bookings'), findsOneWidget);
      await t.tap(key('seg-past'));
      await t.pumpAndSettle();
      expect(find.text('No past bookings'), findsOneWidget);
    });
  });
}
