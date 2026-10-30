import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

/// [from] plus [n] working days (Monday to Friday) on the Kuala Lumpur calendar, as a yyyy-mm-dd string.
String addWorkingDays(DateTime from, int n) {
  var d = from.toUtc().add(const Duration(hours: 8));
  while (n > 0) {
    d = d.add(const Duration(days: 1));
    if (d.weekday < 6) n--;
  }
  return d.toIso8601String().substring(0, 10);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('host: apply, publish, a guest books, scan, complete, payout', (
    t,
  ) async {
    final word = uniqueWord();
    await launchApp(t);

    // sign in from the Profile tab, then become a host
    await openTab(t, 'Profile');
    await signInWithPhone(t);
    await t.tap(key('host-mode-card'));
    await see(t, key('apply-name'));
    await t.enterText(key('apply-name'), 'E2E Studio');
    await t.tap(key('apply-area-Bangsar'));
    await t.enterText(key('apply-holder'), 'E2E Studio');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await settle(t);
    await t.enterText(key('apply-bank'), 'Maybank');
    await t.enterText(key('apply-number'), '1234564821');
    await t.pump();
    await t.tap(key('apply-submit'));
    await see(t, key('host-home'));

    // create and publish an event with the form
    final title = 'E2E Clay $word';
    await t.tap(key('new-event-button'));
    await see(t, key('form-title'));
    await t.enterText(key('form-title'), title);
    await t.enterText(key('form-venue'), 'Test Deck');
    await t.tap(key('form-area-Bangsar'));
    await t.tap(key('field-when'));
    for (var i = 0; i < 3; i++) {
      // the date, then the start time, then the end time
      await settle(t);
      await t.tap(find.text('OK'));
    }
    await settle(t);
    await t.ensureVisible(key('publish'));
    await settle(t);
    await t.tap(key('publish'));
    await see(t, key('host-events'));
    await see(t, label(title));

    // a short event of this host's, with one paying guest
    final soonId = await publishEvent(
      me(),
      title: 'E2E Soon $word',
      priceSen: 3000,
      startsIn: const Duration(seconds: 25),
      lasts: const Duration(seconds: 5),
    );
    final guest = await newPerson();
    final token = await ticketToken(guest, await bookAndPay(guest, soonId));

    // scan the guest's ticket at the door
    await goTo(t, '/host-mode/events/$soonId/scan');
    await see(t, key('debug-code'));
    await t.enterText(key('debug-code'), token);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await see(t, find.text('Checked in just now'));

    // after the end time, mark the event as completed
    await Future<void>.delayed(const Duration(seconds: 30));
    await goTo(t, '/host-mode/events/$soonId');
    await t.tap(key('complete-button'));
    await see(t, key('complete-yes'));
    await t.tap(key('complete-yes'));
    await see(t, key('host-events'));
    final doneAt = DateTime.now();

    // the payout: 30.00 gross, 0.45 gateway fee, 3.00 platform fee, due in 3 working days
    final p = await me().db
        .schema('payments')
        .from('payouts')
        .select('amount_sen, status, due_at')
        .eq('event_id', soonId)
        .single();
    expect(p['amount_sen'], 3000 - 45 - 300);
    expect(p['status'], 'scheduled');
    final due = DateTime.parse(p['due_at'] as String)
        .toUtc()
        .add(const Duration(hours: 8));
    expect(due.toIso8601String().substring(0, 10), addWorkingDays(doneAt, 3));
  });
}
