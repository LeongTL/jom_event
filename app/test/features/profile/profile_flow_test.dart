import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/auth/data/auth_repository.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/pump_app.dart';

void main() {
  // rootBundle remembers a read that never finished in an earlier test (the fake clock does not drive file reads)
  setUp(rootBundle.clear);

  testWidgets('profile_shows_name_phone_and_the_rows', (t) async {
    final router = await pumpApp(t, location: '/profile');
    expect(find.text('Mei Tan'), findsOneWidget);
    expect(find.text('+60 12 345 6789'), findsOneWidget);
    for (final row in ['My reviews', 'Notifications', 'Help & support', 'Terms & privacy', 'Sign out', 'Delete account']) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.text('Switch to Host mode'), findsOneWidget);
    await t.tap(find.text('My reviews'));
    await t.pumpAndSettle();
    expect(where(router), '/my-reviews');
  });

  testWidgets('rows_open_notifications_help_terms_and_host_mode', (t) async {
    final router = await pumpApp(t, location: '/profile');
    for (final (label, path) in [('Notifications', '/notifications'), ('Help & support', '/help'), ('Terms & privacy', '/legal')]) {
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(where(router), path);
      router.pop();
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Switch to Host mode'));
    await t.pumpAndSettle();
    expect(where(router), '/host-mode/home');
  });

  testWidgets('profile_signed_out_shows_the_sign_in_prompt', (t) async {
    await pumpApp(t, location: '/profile', auth: FakeAuthRepository());
    expect(find.text('Sign in to see your profile'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('profile_log_out_returns_to_explore_signed_out', (t) async {
    final auth = FakeAuthRepository(initial: fakeSession(name: 'Mei Tan'));
    final router = await pumpApp(t, location: '/profile', auth: auth);
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(where(router), '/explore');
  });

  group('delete account', () {
    testWidgets('delete_account_asks_confirmation_then_calls_function_and_signs_out', (t) async {
      final auth = FakeAuthRepository(initial: fakeSession(name: 'Mei Tan'));
      final router = await pumpApp(t, location: '/profile', auth: auth);
      await t.tap(find.text('Delete account'));
      await t.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);
      await t.tap(find.text('Keep my account'));
      await t.pumpAndSettle();
      expect(auth.deleteCalls, 0);

      await t.tap(find.text('Delete account'));
      await t.pumpAndSettle();
      await t.tap(key('confirm-delete'));
      await t.pumpAndSettle();
      expect(auth.deleteCalls, 1);
      expect(where(router), '/explore');
    });

    testWidgets('host_with_active_events_gets_clear_refusal_message', (t) async {
      final auth = FakeAuthRepository(initial: fakeSession(name: 'Mei Tan'))..deleteError = const AccountDeleteRefused('host_has_active_events');
      final router = await pumpApp(t, location: '/profile', auth: auth);
      await t.tap(find.text('Delete account'));
      await t.pumpAndSettle();
      await t.tap(key('confirm-delete'));
      await t.pumpAndSettle();
      expect(find.text('You still have events with guests. Finish or cancel them first, then try again.'), findsOneWidget);
      expect(where(router), '/profile');
    });

    testWidgets('a_failed_delete_says_so_and_stays_signed_in', (t) async {
      final auth = FakeAuthRepository(initial: fakeSession(name: 'Mei Tan'))..deleteError = Exception('offline');
      final router = await pumpApp(t, location: '/profile', auth: auth);
      await t.tap(find.text('Delete account'));
      await t.pumpAndSettle();
      await t.tap(key('confirm-delete'));
      await t.pumpAndSettle();
      expect(find.text('Could not delete your account. Check your connection and try again.'), findsOneWidget);
      expect(where(router), '/profile');
    });
  });

  testWidgets('terms_and_privacy_pages_render_from_assets', (t) async {
    await pumpApp(t, location: '/legal');
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); // the asset read is real I/O
    await t.pumpAndSettle();
    expect(find.text('Terms of use'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Privacy policy'), 400);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('help_has_contact_and_questions', (t) async {
    await pumpApp(t, location: '/help');
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('How do refunds work?'), findsOneWidget);
  });
}
