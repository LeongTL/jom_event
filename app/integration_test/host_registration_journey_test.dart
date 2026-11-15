import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

Future<void> fillApplyForm(WidgetTester t, String name) async {
  await see(t, key('apply-name'));
  await t.enterText(key('apply-name'), name);
  await t.tap(key('apply-area-Bangsar'));
  await t.enterText(key('apply-holder'), name);
  await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
  await settle(t);
  await t.enterText(key('apply-bank'), 'Maybank');
  // the keyboard shrinks the list, so the number field below is not built until the list scrolls again
  await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
  await settle(t);
  await t.enterText(key('apply-number'), '1234564821');
  await t.pump();
  await t.tap(key('apply-submit'));
}

Future<int> notices(String type) async {
  final rows =
      await me().db
              .schema('identity')
              .from('notifications')
              .select('id')
              .eq('type', type)
          as List;
  return rows.length;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'host registration: none, pending, rejected, pending, approved, suspended, entrance off',
    (t) async {
      await launchApp(t);
      addTearDown(() => setHostEntry(true));

      // signed out, a Host mode link goes nowhere
      await goTo(t, '/host-mode/home');
      expect(key('host-home'), findsNothing);

      // none: Register as Event owner; Host mode is closed
      await openTab(t, 'Profile');
      await signInWithPhone(t);
      await see(t, key('host-card-none'));
      expect(find.text('Register as Event owner'), findsOneWidget);
      await goTo(t, '/host-mode/home');
      expect(key('host-home'), findsNothing);
      await goTo(t, '/profile');

      // apply: pending, "Application under review", still no Host mode
      await t.tap(key('host-card-none'));
      await fillApplyForm(t, 'E2E Studio');
      await see(t, key('host-card-pending'));
      expect(find.text('Application under review'), findsOneWidget);
      expect(find.text('Switch to Host mode'), findsNothing);
      await goTo(t, '/host-mode/home');
      expect(key('host-home'), findsNothing);
      await goTo(t, '/profile');

      // rejected: the reason and Apply again; the user is told
      await reviewHost(me().id, 'reject', reason: 'Please add a real photo');
      await resumeApp(t);
      await see(t, key('host-card-rejected'));
      expect(find.text('Please add a real photo'), findsOneWidget);
      expect(find.text('Apply again'), findsOneWidget);
      expect(await notices('host_rejected'), 1);

      // apply again: pending again
      await t.tap(key('host-card-rejected'));
      await fillApplyForm(t, 'E2E Studio');
      await see(t, key('host-card-pending'));

      // approved: Switch to Host mode opens the host home
      await reviewHost(me().id, 'approve');
      await resumeApp(t);
      await see(t, key('host-card-approved'));
      expect(find.text('Switch to Host mode'), findsOneWidget);
      expect(await notices('host_approved'), 1);
      await t.tap(key('host-card-approved'));
      await see(t, key('host-home'));

      // suspended: the paused message, Host mode is closed again
      await goTo(t, '/profile');
      await reviewHost(me().id, 'suspend', reason: 'Complaint');
      await resumeApp(t);
      await see(t, key('host-card-suspended'));
      expect(
        find.text('Your host access is paused. Contact support'),
        findsOneWidget,
      );
      expect(await notices('host_suspended'), 1);
      await goTo(t, '/host-mode/home');
      expect(key('host-home'), findsNothing);
      await goTo(t, '/profile');

      // back to approved, then the entrance switched off: no card, no Host mode
      await reviewHost(me().id, 'unsuspend');
      await resumeApp(t);
      await see(t, key('host-card-approved'));
      await setHostEntry(false);
      await resumeApp(t);
      expect(key('host-card-approved'), findsNothing);
      expect(find.text('Switch to Host mode'), findsNothing);
      await goTo(t, '/host-mode/home');
      expect(key('host-home'), findsNothing);
    },
  );
}
