import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delete: the host deletes an event a guest has paid for', (
    t,
  ) async {
    final host = await newHost('E2E Delete Host');
    final title = 'E2E Doomed ${uniqueWord()}';
    final eventId = await publishEvent(host, title: title, priceSen: 3000);

    // the guest pays in the app
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

    // the host deletes the event
    await host.db
        .schema('events')
        .rpc('delete_event', params: {'p_event_id': eventId});

    // a refund row exists, and the guest is told
    final refunds = await me().db
        .schema('payments')
        .from('refunds')
        .select('amount_sen')
        .eq('booking_id', booking);
    expect(refunds.length, 1);
    expect(refunds.first['amount_sen'], 3000);
    await goTo(t, '/notifications');
    await see(t, find.text('$title was cancelled'));
  });
}
