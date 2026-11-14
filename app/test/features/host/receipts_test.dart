import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/host.dart';
import 'package:jom/features/host/domain/receipt.dart';

import '../../helpers/fake_events.dart';
import '../../helpers/fake_host.dart';
import '../../helpers/pump_app.dart';

PendingReceipt receipt(
  String id, {
  String event = 'e1',
  bool late = false,
  int n = 1,
}) => PendingReceipt(
  id: id,
  bookingId: 'b$id',
  eventId: event,
  eventTitle: 'Event $event',
  guestId: 'u$n',
  guestName: 'Bob Tan',
  guestUsername: 'bobtan',
  amountSen: 3000,
  imagePath: 'b$id/a.jpg',
  late: late,
  uploadedAt: clock,
);

FakeHost host(List<PendingReceipt> receipts) => FakeHost(
  profile: hostMe(),
  events: [hostEvent('e1'), hostEvent('e2')],
  receipts: receipts,
);

void main() {
  testWidgets('host_home_shows_pending_count_and_opens_list', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/home',
      host: host([receipt('r1'), receipt('r2', event: 'e2')]),
    );
    expect(find.text('2 receipts to check'), findsOneWidget);
    await t.tap(key('pending-receipts-card'));
    await t.pumpAndSettle();
    expect(key('receipts-screen'), findsOneWidget);
    expect(key('receipt-row-r1'), findsOneWidget);
    expect(key('receipt-row-r2'), findsOneWidget);
  });

  testWidgets('event_page_lists_its_pending_receipts', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/events/e1',
      host: host([receipt('r1'), receipt('r2', event: 'e2')]),
    );
    expect(find.text('1 receipt to check'), findsOneWidget);
    await t.tap(key('pending-receipts-card'));
    await t.pumpAndSettle();
    expect(key('receipt-row-r1'), findsOneWidget);
    expect(key('receipt-row-r2'), findsNothing);
  });

  testWidgets('guest_list_shows_the_same_banner', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/events/e1/guests',
      host: host([receipt('r1')]),
    );
    expect(key('pending-receipts-card'), findsOneWidget);
  });

  testWidgets('late_receipts_are_marked_late', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/receipts',
      host: host([receipt('r1', late: true), receipt('r2')]),
    );
    expect(
      find.descendant(of: key('receipt-row-r1'), matching: find.text('Late')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: key('receipt-row-r2'), matching: find.text('Late')),
      findsNothing,
    );
  });

  testWidgets('list_empty_state', (t) async {
    await pumpApp(t, location: '/host-mode/receipts', host: host([]));
    expect(find.text('No receipts waiting'), findsOneWidget);
  });

  testWidgets('detail_shows_image_amount_name_and_username', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/receipts/r1',
      host: host([receipt('r1')]),
    );
    expect(key('receipt-image'), findsOneWidget);
    expect(find.text('Bob Tan'), findsOneWidget);
    expect(find.text('@bobtan'), findsOneWidget);
    expect(find.textContaining('RM 30'), findsWidgets);
  });

  testWidgets('accept_confirms_and_returns_to_list', (t) async {
    final h = host([receipt('r1')]);
    await pumpApp(t, location: '/host-mode/receipts', host: h);
    await t.tap(key('receipt-row-r1'));
    await t.pumpAndSettle();
    await t.tap(key('receipt-accept'));
    await t.pumpAndSettle();
    expect(h.accepted, ['r1']);
    expect(key('receipts-screen'), findsOneWidget);
  });

  testWidgets('ask_again_requires_a_note_and_calls_the_repository', (t) async {
    final h = host([receipt('r1')]);
    await pumpApp(t, location: '/host-mode/receipts/r1', host: h);
    await t.tap(key('receipt-ask'));
    await t.pumpAndSettle();
    expect(find.text('Write a short note for the guest.'), findsOneWidget);
    expect(h.asked, isEmpty);
    await t.enterText(key('receipt-note'), 'Amount was short');
    await t.tap(key('receipt-ask'));
    await t.pumpAndSettle();
    expect(h.asked, [('br1', 'Amount was short')]);
  });

  testWidgets('ask_again_error_bookings_closed_shows_message', (t) async {
    final h = host([receipt('r1')])
      ..askError = const HostError('bookings_closed');
    await pumpApp(t, location: '/host-mode/receipts/r1', host: h);
    await t.enterText(key('receipt-note'), 'again please');
    await t.tap(key('receipt-ask'));
    await t.pumpAndSettle();
    expect(find.textContaining('less than an hour'), findsOneWidget);
    expect(key('receipt-image'), findsOneWidget);
  });
}
