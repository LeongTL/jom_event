import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/people/domain/person.dart';

import '../../helpers/fake_people.dart';
import '../../helpers/pump_app.dart';

bool saveEnabled(WidgetTester t) =>
    t
        .widget<FilledButton>(
          find.descendant(
            of: key('username-save'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

Future<void> type(WidgetTester t, String text) async {
  await t.enterText(key('username-field'), text);
  await t.pump(const Duration(milliseconds: 400)); // past the typing pause
  await t.pump();
}

String status(WidgetTester t) => t.widget<Text>(key('username-status')).data!;

void main() {
  testWidgets('field_starts_with_current_username', (t) async {
    await pumpApp(t, location: '/edit-username');
    expect(
      t.widget<TextField>(key('username-field')).controller!.text,
      'meitan1234',
    );
  });

  testWidgets('save_is_disabled_while_the_name_is_unchanged', (t) async {
    await pumpApp(t, location: '/edit-username');
    expect(saveEnabled(t), isFalse);
  });

  testWidgets('typing_checks_availability_live', (t) async {
    final people = FakePeople(taken: {'dave'});
    await pumpApp(t, location: '/edit-username', people: people);
    await type(t, 'MeiFree');
    expect(people.availabilityAsked, ['meifree']);
    expect(status(t), '@meifree is available');
    expect(saveEnabled(t), isTrue);
    await type(t, 'dave');
    expect(status(t), 'Someone already has that username.');
    expect(saveEnabled(t), isFalse);
  });

  for (final bad in ['ab', 'a..b', '.abc', 'abc.', 'a b']) {
    // (too long cannot be typed: the field stops at 20)
    testWidgets('invalid_"$bad"_disables_save_without_asking_the_server', (
      t,
    ) async {
      final people = FakePeople();
      await pumpApp(t, location: '/edit-username', people: people);
      await type(t, bad);
      expect(saveEnabled(t), isFalse);
      expect(status(t), contains('3 to 20'));
      expect(people.availabilityAsked, isEmpty);
    });
  }

  for (final code in [
    'username_taken',
    'username_reserved',
    'username_invalid',
  ]) {
    testWidgets('server_error_${code}_shows_its_message', (t) async {
      final error = UsernameError(code);
      await pumpApp(
        t,
        location: '/edit-username',
        people: FakePeople(setError: error),
      );
      await type(t, 'meifree');
      await t.tap(key('username-save'));
      await t.pumpAndSettle();
      expect(find.text(error.message), findsOneWidget);
      expect(key('edit-username-screen'), findsOneWidget); // stays open
    });
  }

  testWidgets('save_closes_the_screen_and_profile_shows_the_new_name', (
    t,
  ) async {
    final people = FakePeople();
    final router = await pumpApp(t, location: '/profile', people: people);
    expect(find.text('@meitan1234'), findsOneWidget);
    await t.tap(find.text('Edit username'));
    await t.pumpAndSettle();
    expect(where(router), '/edit-username');
    await type(t, 'meifree');
    await t.tap(key('username-save'));
    await t.pumpAndSettle();
    expect(where(router), '/profile');
    expect(find.text('@meifree'), findsOneWidget);
  });
}
