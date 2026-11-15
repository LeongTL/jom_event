import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/chat/domain/chat.dart';
import 'package:jom/features/people/domain/person.dart';
import 'package:jom/features/safety/data/safety_repository.dart';
import 'package:jom/features/safety/domain/safety.dart';

import '../../helpers/fake_chat.dart';
import '../../helpers/fake_events.dart';
import '../../helpers/fake_people.dart';
import '../../helpers/fake_safety.dart';
import '../../helpers/pump_app.dart';

const _guest = Person(
  userId: 'g1',
  name: 'Bob Lim',
  username: 'bob.lim',
  isHost: false,
);

List<Never> get _none => const [];

void main() {
  testWidgets('person_menu_offers_report_and_block', (t) async {
    final safety = FakeSafety();
    await pumpApp(
      t,
      location: '/people/g1',
      people: FakePeople(people: [_guest]),
      overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
    );
    await t.tap(key('person-menu'));
    await t.pumpAndSettle();
    expect(key('menu-report'), findsOneWidget);
    expect(key('menu-block'), findsOneWidget);
  });

  testWidgets('reporting_a_person_sends_the_reason_and_says_thanks', (t) async {
    final safety = FakeSafety();
    await pumpApp(
      t,
      location: '/people/g1',
      people: FakePeople(people: [_guest]),
      overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
    );
    await t.tap(key('person-menu'));
    await t.pumpAndSettle();
    await t.tap(key('menu-report'));
    await t.pumpAndSettle();
    expect(find.byType(FilledButton), findsWidgets);
    await t.tap(key('report-reason-harassment'));
    await t.pumpAndSettle();
    await t.tap(key('report-submit'));
    await t.pumpAndSettle();
    expect(safety.reports, [
      (ReportTarget.user, 'g1', ReportReason.harassment, null),
    ]);
    expect(find.text('Thanks, we will look at it.'), findsOneWidget);
  });

  testWidgets('submit_waits_for_a_reason', (t) async {
    final safety = FakeSafety();
    await pumpApp(
      t,
      location: '/people/g1',
      people: FakePeople(people: [_guest]),
      overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
    );
    await t.tap(key('person-menu'));
    await t.pumpAndSettle();
    await t.tap(key('menu-report'));
    await t.pumpAndSettle();
    await t.tap(key('report-submit'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(safety.reports, isEmpty);
  });

  testWidgets('blocking_asks_first_then_blocks_and_leaves_the_page', (t) async {
    final safety = FakeSafety();
    final router = await pumpApp(
      t,
      location: '/people/g1',
      people: FakePeople(people: [_guest]),
      overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
    );
    await t.tap(key('person-menu'));
    await t.pumpAndSettle();
    await t.tap(key('menu-block'));
    await t.pumpAndSettle();
    expect(find.text('Block Bob Lim?'), findsOneWidget);
    expect(safety.blocks, isEmpty);
    await t.tap(key('block-confirm'));
    await t.pumpAndSettle();
    expect(safety.blocks, ['g1']);
    expect(where(router), '/explore');
  });

  testWidgets('cancelling_the_block_changes_nothing', (t) async {
    final safety = FakeSafety();
    await pumpApp(
      t,
      location: '/people/g1',
      people: FakePeople(people: [_guest]),
      overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
    );
    await t.tap(key('person-menu'));
    await t.pumpAndSettle();
    await t.tap(key('menu-block'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(safety.blocks, isEmpty);
    expect(key('person-screen'), findsOneWidget);
  });

  testWidgets('event_page_can_report_but_not_block', (t) async {
    final safety = FakeSafety();
    await pumpApp(
      t,
      location: '/event/e1',
      events: FakeEvents(
        details: {'e1': detailOf(sum('e1'), shareCode: 'abc')},
      ),
      overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
    );
    await t.tap(key('event-menu'));
    await t.pumpAndSettle();
    expect(key('menu-block'), findsNothing);
    await t.tap(key('event-report'));
    await t.pumpAndSettle();
    await t.tap(key('report-reason-fake_event'));
    await t.pumpAndSettle();
    await t.tap(key('report-submit'));
    await t.pumpAndSettle();
    expect(safety.reports, [
      (ReportTarget.event, 'e1', ReportReason.fakeEvent, null),
    ]);
  });

  testWidgets(
    'chat_header_blocks_the_other_side_and_a_message_can_be_reported',
    (t) async {
      final safety = FakeSafety();
      final chat = FakeChat(
        infos: {
          't1': const ThreadInfo(
            id: 't1',
            iAmHost: false,
            otherName: 'Mei Studio',
            otherId: 'h1',
          ),
        },
        messages: {
          't1': [msg('m1', 'h1', 'See you there', DateTime.utc(2030, 1, 8, 6))],
        },
      );
      final router = await pumpApp(
        t,
        location: '/chats/t1',
        chat: chat,
        overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
      );
      await t.longPress(key('bubble-m1'));
      await t.pumpAndSettle();
      await t.tap(key('report-reason-spam'));
      await t.pumpAndSettle();
      await t.tap(key('report-submit'));
      await t.pumpAndSettle();
      expect(safety.reports, [
        (ReportTarget.message, 'm1', ReportReason.spam, null),
      ]);
      await t.tap(key('chat-menu'));
      await t.pumpAndSettle();
      await t.tap(key('menu-block'));
      await t.pumpAndSettle();
      await t.tap(key('block-confirm'));
      await t.pumpAndSettle();
      expect(safety.blocks, ['h1']);
      expect(where(router), isNot('/chats/t1'));
    },
  );

  testWidgets('blocked_users_lists_them_and_unblock_removes_the_row', (
    t,
  ) async {
    final safety = FakeSafety(
      blockedUsers: [
        BlockedUser(
          userId: 'g1',
          name: 'Bob Lim',
          username: 'bob.lim',
          blockedAt: DateTime.utc(2030, 1, 1),
        ),
      ],
    );
    await pumpApp(
      t,
      location: '/profile',
      overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
    );
    await t.ensureVisible(key('profile-blocked-users'));
    await t.tap(key('profile-blocked-users'));
    await t.pumpAndSettle();
    expect(find.text('Bob Lim'), findsOneWidget);
    await t.tap(key('unblock-g1'));
    await t.pumpAndSettle();
    expect(safety.unblocks, ['g1']);
    expect(find.text('You have not blocked anyone.'), findsOneWidget);
  });

  testWidgets('blocked_users_empty_state', (t) async {
    await pumpApp(
      t,
      location: '/blocked-users',
      overrides: [safetyRepositoryProvider.overrideWithValue(FakeSafety())],
    );
    expect(find.text('You have not blocked anyone.'), findsOneWidget);
    expect(_none, isEmpty);
  });
}
