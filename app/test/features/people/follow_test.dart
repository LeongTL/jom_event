import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/people/domain/person.dart';

import '../../helpers/fake_auth.dart';
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
const _me = Person(
  userId: 'u1',
  name: 'Mei Tan',
  username: 'meitan1234',
  isHost: false,
);

void main() {
  testWidgets('follow_button_toggles_and_updates_the_count', (t) async {
    final people = FakePeople(people: [_guest]);
    await pumpApp(t, location: '/people/g1', people: people);
    expect(find.text('Bob Lim'), findsOneWidget);
    expect(find.text('@bob.lim'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('0 Followers'), findsOneWidget);
    await t.tap(key('follow-button'));
    await t.pumpAndSettle();
    expect(people.followed, ['g1']);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('1 Followers'), findsOneWidget);
    await t.tap(key('follow-button'));
    await t.pumpAndSettle();
    expect(people.unfollowed, ['g1']);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('0 Followers'), findsOneWidget);
  });

  testWidgets('signed_out_follow_opens_the_sign_in_sheet', (t) async {
    final people = FakePeople(people: [_guest]);
    await pumpApp(
      t,
      location: '/people/g1',
      people: people,
      auth: FakeAuthRepository(),
    );
    await t.tap(key('follow-button'));
    await t.pumpAndSettle();
    expect(find.text('Sign in to follow'), findsOneWidget);
    expect(people.followed, isEmpty);
  });

  testWidgets('double_tap_calls_follow_once', (t) async {
    final people = FakePeople(
      people: [_guest],
      followDelay: const Duration(milliseconds: 200),
    );
    await pumpApp(t, location: '/people/g1', people: people);
    await t.tap(key('follow-button'));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(key('follow-button'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(people.followed, ['g1']);
    expect(people.unfollowed, isEmpty);
  });

  testWidgets('no_follow_button_on_my_own_page', (t) async {
    await pumpApp(
      t,
      location: '/people/u1',
      people: FakePeople(people: [_me]),
    );
    expect(find.text('Mei Tan'), findsOneWidget);
    expect(key('follow-button'), findsNothing);
  });

  testWidgets('a_host_id_on_the_person_route_opens_the_host_page', (t) async {
    final router = await pumpApp(
      t,
      location: '/people/h1',
      people: FakePeople(people: [_host]),
    );
    expect(where(router), '/host/h1');
  });

  testWidgets('person_page_for_an_unknown_id_says_so', (t) async {
    await pumpApp(t, location: '/people/nobody', people: FakePeople());
    expect(find.text('This profile is not available.'), findsOneWidget);
  });

  testWidgets('counts_open_the_follower_and_following_lists', (t) async {
    final people = FakePeople(
      people: [_guest],
      followersOf: {
        'g1': [_host],
      },
      followingOf: {
        'g1': [_me],
      },
    );
    final router = await pumpApp(t, location: '/people/g1', people: people);
    await t.tap(key('person-followers'));
    await t.pumpAndSettle();
    expect(where(router), '/people/g1/followers');
    expect(find.text('Studio Dave'), findsOneWidget);
    expect(find.text('@dave.host'), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    await t.tap(key('person-following'));
    await t.pumpAndSettle();
    expect(where(router), '/people/g1/following');
    expect(find.text('Mei Tan'), findsOneWidget);
  });

  testWidgets('lists_show_a_page_and_load_more', (t) async {
    final many = [
      for (var i = 0; i < 25; i++)
        Person(
          userId: 'x$i',
          name: 'Person $i',
          username: 'person$i',
          isHost: false,
        ),
    ];
    await pumpApp(
      t,
      location: '/people/g1/followers',
      people: FakePeople(people: [_guest], followersOf: {'g1': many}),
    );
    expect(find.byType(ListTile), findsNothing); // rows are our own widgets
    expect(find.textContaining('Person '), findsNWidgets(20));
    await t.tap(key('list-more'));
    await t.pumpAndSettle();
    expect(find.textContaining('Person '), findsNWidgets(25));
    expect(key('list-more'), findsNothing);
  });

  testWidgets('empty_list_says_nobody_yet', (t) async {
    await pumpApp(
      t,
      location: '/people/g1/followers',
      people: FakePeople(people: [_guest]),
    );
    expect(find.text('Nobody yet'), findsOneWidget);
  });
}
