import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/host.dart';
import 'package:jom/features/people/domain/person.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/fake_people.dart';
import '../../helpers/pump_app.dart';

const bob = Person(
  userId: 'u1',
  name: 'Bob Tan',
  username: 'bobtan',
  isHost: false,
);

FakeHost host({List<Guest> guests = const []}) => FakeHost(
  profile: hostMe(),
  events: [
    hostEvent('e1'),
    hostEvent('e2'),
    hostEvent('e3', sold: 12, cap: 12),
  ],
  guestRows: [...guests],
);

Future<void> findBob(WidgetTester t) async {
  await t.enterText(key('assign-search'), 'bo');
  await t.pump(const Duration(milliseconds: 400));
  await t.pumpAndSettle();
  await t.tap(key('assign-person-u1'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('search_results_show_name_handle_and_avatar_only', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/assign-seat?eventId=e1',
      host: host(),
      people: FakePeople(people: [bob]),
    );
    await t.enterText(key('assign-search'), 'bo');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('Bob Tan'), findsOneWidget);
    expect(find.text('@bobtan'), findsOneWidget);
  });

  testWidgets('assign_calls_repository_with_the_chosen_values', (t) async {
    final h = host();
    await pumpApp(
      t,
      location: '/host-mode/assign-seat?eventId=e1',
      host: h,
      people: FakePeople(people: [bob]),
    );
    await findBob(t);
    await t.tap(key('assign-people-2'));
    await t.pumpAndSettle();
    await t.tap(key('assign-confirm'));
    await t.pumpAndSettle();
    expect(h.assigned, [('e1', 'u1', 2, null, false)]);
  });

  testWidgets('choose_another_event_of_the_host', (t) async {
    final h = host();
    await pumpApp(
      t,
      location: '/host-mode/assign-seat?eventId=e1',
      host: h,
      people: FakePeople(people: [bob]),
    );
    await findBob(t);
    await t.tap(key('assign-event'));
    await t.pumpAndSettle();
    await t.tap(find.text('Event e2').last);
    await t.pumpAndSettle();
    await t.tap(key('assign-confirm'));
    await t.pumpAndSettle();
    expect(h.assigned.single.$1, 'e2');
  });

  testWidgets('over_capacity_switch_only_appears_when_the_event_is_full', (
    t,
  ) async {
    await pumpApp(
      t,
      location: '/host-mode/assign-seat?eventId=e1',
      host: host(),
      people: FakePeople(people: [bob]),
    );
    expect(key('assign-over-capacity'), findsNothing);
    await pumpApp(
      t,
      location: '/host-mode/assign-seat?eventId=e3',
      host: host(),
      people: FakePeople(people: [bob]),
    );
    expect(key('assign-over-capacity'), findsOneWidget);
  });

  testWidgets(
    'full_event_without_switch_shows_event_full_message_and_with_it_assigns',
    (t) async {
      final h = host();
      await pumpApp(
        t,
        location: '/host-mode/assign-seat?eventId=e3',
        host: h,
        people: FakePeople(people: [bob]),
      );
      await findBob(t);
      await t.tap(key('assign-confirm'));
      await t.pumpAndSettle();
      expect(find.textContaining('This event is full'), findsOneWidget);
      expect(h.assigned, isEmpty);
      await t.tap(key('assign-over-capacity'));
      await t.pumpAndSettle();
      await t.tap(key('assign-confirm'));
      await t.pumpAndSettle();
      expect(h.assigned, [('e3', 'u1', 1, null, true)]);
    },
  );

  testWidgets('late_receipt_can_be_linked', (t) async {
    final h = host();
    await pumpApp(
      t,
      location: '/host-mode/assign-seat?eventId=e1&userId=u1&receiptId=r9',
      host: h,
      people: FakePeople(people: [bob]),
    );
    expect(find.text('Bob Tan'), findsOneWidget);
    await t.tap(key('assign-confirm'));
    await t.pumpAndSettle();
    expect(h.assigned, [('e1', 'u1', 1, 'r9', false)]);
  });

  testWidgets('refund_needs_a_note_and_calls_repository', (t) async {
    final h = host(
      guests: [
        const Guest(
          bookingId: 'b1',
          name: 'Guest 1',
          people: 1,
          code: 'KLS-1',
          checkedIn: false,
        ),
      ],
    );
    await pumpApp(t, location: '/host-mode/events/e1/guests', host: h);
    await t.tap(key('refund-b1'));
    await t.pumpAndSettle();
    await t.tap(key('refund-confirm'));
    await t.pumpAndSettle();
    expect(find.text('Write a short note for your records.'), findsOneWidget);
    expect(h.refunded, isEmpty);
    await t.enterText(key('refund-note'), 'Refunded by bank');
    await t.tap(key('refund-confirm'));
    await t.pumpAndSettle();
    expect(h.refunded, [('b1', 'Refunded by bank')]);
  });

  testWidgets('refund_not_offered_for_checked_in_guests', (t) async {
    final h = host(
      guests: [
        const Guest(
          bookingId: 'b1',
          name: 'Guest 1',
          people: 1,
          code: 'KLS-1',
          checkedIn: true,
        ),
      ],
    );
    await pumpApp(t, location: '/host-mode/events/e1/guests', host: h);
    expect(key('refund-b1'), findsNothing);
  });
}
