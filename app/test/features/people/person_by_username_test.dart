import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/people/domain/person.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_events.dart';
import '../../helpers/fake_people.dart';
import '../../helpers/pump_app.dart';

const gus = Person(
  userId: 'p1',
  name: 'Gus Tan',
  username: 'gustan',
  isHost: false,
);

void main() {
  testWidgets('/u/<username> opens that person', (t) async {
    await pumpApp(
      t,
      location: '/u/gustan',
      people: FakePeople(people: const [gus]),
    );
    expect(key('person-screen'), findsOneWidget);
    expect(find.text('Gus Tan'), findsWidgets);
  });

  testWidgets('the username is not case sensitive', (t) async {
    await pumpApp(
      t,
      location: '/u/GusTan',
      people: FakePeople(people: const [gus]),
    );
    expect(find.text('Gus Tan'), findsWidgets);
  });

  testWidgets('an unknown username says the profile is not available', (
    t,
  ) async {
    await pumpApp(
      t,
      location: '/u/nobody',
      people: FakePeople(people: const [gus]),
    );
    expect(key('person-not-found'), findsOneWidget);
  });

  testWidgets('a signed-out visitor can open the link', (t) async {
    await pumpApp(
      t,
      location: '/u/gustan',
      auth: FakeAuthRepository(),
      people: FakePeople(people: const [gus]),
    );
    expect(key('person-not-found'), findsNothing);
  });

  testWidgets('an event link with a trailing slash still opens the event', (
    t,
  ) async {
    final d = detailOf(
      sum('e1', title: 'Sunset yoga'),
      shareCode: 'abCD12efGH',
    );
    await pumpApp(
      t,
      location: '/e/abCD12efGH/',
      events: FakeEvents(
        all: [sum('e1')],
        details: {'e1': d},
        codes: {'abCD12efGH': d},
      ),
    );
    expect(find.text('Sunset yoga'), findsWidgets);
  });

  testWidgets('a wrong event code shows the not-found screen', (t) async {
    await pumpApp(t, location: '/e/NOPE', events: FakeEvents());
    expect(key('event-not-found'), findsOneWidget);
  });
}
