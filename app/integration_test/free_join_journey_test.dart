import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('free event: Join, sign in, Confirm my spot, ticket', (t) async {
    final host = await newHost('E2E Free Host');
    final title = 'E2E Free Meetup ${uniqueWord()}';
    await publishEvent(
      host,
      title: title,
      priceSen: 0,
      startsIn: const Duration(hours: 3),
    );

    await launchApp(t);
    await openEventFromHome(t, title);

    await t.tap(key('join'));
    await see(t, find.text('Continue with phone number'));
    await signInWithPhone(t);

    await see(t, key('checkout-screen'));
    await t.tap(key('confirm'));
    await see(t, key('ticket-screen'));
    expect(find.text(title), findsWidgets);
  });
}
