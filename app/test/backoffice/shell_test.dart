import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/host_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;

import '../helpers/fake_auth.dart';
import '../helpers/fake_backoffice.dart';
import '../helpers/pump_app.dart' show key;

Session admin() =>
    fakeSession(phone: null, email: 'ada@example.com', name: 'Ada Admin');

void main() {
  testWidgets(
    'desktop_admin_shell_has_a_left_navigation_with_only_applications',
    (t) async {
      await pumpBackOffice(
        t,
        BoWorld(isAdmin: true, aal2: true, signedIn: admin()),
      );
      expect(key('bo-admin-shell'), findsOneWidget);
      expect(key('bo-sidebar'), findsOneWidget);
      expect(key('bo-menu'), findsNothing);
      expect(key('bo-nav-applications'), findsOneWidget);
      expect(find.text('Hosts'), findsNothing);
      expect(find.text('Overview'), findsNothing);
    },
  );

  testWidgets('tablet_width_keeps_the_left_navigation', (t) async {
    await pumpBackOffice(
      t,
      BoWorld(isAdmin: true, aal2: true, signedIn: admin()),
      width: 820,
      height: 900,
    );
    expect(key('bo-sidebar'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('phone_width_uses_a_top_bar_with_a_menu_and_does_not_overflow', (
    t,
  ) async {
    await pumpBackOffice(
      t,
      BoWorld(isAdmin: true, aal2: true, signedIn: admin()),
      width: 390,
      height: 800,
    );
    expect(key('bo-sidebar'), findsNothing);
    expect(key('bo-menu'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(key('bo-menu'));
    await t.pumpAndSettle();
    expect(key('bo-nav-applications'), findsOneWidget);
    expect(key('bo-signout'), findsOneWidget);
  });

  testWidgets('an_admin_with_a_password_only_is_held_at_the_code_screen', (
    t,
  ) async {
    await pumpBackOffice(t, BoWorld(isAdmin: true, signedIn: admin()));
    expect(key('bo-mfa'), findsOneWidget);
    expect(key('bo-admin-shell'), findsNothing);
  });

  testWidgets('a_person_who_is_both_admin_and_host_can_switch_and_back', (
    t,
  ) async {
    await pumpBackOffice(
      t,
      BoWorld(
        isAdmin: true,
        aal2: true,
        host: HostState.approved,
        signedIn: admin(),
      ),
    );
    expect(key('bo-admin-shell'), findsOneWidget);
    await t.tap(key('bo-switch'));
    await t.pumpAndSettle();
    expect(key('bo-host-shell'), findsOneWidget);
    await t.tap(key('bo-switch'));
    await t.pumpAndSettle();
    expect(key('bo-admin-shell'), findsOneWidget);
  });

  testWidgets('only_a_person_who_is_both_sees_the_switch', (t) async {
    await pumpBackOffice(
      t,
      BoWorld(isAdmin: true, aal2: true, signedIn: admin()),
    );
    expect(key('bo-switch'), findsNothing);
  });

  testWidgets('signing_out_forgets_the_switch_choice', (t) async {
    final w = BoWorld(
      isAdmin: true,
      aal2: true,
      host: HostState.approved,
      signedIn: admin(),
    );
    await pumpBackOffice(t, w);
    await t.tap(key('bo-switch'));
    await t.pumpAndSettle();
    await t.tap(key('bo-signout'));
    await t.pumpAndSettle();
    expect(key('bo-signin'), findsOneWidget);
    w.auth.signInAs(admin());
    await t.pumpAndSettle();
    expect(key('bo-admin-shell'), findsOneWidget);
  });

  testWidgets('a_suspended_host_is_not_authorised', (t) async {
    await pumpBackOffice(
      t,
      BoWorld(host: HostState.suspended, signedIn: fakeSession()),
    );
    expect(key('bo-not-authorised'), findsOneWidget);
    expect(key('bo-host-shell'), findsNothing);
  });

  testWidgets('the_host_shell_is_a_placeholder_with_sign_out', (t) async {
    await pumpBackOffice(
      t,
      BoWorld(host: HostState.approved, signedIn: fakeSession()),
    );
    expect(key('bo-host-shell'), findsOneWidget);
    expect(find.textContaining('coming'), findsOneWidget);
    expect(key('bo-signout'), findsOneWidget);
  });
}
