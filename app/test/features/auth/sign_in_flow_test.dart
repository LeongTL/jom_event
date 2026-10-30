import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/calm.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/auth/domain/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth.dart';

/// A page with one button that does what a Join / heart / Message button will do: ask for an account first.
class Probe extends ConsumerWidget {
  const Probe({super.key, required this.why, required this.onDone, this.onRefused});
  final AuthReason why;
  final VoidCallback onDone;
  final VoidCallback? onRefused;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: TextButton(
          onPressed: () async {
            final ok = await requireAuth(ref, context, why);
            if (ok) {
              onDone();
            } else {
              onRefused?.call();
            }
          },
          child: const Text('Do it'),
        ),
      );
}

Future<void> pumpProbe(WidgetTester t, FakeAuthRepository repo, {AuthReason why = AuthReason.join, required VoidCallback onDone, VoidCallback? onRefused}) =>
    t.pumpWidget(ProviderScope(
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: calmTheme(), home: Scaffold(body: Probe(why: why, onDone: onDone, onRefused: onRefused))),
    ));

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}

void main() {
  group('requireAuth', () {
    testWidgets('require_auth_returns_true_without_sheet_when_signed_in', (t) async {
      var done = 0;
      await pumpProbe(t, FakeAuthRepository(initial: fakeSession(name: 'Mei')), onDone: () => done++);
      await t.pumpAndSettle();
      await tapText(t, 'Do it');
      expect(done, 1);
      expect(find.text('Continue with Google'), findsNothing);
    });

    // require_auth_shows_heading_for_each_reason: one isolated test per reason (the three headings)
    const copy = {
      AuthReason.join: ('Sign in to join', 'Free or paid, we need to know who is coming. Browsing stays open.'),
      AuthReason.save: ('Sign in to save', 'Saved events live in your account, so they follow you across phones.'),
      AuthReason.chat: ('Sign in to chat', 'Chat is between you and the host, so we need to know who you are.'),
    };
    for (final e in copy.entries) {
      testWidgets('require_auth_shows_heading_for_each_reason: ${e.key.name}', (t) async {
        await pumpProbe(t, FakeAuthRepository(), why: e.key, onDone: () {});
        await t.pumpAndSettle();
        await tapText(t, 'Do it');
        expect(find.text(e.value.$1), findsOneWidget);
        expect(find.text(e.value.$2), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Continue with phone number'), findsOneWidget);
      });
    }

    testWidgets('sign_in_sheet_keeps_the_three_headings_and_uses_accent_buttons', (t) async {
      for (final e in copy.entries) {
        await pumpProbe(t, FakeAuthRepository(), why: e.key, onDone: () {});
        await t.pumpAndSettle();
        await tapText(t, 'Do it');
        expect(find.text(e.value.$1), findsOneWidget, reason: e.key.name);
        final google = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue with Google'));
        expect(google.style!.backgroundColor!.resolve({}), Calm.acc);
        expect(t.widget<Text>(find.text(e.value.$1)).style!.fontFamily, Calm.serif, reason: 'headings are Fraunces');
        await t.tapAt(const Offset(10, 10));
        await t.pumpAndSettle();
      }
    });

    testWidgets('dismissing the sheet means no, and the action does not run', (t) async {
      var done = 0, refused = 0;
      await pumpProbe(t, FakeAuthRepository(), onDone: () => done++, onRefused: () => refused++);
      await t.pumpAndSettle();
      await tapText(t, 'Do it');
      await t.tapAt(const Offset(10, 10)); // the dimmed area above the sheet
      await t.pumpAndSettle();
      expect((done, refused), (0, 1));
    });
  });

  group('the phone flow', () {
    Future<void> toOtpScreen(WidgetTester t) async {
      await tapText(t, 'Do it');
      await tapText(t, 'Continue with phone number');
      await t.enterText(find.byKey(const Key('phone-field')), '012-345 6789');
      await tapText(t, 'Send code');
    }

    testWidgets('phone_flow_with_test_otp_123456_signs_in, and the pending action then runs once', (t) async {
      final repo = FakeAuthRepository(newUserHasName: true);
      var done = 0;
      await pumpProbe(t, repo, onDone: () => done++);
      await t.pumpAndSettle();
      await toOtpScreen(t);
      expect(repo.sentTo, ['+60123456789']);
      expect(find.text('+60 12 345 6789'), findsOneWidget);

      await t.enterText(find.byKey(const Key('otp-field')), '123456');
      await tapText(t, 'Verify');
      expect(repo.verified, [('+60123456789', '123456')]);
      expect(done, 1); // the sheet closed and the caller carried on, exactly once
      expect(find.text('Verify'), findsNothing);
    });

    testWidgets('wrong_otp_shows_error_and_stays', (t) async {
      final repo = FakeAuthRepository();
      var done = 0;
      await pumpProbe(t, repo, onDone: () => done++);
      await t.pumpAndSettle();
      await toOtpScreen(t);
      await t.enterText(find.byKey(const Key('otp-field')), '000000');
      await tapText(t, 'Verify');
      expect(find.text("That code isn't right. Check it and try again."), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget); // still on the code screen
      expect(done, 0);

      // and the right code still works afterwards
      await t.enterText(find.byKey(const Key('otp-field')), '123456');
      await tapText(t, 'Verify');
      expect(find.text('What should we call you?'), findsOneWidget);
    });

    testWidgets('a number that is not Malaysian is refused before any code is sent', (t) async {
      final repo = FakeAuthRepository();
      await pumpProbe(t, repo, onDone: () {});
      await t.pumpAndSettle();
      await tapText(t, 'Do it');
      await tapText(t, 'Continue with phone number');
      await t.enterText(find.byKey(const Key('phone-field')), '+65 9123 4567');
      await tapText(t, 'Send code');
      expect(find.text('Enter a Malaysian mobile number, like 012 345 6789'), findsOneWidget);
      expect(repo.sentTo, isEmpty);
    });

    testWidgets('a sending failure is shown and the user can try again', (t) async {
      final repo = FakeAuthRepository()..sendError = const AuthException('Too many requests');
      await pumpProbe(t, repo, onDone: () {});
      await t.pumpAndSettle();
      await tapText(t, 'Do it');
      await tapText(t, 'Continue with phone number');
      await t.enterText(find.byKey(const Key('phone-field')), '0123456789');
      await tapText(t, 'Send code');
      expect(find.text("We couldn't send the code. Wait a moment and try again."), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('first_sign_in_asks_for_name_then_continues', (t) async {
      final repo = FakeAuthRepository(); // a brand-new phone user has no name yet
      var done = 0;
      await pumpProbe(t, repo, onDone: () => done++);
      await t.pumpAndSettle();
      await toOtpScreen(t);
      await t.enterText(find.byKey(const Key('otp-field')), '123456');
      await tapText(t, 'Verify');
      expect(find.text('What should we call you?'), findsOneWidget);
      expect(done, 0);

      await tapText(t, 'Continue'); // an empty name is not accepted
      expect(find.text('Please enter your name.'), findsOneWidget);
      expect(repo.names, isEmpty);

      await t.enterText(find.byKey(const Key('name-field')), '  Mei Tan ');
      await tapText(t, 'Continue');
      expect(repo.names, ['Mei Tan']);
      expect(done, 1);
    });

    testWidgets('the user can go back and use a different number', (t) async {
      final repo = FakeAuthRepository();
      await pumpProbe(t, repo, onDone: () {});
      await t.pumpAndSettle();
      await toOtpScreen(t);
      await tapText(t, 'Use a different number');
      expect(find.byKey(const Key('phone-field')), findsOneWidget);
    });
  });

  group('Google', () {
    testWidgets('Continue with Google signs in, a Google user already has a name, and the action runs once', (t) async {
      final repo = FakeAuthRepository();
      var done = 0;
      await pumpProbe(t, repo, onDone: () => done++);
      await t.pumpAndSettle();
      await tapText(t, 'Do it');
      await tapText(t, 'Continue with Google');
      expect(repo.googleCalls, 1);
      expect(find.text('What should we call you?'), findsNothing);
      expect(done, 1);
    });

    testWidgets('a Google failure is explained instead of crashing, and phone still works', (t) async {
      final repo = FakeAuthRepository()..googleError = const GoogleNotConfigured();
      var done = 0;
      await pumpProbe(t, repo, onDone: () => done++);
      await t.pumpAndSettle();
      await tapText(t, 'Do it');
      await tapText(t, 'Continue with Google');
      expect(find.text("Google sign-in isn't set up on this device yet. Use your phone number instead."), findsOneWidget);
      expect(done, 0);
      expect(find.text('Continue with phone number'), findsOneWidget);
    });

    testWidgets('cancelling the Google window is not an error', (t) async {
      final repo = FakeAuthRepository()..googleError = const GoogleCancelled();
      await pumpProbe(t, repo, onDone: () {});
      await t.pumpAndSettle();
      await tapText(t, 'Do it');
      await tapText(t, 'Continue with Google');
      expect(find.textContaining("isn't set up"), findsNothing);
      expect(find.textContaining('went wrong'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  test('needsName: a session without a name asks for one, with a name does not', () {
    expect(needsName(fakeSession()), isTrue);
    expect(needsName(fakeSession(name: '   ')), isTrue);
    expect(needsName(fakeSession(name: 'Mei')), isFalse);
  });
}
