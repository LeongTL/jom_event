import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tickets: a paid ticket is on Home and in Tickets, cancelling moves it to Previous',
    (t) async {
      final host = await newHost('E2E Tickets Host');
      final title = 'E2E Ticketed ${uniqueWord()}';
      final eventId = await publishEvent(
        host,
        title: title,
        priceSen: 3000,
        category: 'make',
      );

      await launchApp(t);
      await openEventFromHome(t, title);
      await t.tap(key('join'));
      await see(t, find.text('Continue with phone number'));
      await signInWithPhone(t);
      await see(t, key('checkout-screen'));
      await t.tap(key('pay'));
      await see(t, key('gateway-screen'));
      await t.tap(key('gateway-pay'));
      await see(t, key('ticket-screen'), within: const Duration(seconds: 40));
      final booking = (await me().db
          .schema('bookings')
          .from('bookings')
          .select('id')
          .eq('event_id', eventId)
          .single())['id'];

      // Home's ticket row
      await goTo(t, '/explore');
      await see(t, key('ticket-row'));
      expect(
        find.descendant(of: key('ticket-row'), matching: label(title)),
        findsOneWidget,
      );

      // the Tickets tab, in the colour of a "make" event
      await goTo(t, '/tickets');
      await see(t, key('ticket-header'));
      final header =
          t.widget<Container>(key('ticket-header')).decoration as BoxDecoration;
      expect(header.color, const Color(0xFFA8553A));

      // cancelling moves it to Previous
      await t.ensureVisible(key('ticket-cancel'));
      await settle(t);
      await t.tap(key('ticket-cancel'));
      await see(t, key('cancel-yes'));
      await t.tap(key('cancel-yes'));
      await settle(t, const Duration(seconds: 2));
      expect(key('ticket-header'), findsNothing);
      await t.tap(key('seg-past'));
      await see(t, key('booking-$booking'));
    },
  );
}
