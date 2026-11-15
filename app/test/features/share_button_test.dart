import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/people/domain/person.dart';
import 'package:jom/features/reviews/domain/review.dart';
import 'package:jom/shared/share_sheet.dart';

import '../helpers/fake_events.dart';
import '../helpers/fake_people.dart';
import '../helpers/fake_reviews.dart';
import '../helpers/pump_app.dart';

const base = 'https://share.example.invalid';

void main() {
  late List<String> sent;

  setUp(() => sent = []);

  List<dynamic> overrides({String shareBase = base}) => [
    shareProvider.overrideWithValue((message) async => sent.add(message)),
    shareBaseUrlProvider.overrideWithValue(shareBase),
  ];

  testWidgets('the event page sends the title, date, area and the https link', (
    t,
  ) async {
    await pumpApp(
      t,
      location: '/event/e1',
      events: FakeEvents(
        all: [sum('e1', title: 'Sunset yoga')],
        details: {
          'e1': detailOf(
            sum('e1', title: 'Sunset yoga'),
            shareCode: 'abCD12efGH',
          ),
        },
      ),
      overrides: [...overrides()],
    );
    await t.tap(key('hero-share'));
    await t.pumpAndSettle();
    expect(sent, [
      'Sunset yoga · Sat 12 Jan · 9:00 AM · Bangsar\n$base/e/abCD12efGH',
    ]);
  });

  testWidgets('with no domain set the event link is the app link', (t) async {
    await pumpApp(
      t,
      location: '/event/e1',
      events: FakeEvents(
        all: [sum('e1')],
        details: {'e1': detailOf(sum('e1'), shareCode: 'abCD12efGH')},
      ),
      overrides: [...overrides(shareBase: '')],
    );
    await t.tap(key('hero-share'));
    await t.pumpAndSettle();
    expect(sent.single, endsWith('\njom://e/abCD12efGH'));
  });

  testWidgets('an event with no code has no share button', (t) async {
    await pumpApp(
      t,
      location: '/event/e1',
      events: FakeEvents(
        all: [sum('e1')],
        details: {'e1': detailOf(sum('e1'))},
      ),
      overrides: [...overrides()],
    );
    expect(key('hero-share'), findsNothing);
  });

  testWidgets('a person page sends their name and the /u link', (t) async {
    await pumpApp(
      t,
      location: '/people/p1',
      people: FakePeople(
        people: const [
          Person(
            userId: 'p1',
            name: 'Gus Tan',
            username: 'gustan',
            isHost: false,
          ),
        ],
      ),
      overrides: [...overrides()],
    );
    await t.tap(key('person-share'));
    await t.pumpAndSettle();
    expect(sent, ['Gus Tan · @gustan\n$base/u/gustan']);
  });

  testWidgets('a host page sends the host name and the /u link', (t) async {
    await pumpApp(
      t,
      location: '/host/h1',
      reviews: FakeReviews(
        hosts: {
          'h1': HostPublic(
            name: 'Mei Studio',
            since: DateTime.utc(2029),
            verified: true,
            ratingCount: 0,
            guests: 0,
            upcoming: const [],
            reviews: const [],
          ),
        },
      ),
      people: FakePeople(
        people: const [
          Person(
            userId: 'h1',
            name: 'Mei Studio',
            username: 'meistudio',
            isHost: true,
          ),
        ],
      ),
      overrides: [...overrides()],
    );
    await t.tap(key('host-share'));
    await t.pumpAndSettle();
    expect(sent, ['Mei Studio · @meistudio\n$base/u/meistudio']);
  });
}
