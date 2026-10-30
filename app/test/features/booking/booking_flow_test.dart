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
import 'package:jom/shared/models/event_summary.dart';
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
final today = sum('e3', title: 'Salsa Night', starts: clock.add(const Duration(hours: 5)), cats: ['move', 'meet']);

Future<void> pumpApp(
  WidgetTester t, {
  required String location,
  int priceSen = 3000,
  Object? createError,
  List<Booking> upcoming = const [],
  List<Booking> past = const [],
  String policy = '48h',
  int spotsLeft = 7,
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
        'e1': detailOf(spotsLeft == 7 ? paid : sum('e1', title: 'Batik Workshop', price: 3000, spots: spotsLeft), policy: policy),
        'e2': detailOf(free, bookable: false, policy: 'none'),
        'e3': detailOf(today),
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
      weekendProvider.overrideWith((ref, a) async => <EventSummary>[]),
      nearYouProvider.overrideWith((ref, q) async => <EventSummary>[]),
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

    testWidgets('checkout shows the contact and the booking limit', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      expect(find.text('Mei'), findsOneWidget);
      expect(find.text('+60 12 345 6789'), findsOneWidget);
      expect(find.text('Up to 2 per booking'), findsOneWidget);
    });

    testWidgets('checkout_total_is_price_times_people_with_no_service_fee_line', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      expect(find.text('RM 30 × 1 spot'), findsOneWidget);
      expect(find.text('Price details'), findsOneWidget);
      expect(find.textContaining('No booking fees'), findsOneWidget);
      await t.tap(key('people-plus'));
      await t.pumpAndSettle();
      expect(find.text('RM 30 × 2 spots'), findsOneWidget);
      expect(textOf(t, 'total'), 'RM 60');
      expect(find.textContaining(RegExp('service fee', caseSensitive: false)), findsNothing);
    });

    testWidgets('spots_stepper_stops_at_2_and_never_exceeds_spots_left', (t) async {
      await pumpApp(t, location: '/event/e1/checkout', spotsLeft: 1);
      await t.tap(key('people-plus'));
      await t.pumpAndSettle();
      expect(textOf(t, 'people-count'), '1', reason: 'only one spot is left');
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('people-plus'));
      await t.tap(key('people-plus'));
      await t.pumpAndSettle();
      expect(textOf(t, 'people-count'), '2');
    });

    testWidgets('checkout_policy_card_states_the_refund_amount_and_the_cutoff_time_in_kuala_lumpur', (t) async {
      await pumpApp(t, location: '/event/e1/checkout'); // 48h policy, starts Sat 12 Jan 9:00 AM KL
      final card = key('checkout-policy');
      expect(find.descendant(of: card, matching: find.text('Full refund until Thu 10 Jan, 9:00 AM')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text("You'd get RM 30 back to your original payment method.")), findsOneWidget);
      await t.tap(key('people-plus'));
      await t.pumpAndSettle();
      expect(find.descendant(of: card, matching: find.text("You'd get RM 60 back to your original payment method.")), findsOneWidget);
      await pumpApp(t, location: '/event/e1/checkout', policy: 'none');
      expect(find.descendant(of: key('checkout-policy'), matching: find.text('No refunds once booked')), findsOneWidget);
      await pumpApp(t, location: '/event/e2/checkout', priceSen: 0);
      expect(find.descendant(of: key('checkout-policy'), matching: find.text('Free event')), findsOneWidget);
    });

    testWidgets('free_confirm_my_spot_creates_confirmed_booking_and_opens_ticket', (t) async {
      await pumpApp(t, location: '/event/e2/checkout', priceSen: 0);
      await t.tap(key('confirm'));
      await t.pumpAndSettle();
      expect(bookings.created, [('e2', 1, 'Mei', '60123456789')]);
      expect(key('ticket-screen'), findsOneWidget);
      expect(find.text("You're booked"), findsOneWidget);
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
      await t.tap(key('ticket-done'));
      await t.pumpAndSettle();
      expect(key('checkout-screen'), findsNothing, reason: 'Done leaves the booking, it does not step back into Review and pay');
      expect(key('tickets-screen'), findsOneWidget);
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

    testWidgets('processing_and_failed_copy_is_unchanged', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      await t.tap(key('gateway-pay'));
      await moment(t);
      expect(find.text('Confirming your payment'), findsOneWidget);
      expect(find.text("Please don't close the app or pay again. This takes a few seconds."), findsOneWidget);
      bookings.setStatus('b1', 'payment_failed');
      await t.pumpAndSettle();
      expect(find.text("Payment didn't go through"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Give up'), findsOneWidget);
    });

    testWidgets('gateway_page_is_neutral_white_and_not_themed', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      expect(t.widget<Scaffold>(key('gateway-screen')).backgroundColor, const Color(0xFFF6F7F9));
      expect(t.widget<FilledButton>(key('gateway-pay')).style!.backgroundColor!.resolve({}), const Color(0xFF2F6BFF), reason: 'the third party keeps its own blue, not the app accent');
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

    testWidgets('the gateway has a back button that returns to checkout', (t) async {
      await pumpApp(t, location: '/event/e1/checkout');
      await t.tap(key('pay'));
      await t.pumpAndSettle();
      await t.tap(key('gateway-back'));
      await t.pumpAndSettle();
      expect(key('gateway-screen'), findsNothing);
      expect(key('checkout-screen'), findsOneWidget);
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
      expect(find.text("You're booked"), findsOneWidget);
      expect(find.text('Confirmation sent to your email'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(bookings.tokenAsked, ['b9'], reason: 'the QR holds the booking\'s signed token, fetched for its owner');
      expect(find.text('KLS-4821'), findsOneWidget);
      expect(find.text('Show this at the entrance'), findsOneWidget);
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
      expect(find.byType(QrImageView), findsNothing, reason: 'a cancelled ticket has no QR to show');
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

  group('tickets tab', () {
    final soon = clock.add(const Duration(days: 3));
    Future<void> openTab(WidgetTester t, {List<Booking> upcoming = const [], List<Booking> past = const []}) =>
        pumpApp(t, location: '/tickets', upcoming: upcoming, past: past);

    testWidgets('upcoming_groups_by_day_with_Today_first_each_a_full_ticket', (t) async {
      await openTab(t, upcoming: [bk('c1', event: 'e1', starts: soon), bk('c2', event: 'e3', code: 'KLS-0002')]);
      expect(key('tickets-screen'), findsOneWidget);
      expect(find.text('Tickets'), findsWidgets);
      final today = t.getTopLeft(find.text('TODAY · WED 9 JAN')).dy, later = t.getTopLeft(find.text('SAT 12 JAN')).dy;
      expect(today, lessThan(later));
      expect(find.byType(QrImageView), findsNWidgets(2));
      expect(find.text('✓ Confirmed'), findsNWidgets(2));
    });

    testWidgets('each_ticket_header_uses_its_primary_category_colour', (t) async {
      await openTab(t, upcoming: [bk('c1', event: 'e1', starts: soon), bk('c2', event: 'e3', code: 'KLS-0002')]);
      Color header(String id) => (t.widget<Container>(find.descendant(of: key('ticket-$id'), matching: key('ticket-header'))).decoration as BoxDecoration).color!;
      expect(header('c1'), const Color(0xFFA8553A), reason: 'make');
      expect(header('c2'), const Color(0xFF1F5E5B), reason: 'move comes before meet');
    });

    testWidgets('ticket_card_rows_in_the_designed_order_and_price_has_no_service_fee', (t) async {
      await openTab(t, upcoming: [bk('c1', event: 'e1', people: 2, amount: 6000, starts: soon)]);
      final ys = [for (final k in ['row-date', 'row-attendee', 'row-host', 'row-payment']) t.getTopLeft(key(k)).dy];
      expect(ys, [...ys]..sort());
      expect(find.text('Mei'), findsOneWidget, reason: 'attendee');
      expect(find.text('KLS-4821'), findsOneWidget);
      expect(find.text('Mei Studio'), findsOneWidget);
      expect(find.text('RM 60'), findsOneWidget, reason: 'price x people only');
      expect(find.textContaining('fee', findRichText: true), findsNothing);
    });

    testWidgets('processing_ticket_shows_the_chip_and_a_hint_instead_of_the_qr', (t) async {
      await openTab(t, upcoming: [bk('p1', status: 'processing', event: 'e1', starts: soon)]);
      expect(find.text('Processing'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Your QR code appears here as soon as the payment clears.'), findsOneWidget);
    });

    testWidgets('actions_are_two_buttons_and_a_cancel_link_only_inside_the_free_window', (t) async {
      await openTab(t, upcoming: [bk('c1', event: 'e1', cutoff: clock.add(const Duration(days: 1)), starts: soon), bk('c2', event: 'e3', code: 'KLS-0002', cutoff: clock.subtract(const Duration(hours: 1)))]);
      expect(key('ticket-directions'), findsNWidgets(2));
      expect(key('ticket-calendar'), findsNWidgets(2));
      expect(key('ticket-cancel'), findsOneWidget);
    });

    testWidgets('cancelling_from_the_tab_moves_the_ticket_out_of_upcoming', (t) async {
      final c1 = bk('c1', event: 'e1', cutoff: clock.add(const Duration(days: 1)), starts: soon);
      await pumpApp(t, location: '/tickets', upcoming: [c1], setup: (b) => b.byId['c1'] = c1);
      await t.ensureVisible(key('ticket-cancel'));
      await t.tap(key('ticket-cancel'));
      await t.pumpAndSettle();
      bookings.upcoming.clear();
      await t.tap(key('cancel-yes'));
      await t.pumpAndSettle();
      expect(bookings.cancelled, ['c1']);
      expect(find.textContaining('No upcoming tickets.'), findsOneWidget);
    });

    testWidgets('previous_lists_attended_and_cancelled_and_only_attended_opens_review', (t) async {
      await openTab(t, past: [bk('a1', status: 'attended', event: 'e1', starts: clock), bk('x1', status: 'cancelled', event: 'e2', starts: clock)]);
      await t.tap(key('seg-past'));
      await t.pumpAndSettle();
      expect(find.descendant(of: key('booking-a1'), matching: find.text('Attended')), findsOneWidget);
      expect(find.descendant(of: key('booking-x1'), matching: find.text('Cancelled')), findsOneWidget);
      expect(find.text('Tap an attended event to write a review'), findsOneWidget);
      await t.tap(key('booking-x1'));
      await t.pumpAndSettle();
      expect(key('tickets-screen'), findsOneWidget, reason: 'a cancelled booking opens nothing');
      await t.tap(key('booking-a1'));
      await t.pumpAndSettle();
      expect(key('review-screen'), findsOneWidget);
    });

    testWidgets('a_cancelled_booking_whose_event_is_gone_still_shows_in_previous', (t) async {
      await openTab(t, past: [bk('x1', status: 'cancelled', event: 'gone', title: 'Vanished Event', starts: clock)]);
      await t.tap(key('seg-past'));
      await t.pumpAndSettle();
      expect(find.text('Vanished Event'), findsOneWidget);
    });

    testWidgets('empty_upcoming_says_so_and_offers_Explore', (t) async {
      await openTab(t);
      expect(find.textContaining('No upcoming tickets.'), findsOneWidget);
      await t.tap(find.text('Explore events'));
      await t.pumpAndSettle();
      expect(key('home-screen'), findsOneWidget);
    });

    testWidgets('ten_tickets_do_not_overflow', (t) async {
      await openTab(t, upcoming: [for (var i = 0; i < 10; i++) bk('c$i', event: i.isEven ? 'e1' : 'e3', code: 'KLS-000$i', starts: soon)]);
      expect(t.takeException(), isNull);
    });
  });
}
