import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/host_status.dart';

import '../helpers/fake_backoffice.dart';
import '../helpers/pump_app.dart' show key;

Future<void> phoneSignIn(WidgetTester t, {String code = '123456'}) async {
  await t.enterText(key('bo-phone'), '012 345 6789');
  await t.tap(key('bo-send-code'));
  await t.pumpAndSettle();
  await t.enterText(key('bo-code'), code);
  await t.tap(key('bo-verify'));
  await t.pumpAndSettle();
}

Future<void> adminSignIn(
  WidgetTester t, {
  String password = 'secret-pass',
}) async {
  await t.tap(key('bo-tab-admin'));
  await t.pumpAndSettle();
  await t.enterText(key('bo-email'), 'ada@example.com');
  await t.enterText(key('bo-password'), password);
  await t.tap(key('bo-signin-submit'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('signed_out_shows_the_sign_in_with_host_and_admin_tabs', (
    t,
  ) async {
    await pumpBackOffice(t, BoWorld());
    expect(key('bo-signin'), findsOneWidget);
    expect(key('bo-tab-host'), findsOneWidget);
    expect(key('bo-tab-admin'), findsOneWidget);
    expect(key('bo-phone'), findsOneWidget);
    expect(key('bo-google'), findsOneWidget);
  });

  testWidgets(
    'an_approved_host_signs_in_with_a_phone_code_and_lands_in_the_host_shell',
    (t) async {
      final w = BoWorld(host: HostState.approved);
      await pumpBackOffice(t, w);
      await phoneSignIn(t);
      expect(key('bo-host-shell'), findsOneWidget);
      expect(w.auth.sentTo, ['+60123456789']);
    },
  );

  testWidgets('a_wrong_phone_code_says_so_and_stays', (t) async {
    await pumpBackOffice(t, BoWorld(host: HostState.approved));
    await phoneSignIn(t, code: '000000');
    expect(
      find.text("That code isn't right. Check it and try again."),
      findsOneWidget,
    );
    expect(key('bo-host-shell'), findsNothing);
  });

  testWidgets('a_number_that_is_not_malaysian_is_refused_before_sending', (
    t,
  ) async {
    final w = BoWorld();
    await pumpBackOffice(t, w);
    await t.enterText(key('bo-phone'), '555 1234');
    await t.tap(key('bo-send-code'));
    await t.pumpAndSettle();
    expect(find.textContaining('Malaysian mobile number'), findsOneWidget);
    expect(w.auth.sentTo, isEmpty);
  });

  testWidgets('google_button_starts_google_sign_in', (t) async {
    final w = BoWorld(host: HostState.approved);
    await pumpBackOffice(t, w);
    await t.tap(key('bo-google'));
    await t.pumpAndSettle();
    expect(w.auth.googleCalls, 1);
    expect(key('bo-host-shell'), findsOneWidget);
  });

  testWidgets('a_plain_user_sees_not_authorised_and_can_sign_out', (t) async {
    final w = BoWorld();
    await pumpBackOffice(t, w);
    await phoneSignIn(t);
    expect(key('bo-not-authorised'), findsOneWidget);
    expect(find.text('Not authorised'), findsOneWidget);
    await t.tap(key('bo-signout'));
    await t.pumpAndSettle();
    expect(key('bo-signin'), findsOneWidget);
    expect(w.auth.signOutCalls, 1);
  });

  testWidgets(
    'an_admin_without_an_authenticator_enrols_and_then_enters_the_admin_shell',
    (t) async {
      final w = BoWorld(isAdmin: true);
      await pumpBackOffice(t, w);
      await adminSignIn(t);
      expect(key('bo-mfa'), findsOneWidget);
      expect(key('bo-admin-shell'), findsNothing);
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
      await t.enterText(key('bo-mfa-code'), '123456');
      await t.tap(key('bo-mfa-verify'));
      await t.pumpAndSettle();
      expect(w.boAuth.verifies, [('f1', '123456')]);
      expect(key('bo-admin-shell'), findsOneWidget);
    },
  );

  testWidgets('an_admin_with_an_authenticator_is_only_asked_for_the_code', (
    t,
  ) async {
    final w = BoWorld(isAdmin: true, factorId: 'f9');
    await pumpBackOffice(t, w);
    await adminSignIn(t);
    expect(key('bo-mfa'), findsOneWidget);
    expect(key('bo-mfa-secret'), findsNothing);
    expect(w.boAuth.enrolments, isEmpty);
    await t.enterText(key('bo-mfa-code'), '123456');
    await t.tap(key('bo-mfa-verify'));
    await t.pumpAndSettle();
    expect(w.boAuth.verifies, [('f9', '123456')]);
    expect(key('bo-admin-shell'), findsOneWidget);
  });

  testWidgets('a_wrong_authenticator_code_stays_on_the_code_screen', (t) async {
    final w = BoWorld(isAdmin: true, factorId: 'f9');
    await pumpBackOffice(t, w);
    await adminSignIn(t);
    await t.enterText(key('bo-mfa-code'), '000000');
    await t.tap(key('bo-mfa-verify'));
    await t.pumpAndSettle();
    expect(
      find.text("That code isn't right. Check it and try again."),
      findsOneWidget,
    );
    expect(key('bo-admin-shell'), findsNothing);
  });

  testWidgets('a_wrong_password_says_so', (t) async {
    final w = BoWorld(isAdmin: true);
    await pumpBackOffice(t, w);
    await adminSignIn(t, password: 'nope');
    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(key('bo-mfa'), findsNothing);
  });

  testWidgets(
    'a_person_who_is_not_an_admin_cannot_get_past_the_password_screen_into_the_admin_shell',
    (t) async {
      final w = BoWorld();
      await pumpBackOffice(t, w);
      await adminSignIn(t);
      expect(key('bo-not-authorised'), findsOneWidget);
      expect(key('bo-admin-shell'), findsNothing);
    },
  );

  testWidgets('the_sign_in_fits_a_phone', (t) async {
    await pumpBackOffice(t, BoWorld(), width: 390, height: 800);
    expect(key('bo-signin'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'sign_in_screen_has_no_overflow_at_phone_width_on_the_admin_tab',
    (t) async {
      await pumpBackOffice(t, BoWorld(), width: 390, height: 800);
      await t.tap(key('bo-tab-admin'));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(t.takeException(), isNull);
    },
  );
}
