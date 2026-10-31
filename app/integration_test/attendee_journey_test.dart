import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'attendee: browse, save, pay, ticket, chat with the host, review',
    (t) async {
      final host = await newHost('E2E Pilates Host');
      final word = uniqueWord();
      final title = 'E2E Pilates $word';
      final eventId = await publishEvent(host, title: title, priceSen: 3000);

      // browse signed out; the heart asks for sign-in, then saves
      await launchApp(t);
      await openEventFromHome(t, title);
      await t.tap(key('heart-off:$eventId'));
      await see(t, find.text('Continue with phone number'));
      await signInWithPhone(t);
      await see(t, key('heart-on:$eventId'));

      // join and pay at the mock gateway
      await t.tap(key('join'));
      await see(t, key('checkout-screen'));
      await t.tap(key('pay'));
      await see(t, key('gateway-screen'));
      await t.tap(key('gateway-pay'));
      await see(t, key('ticket-screen'), within: const Duration(seconds: 40));
      await see(t, key('qr'));

      // message the host and see the reply arrive
      await t.tap(key('ticket-done'));
      await settle(t, const Duration(seconds: 1));
      await openTab(t, 'Explore');
      await openEventFromHome(t, title);
      await t.ensureVisible(
        key('message'),
      ); // on a shorter screen the sticky Book bar covers it
      await t.tap(key('message'));
      await see(t, key('thread-screen'));
      await t.enterText(key('msg-field'), 'Hi, do I need to bring a mat?');
      await t.tap(key('send-button'));
      await see(t, find.text('Hi, do I need to bring a mat?'));
      await replyInLatestThread(host, 'Mats are provided, see you there.');
      await see(t, find.text('Mats are provided, see you there.'));

      // a second, short event: the app's user joins, is checked in, the host completes it, the guest reviews
      final soon = 'E2E Soon $word';
      final soonId = await publishEvent(
        host,
        title: soon,
        priceSen: 0,
        startsIn: const Duration(seconds: 25),
        lasts: const Duration(seconds: 5),
      );
      final booking = await bookAndPay(me(), soonId);
      await checkIn(host, soonId, await ticketToken(me(), booking));
      await Future<void>.delayed(const Duration(seconds: 32));
      await host.db
          .schema('events')
          .rpc('complete_event', params: {'p_event_id': soonId});

      await goTo(t, '/tickets');
      await t.tap(key('seg-past'));
      await see(t, key('booking-$booking'));
      await t.tap(key('booking-$booking'));
      await see(t, key('review-screen'));
      await t.tap(key('star-5'));
      await t.enterText(key('review-body'), 'Lovely, calm class.');
      await t.tap(key('submit-review'));
      await settle(t, const Duration(seconds: 2));
      expect(key('review-screen'), findsNothing);
      final stars =
          await host.db
                  .schema('reviews')
                  .rpc('host_reviews', params: {'p_host_id': host.id})
              as List;
      expect((stars.first as Map)['stars'], 5);
    },
  );
}
