import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/host.dart';
import 'package:jom/features/host/domain/scan_controller.dart';
import 'package:jom/features/host/presentation/scan_screen.dart';

import '../../helpers/fake_events.dart';
import '../../helpers/fake_host.dart';
import '../../helpers/pump_app.dart';

const fees = Earnings(
  gross: 36000,
  gateway: 540,
  platform: 3600,
  receives: 31860,
);

Guest guest(int n, {bool checked = false, int people = 1}) => Guest(
  bookingId: 'b$n',
  name: 'Guest $n',
  people: people,
  code: 'KLS-0000$n',
  checkedIn: checked,
);

// an event that finished an hour ago, so it can be completed
HostEventRow over({String status = 'published'}) => hostEvent(
  'e1',
  sold: 12,
  cap: 12,
  starts: clock.subtract(const Duration(hours: 3)),
)..toString();

HostEventRow ended() {
  final e = over();
  return HostEventRow(
    id: e.id,
    title: e.title,
    categories: e.categories,
    area: e.area,
    venue: e.venue,
    startsAt: e.startsAt,
    endsAt: e.endsAt,
    capacity: e.capacity,
    priceSen: e.priceSen,
    status: 'ended',
    seatsSold: e.seatsSold,
  );
}

/// A camera stand-in the test drives by hand.
class FakeCamera {
  late ValueChanged<String> onCode;
  late VoidCallback onUnavailable;
  Widget build(
    BuildContext c, {
    required ValueChanged<String> onCode,
    required VoidCallback onUnavailable,
  }) {
    this.onCode = onCode;
    this.onUnavailable = onUnavailable;
    return const SizedBox(key: Key('fake-camera'), height: 200);
  }
}

Future<(FakeHost, FakeCamera)> pumpScan(
  WidgetTester t,
  List<Object> replies,
) async {
  final host = FakeHost(
    profile: hostMe(),
    events: [hostEvent('e1', sold: 12, cap: 12)],
    guestRows: [guest(1, checked: true, people: 2), guest(2, people: 10)],
    scanReplies: replies,
  );
  final cam = FakeCamera();
  await pumpApp(
    t,
    location: '/host-mode/events/e1/scan',
    host: host,
    overrides: [scannerBuilderProvider.overrideWithValue(cam.build)],
  );
  return (host, cam);
}

Future<void> scan(WidgetTester t, FakeCamera cam, String code) async {
  cam.onCode(code);
  await t.pump();
  await t.pump();
}

