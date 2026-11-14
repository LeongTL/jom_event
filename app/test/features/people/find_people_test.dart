import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/people/domain/person.dart';

import '../../helpers/fake_people.dart';
import '../../helpers/pump_app.dart';

const _host = Person(
  userId: 'h1',
  name: 'Studio Dave',
  username: 'dave.host',
  isHost: true,
);
const _guest = Person(
  userId: 'g1',
  name: 'Bob Lim',
  username: 'bob.lim',
  isHost: false,
);

Future<void> search(WidgetTester t, String q) async {
  await t.enterText(key('people-search'), q);
  await t.pump(const Duration(milliseconds: 400)); // past the typing pause
  await t.pumpAndSettle();
}

void main() {
  testWidgets('search_waits_for_two_characters', (t) async {
    final people = FakePeople(people: [_host, _guest]);
    await pumpApp(t, location: '/people', people: people);
    await search(t, 'b');
    expect(people.searches, isEmpty);
    await search(t, 'bo');
    expect(people.searches, ['bo']);
  });

  testWidgets('results_show_name_and_username', (t) async {
    await pumpApp(
      t,
      location: '/people',
      people: FakePeople(people: [_host, _guest]),
    );
    await search(t, 'bo');
    expect(find.text('Bob Lim'), findsOneWidget);
    expect(find.text('@bob.lim'), findsOneWidget);
    expect(find.text('Studio Dave'), findsNothing);
  });

  testWidgets('tapping_a_host_opens_the_host_page_and_a_guest_a_person_page', (
    t,
  ) async {
    final router = await pumpApp(
      t,
      location: '/people',
      people: FakePeople(people: [_host, _guest]),
    );
    await search(t, 'dave');
    await t.tap(key('person-h1'));
    await t.pumpAndSettle();
    expect(where(router), '/host/h1');
    router.pop();
    await t.pumpAndSettle();
    await search(t, 'bob');
    await t.tap(key('person-g1'));
    await t.pumpAndSettle();
    expect(where(router), '/people/g1');
  });

  testWidgets('no_results_says_so', (t) async {
    await pumpApp(t, location: '/people', people: FakePeople());
    await search(t, 'zz');
    expect(find.text('No one found'), findsOneWidget);
  });
}