void main() {
  group('event details', () {
    testWidgets(
      'event_details_shows_fill_bar_tiles_and_expected_payout_RM318_60_for_12_paid',
      (t) async {
        await pumpApp(
          t,
          location: '/host-mode/events/e1',
          host: FakeHost(
            profile: hostMe(),
            events: [hostEvent('e1', sold: 12, cap: 12)],
            guestRows: [
              guest(1, checked: true, people: 5),
              guest(2, people: 7),
            ],
            earn: fees,
          ),
        );
        expect(find.text('Event e1'), findsOneWidget);
        expect(
          t
              .widget<FractionallySizedBox>(
                find.descendant(
                  of: key('fill-bar'),
                  matching: find.byType(FractionallySizedBox),
                ),
              )
              .widthFactor,
          1,
        );
        expect(find.text('Full'), findsOneWidget);
        expect(
          find.descendant(of: key('tile-joined'), matching: find.text('12')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: key('tile-checked'), matching: find.text('5')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: key('tile-gross'), matching: find.text('RM 360')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: key('payout-line'),
            matching: find.textContaining('RM 318.60'),
          ),
          findsOneWidget,
        );
        expect(find.text('Scan tickets'), findsOneWidget);
        expect(find.text('Guest list'), findsOneWidget);
      },
    );

    testWidgets('complete_button_disabled_before_end_time_with_hint', (
      t,
    ) async {
      await pumpApp(
        t,
        location: '/host-mode/events/e1',
        host: FakeHost(
          profile: hostMe(),
          events: [hostEvent('e1')],
          earn: fees,
        ),
      );
      expect(
        t
            .widget<FilledButton>(
              find.descendant(
                of: key('complete-button'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('after it ends'), findsOneWidget);
    });

    testWidgets(
      'complete_sheet_shows_no_show_count_and_calls_complete_then_returns_to_events',
      (t) async {
        final host = FakeHost(
          profile: hostMe(),
          events: [over()],
          earn: fees,
          guestRows: [guest(1, checked: true), guest(2), guest(3)],
        );
        final router = await pumpApp(
          t,
          location: '/host-mode/events/e1',
          host: host,
        );
        await t.tap(key('complete-button'));
        await t.pumpAndSettle();
        expect(
          find.textContaining('2 guests did not check in'),
          findsOneWidget,
        );
        await t.tap(key('complete-yes'));
        await t.pumpAndSettle();
        expect(host.completed, ['e1']);
        expect(where(router), '/host-mode/events');
      },
    );
  });

  group('scanner', () {
    testWidgets(
      'scan_valid_code_shows_green_card_with_name_people_and_ticket_code_and_counter_increments',
      (t) async {
        final (_, cam) = await pumpScan(t, [
          const ScanResult(
            ScanKind.checkedIn,
            name: 'Aina Rahman',
            people: 2,
            code: 'KLS-00042',
          ),
        ]);
        expect(
          find.descendant(
            of: key('scan-counter'),
            matching: find.text('2 / 12'),
          ),
          findsOneWidget,
        );
        await scan(t, cam, 'tok1');
        expect(find.textContaining('Aina Rahman'), findsOneWidget);
        expect(find.textContaining('2 people'), findsOneWidget);
        expect(find.textContaining('KLS-00042'), findsOneWidget);
        expect(find.text('Checked in just now'), findsOneWidget);
        expect(
          find.descendant(
            of: key('scan-counter'),
            matching: find.text('4 / 12'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'scan_same_code_twice_shows_already_with_time_and_counter_unchanged',
      (t) async {
        final (host, cam) = await pumpScan(t, [
          const ScanResult(
            ScanKind.checkedIn,
            name: 'Aina Rahman',
            people: 1,
            code: 'KLS-1',
          ),
          ScanResult(
            ScanKind.already,
            name: 'Aina Rahman',
            people: 1,
            code: 'KLS-1',
            at: DateTime.utc(2030, 1, 9, 1, 2),
          ),
        ]);
        await scan(t, cam, 'tok1');
        await t.pump(const Duration(seconds: 3));
        await scan(t, cam, 'tok1');
        expect(host.scanned, ['tok1', 'tok1']);
        expect(find.text('Already checked in at 9:02 AM'), findsOneWidget);
        expect(
          find.descendant(
            of: key('scan-counter'),
            matching: find.text('3 / 12'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a_camera_held_on_one_ticket_counts_the_guest_once', (t) async {
      final (host, cam) = await pumpScan(t, [
        const ScanResult(
          ScanKind.checkedIn,
          name: 'Aina Rahman',
          people: 2,
          code: 'KLS-1',
        ),
      ]);
      await scan(t, cam, 'tok1');
      await scan(t, cam, 'tok1');
      expect(host.scanned, ['tok1']);
      expect(
        find.descendant(of: key('scan-counter'), matching: find.text('4 / 12')),
        findsOneWidget,
      );
    });

    testWidgets('a_check_in_refreshes_the_guest_list_the_manual_list_reads', (
      t,
    ) async {
      final (host, cam) = await pumpScan(t, [
        const ScanResult(
          ScanKind.checkedIn,
          name: 'Aina Rahman',
          people: 1,
          code: 'KLS-1',
        ),
      ]);
      final before = host.guestCalls;
      await scan(t, cam, 'tok1');
      await t.pump();
      expect(host.guestCalls, greaterThan(before));
      expect(
        find.descendant(of: key('scan-counter'), matching: find.text('3 / 12')),
        findsOneWidget,
      );
    });

    testWidgets('scan_other_event_and_unpaid_and_garbage_show_their_messages', (
      t,
    ) async {
      final (_, cam) = await pumpScan(t, [
        const ScanResult(ScanKind.wrongEvent),
        const ScanResult(ScanKind.notConfirmed, name: 'Late Payer'),
        const ScanResult(ScanKind.invalid),
      ]);
      for (final (code, msg) in [
        ('a', 'This ticket is for another event'),
        ('b', 'This booking is not paid or was cancelled'),
        ('c', 'Not a Jom ticket'),
      ]) {
        await scan(t, cam, code);
        expect(find.text(msg), findsOneWidget);
        await t.pump(const Duration(seconds: 3));
      }
    });

    testWidgets('camera_permission_denied_shows_manual_list_prompt', (t) async {
      final (_, cam) = await pumpScan(t, []);
      cam.onUnavailable();
      await t.pump();
      expect(find.textContaining('Camera is off'), findsOneWidget);
      await t.tap(key('open-manual-list'));
      await t.pumpAndSettle();
      expect(find.text('Check-in'), findsOneWidget);
    });

    testWidgets('no_signal_shows_use_manual_list_message', (t) async {
      final (_, cam) = await pumpScan(t, [Exception('offline')]);
      await scan(t, cam, 'tok1');
      expect(
        find.text('No signal. Use the manual list instead.'),
        findsOneWidget,
      );
    });
  });

  group('manual list', () {
    testWidgets('manual_list_ticks_and_unticks_until_completed', (t) async {
      final host = FakeHost(
        profile: hostMe(),
        events: [hostEvent('e1')],
        guestRows: [guest(1), guest(2, checked: true)],
      );
      await pumpApp(t, location: '/host-mode/events/e1/checkin', host: host);
      expect(
        find.descendant(of: key('checkin-ring'), matching: find.text('1 / 2')),
        findsOneWidget,
      );
      await t.tap(key('guest-b1'));
      await t.pumpAndSettle();
      expect(
        find.descendant(of: key('checkin-ring'), matching: find.text('2 / 2')),
        findsOneWidget,
      );
      await t.tap(key('guest-b1'));
      await t.pumpAndSettle();
      expect(host.ticks, [('b1', true), ('b1', false)]);

      final done = FakeHost(
        profile: hostMe(),
        events: [ended()],
        guestRows: [guest(1)],
      );
      await pumpApp(t, location: '/host-mode/events/e1/checkin', host: done);
      await t.tap(key('guest-b1'));
      await t.pumpAndSettle();
      expect(done.ticks, isEmpty);
    });
  });

  group('payouts', () {
    final row = PayoutRow(
      title: 'Beginner Mat Pilates',
      startsAt: DateTime.utc(2030, 1, 6, 2),
      dueAt: DateTime.utc(2030, 1, 11, 4),
      paid: false,
      earnings: fees,
    );

    testWidgets(
      'payouts_screen_shows_upcoming_paid_out_and_fee_lines_for_each_event',
      (t) async {
        await pumpApp(
          t,
          location: '/host-mode/payouts',
          host: FakeHost(
            profile: hostMe(),
            payoutsView: Payouts(
              upcomingSen: 31860,
              paidSen: 812000,
              rows: [row],
            ),
          ),
        );
        expect(
          find.descendant(
            of: key('payouts-upcoming'),
            matching: find.text('RM 318.60'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: key('payouts-paid'),
            matching: find.text('RM 8120'),
          ),
          findsOneWidget,
        );
        expect(find.text('Beginner Mat Pilates'), findsOneWidget);
        expect(find.text('−RM 5.40'), findsOneWidget);
        expect(find.text('−RM 36'), findsOneWidget);
        expect(
          find.text('RM 318.60'),
          findsNWidgets(2),
        ); // the stat and this event's "You receive"
        expect(find.textContaining('Maybank ••4821'), findsOneWidget);
      },
    );

    testWidgets(
      'payout_account_screen_saves_and_shows_verified_pill_only_when_verified_at_set',
      (t) async {
        final host = FakeHost(profile: hostMe());
        await pumpApp(t, location: '/host-mode/payout-account', host: host);
        expect(find.text('✓ Verified'), findsNothing);
        await t.enterText(key('apply-number'), '999900001111');
        await t.pump();
        await t.tap(key('apply-submit'));
        await t.pumpAndSettle();
        expect(host.applied.single.accountNumber, '999900001111');

        final verified = FakeHost(
          profile: hostMe(verifiedAt: DateTime.utc(2030, 1, 1)),
        );
        await pumpApp(t, location: '/host-mode/payout-account', host: verified);
        expect(find.text('✓ Verified'), findsOneWidget);
      },
    );
  });
}
