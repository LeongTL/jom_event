import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/host.dart';

import '../../helpers/fake_events.dart';
import '../../helpers/fake_host.dart';
import '../../helpers/pump_app.dart';

HostDashboard dash() => HostDashboard(
  profile: hostMe(),
  upcomingPayoutSen: 31860,
  guests: 14,
  next: hostEvent('e1', sold: 8, cap: 12),
);

bool enabled(WidgetTester t, String k) =>
    t
        .widget<FilledButton>(
          find.descendant(of: key(k), matching: find.byType(FilledButton)),
        )
        .onPressed !=
    null;

// the three OK taps of the When field: date, start time, end time (defaults: tomorrow, 18:00 to 20:00)
Future<void> pickWhen(WidgetTester t) async {
  await t.tap(key('field-when'));
  for (var i = 0; i < 3; i++) {
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
  }
  await t.pumpAndSettle();
}

Future<void> fillValid(WidgetTester t) async {
  await t.enterText(key('form-title'), 'Sunset yoga');
  await t.enterText(key('form-venue'), 'Deck 5');
  await t.tap(key('form-area-Bangsar'));
  await pickWhen(t);
}

void main() {
  group('apply', () {
    testWidgets(
      'first_switch_to_host_opens_apply_with_payout_account_and_optional_ssm',
      (t) async {
        final host = FakeHost(profile: null);
        final router = await pumpApp(t, location: '/profile', host: host);
        await t.tap(key('host-mode-card'));
        await t.pumpAndSettle();
        expect(where(router), '/host-mode/apply');
        expect(find.text('Business registration (optional)'), findsOneWidget);
        expect(enabled(t, 'apply-submit'), isFalse);
        await t.enterText(key('apply-name'), 'Mei Studio');
        await t.tap(key('apply-area-Bangsar'));
        await t.enterText(key('apply-holder'), 'Mei Tan');
        await t.enterText(key('apply-bank'), 'Maybank');
        await t.enterText(key('apply-number'), '1234564821');
        await t.pump();
        expect(enabled(t, 'apply-submit'), isTrue);
        await t.tap(key('apply-submit'));
        await t.pumpAndSettle();
        expect(host.applied.single.holder, 'Mei Tan');
        expect(host.applied.single.ssm, isNull);
        expect(where(router), '/host-mode/home');
      },
    );

    testWidgets('a_host_goes_straight_to_the_dashboard', (t) async {
      final router = await pumpApp(t, location: '/profile');
      await t.tap(key('host-mode-card'));
      await t.pumpAndSettle();
      expect(where(router), '/host-mode/home');
    });
  });

  group('dashboard and list', () {
    testWidgets('host_home_shows_payout_card_next_event_fill_bar_and_tiles', (
      t,
    ) async {
      await pumpApp(
        t,
        location: '/host-mode/home',
        host: FakeHost(profile: hostMe(), dash: dash()),
      );
      expect(find.text('Mei Studio'), findsOneWidget);
      expect(find.text('HOST'), findsOneWidget);
      expect(
        find.descendant(
          of: key('payout-card'),
          matching: find.text('RM 318.60'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('payout-card'),
          matching: find.textContaining('Maybank ••4821'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key('next-event'), matching: find.text('Event e1')),
        findsOneWidget,
      );
      expect(
        t
            .widget<FractionallySizedBox>(
              find.descendant(
                of: key('fill-bar'),
                matching: find.byType(FractionallySizedBox),
              ),
            )
            .widthFactor,
        closeTo(8 / 12, .001),
      );
      expect(find.text('8 of 12 paid · 4 spots left'), findsOneWidget);
      expect(find.text('Guest list'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(
        find.descendant(of: key('tile-guests'), matching: find.text('14')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key('tile-rating'), matching: find.text('4.8 ★')),
        findsOneWidget,
      );
    });

    testWidgets(
      'events_tabs_draft_published_ended_list_cards_with_paid_over_spots_pill',
      (t) async {
        final host = FakeHost(
          profile: hostMe(),
          events: [
            hostEvent('e1'),
            hostEvent('d1', status: 'draft', sold: 0),
            hostEvent('x1', status: 'ended', sold: 12),
          ],
        );
        final router = await pumpApp(
          t,
          location: '/host-mode/events',
          host: host,
        );
        expect(
          find.descendant(
            of: key('host-event-e1'),
            matching: find.text('8 / 12 paid'),
          ),
          findsOneWidget,
        );
        expect(key('host-event-d1'), findsNothing);
        await t.tap(key('seg-draft'));
        await t.pumpAndSettle();
        expect(
          find.descendant(
            of: key('host-event-d1'),
            matching: find.text('Draft'),
          ),
          findsOneWidget,
        );
        await t.tap(key('seg-ended'));
        await t.pumpAndSettle();
        expect(
          find.descendant(
            of: key('host-event-x1'),
            matching: find.text('Ended'),
          ),
          findsOneWidget,
        );
        await t.tap(key('seg-draft'));
        await t.pumpAndSettle();
        await t.tap(key('host-event-d1'));
        await t.pumpAndSettle();
        expect(where(router), '/host-mode/events/d1/edit');
      },
    );

    testWidgets(
      'new_event_button_sits_above_the_tab_bar_and_does_not_hide_the_last_card',
      (t) async {
        final host = FakeHost(
          profile: hostMe(),
          events: [for (var i = 1; i <= 40; i++) hostEvent('e$i')],
        );
        final router = await pumpApp(
          t,
          location: '/host-mode/events',
          host: host,
        );
        expect(
          t.getRect(key('new-event-button')).bottom,
          lessThanOrEqualTo(t.getRect(key('tab-bar')).top),
        );
        await t.dragUntilVisible(
          key('host-event-e40'),
          find.byType(ListView),
          const Offset(0, -300),
        );
        await t.drag(find.byType(ListView), const Offset(0, -600));
        await t.pumpAndSettle();
        expect(
          t.getRect(key('host-event-e40')).bottom,
          lessThanOrEqualTo(t.getRect(key('new-event-button')).top),
        );
        await t.tap(key('new-event-button'));
        await t.pumpAndSettle();
        expect(where(router), '/host-mode/new');
      },
    );
  });

  group('create', () {
    testWidgets(
      'new_event_form_has_description_when_where_price_spots_policy_chips_and_completion_note',
      (t) async {
        await pumpApp(t, location: '/host-mode/new');
        for (final k in [
          'form-title',
          'form-description',
          'field-when',
          'form-venue',
          'form-price',
          'spots-value',
          'form-accept',
        ]) {
          expect(key(k), findsOneWidget, reason: k);
        }
        expect(t.widget<Text>(key('spots-value')).data, '12');
        for (final c in [
          'Make',
          'Move',
          'Meet',
          'Other',
          '24 h before',
          '48 h before',
          '7 days before',
          'No refunds',
        ]) {
          expect(find.text(c), findsOneWidget, reason: c);
        }
        expect(
          find.textContaining('completes automatically 24 hours after it ends'),
          findsOneWidget,
        );
      },
    );

    testWidgets('publish_disabled_until_valid', (t) async {
      final host = FakeHost(profile: hostMe());
      final router = await pumpApp(t, location: '/host-mode/new', host: host);
      expect(enabled(t, 'publish'), isFalse);
      await fillValid(t);
      expect(enabled(t, 'publish'), isTrue);
      await t.tap(key('publish'));
      await t.pumpAndSettle();
      final (form, id) = host.saved.single;
      expect(
        [form.title, form.venue, form.area, form.capacity, form.priceSen, id],
        ['Sunset yoga', 'Deck 5', 'Bangsar', 12, 0, null],
      );
      expect(host.published, ['new1']);
      expect(where(router), '/host-mode/events');
    });

    testWidgets('save_draft_saves_without_publishing', (t) async {
      final host = FakeHost(profile: hostMe());
      final router = await pumpApp(t, location: '/host-mode/new', host: host);
      await t.enterText(key('form-title'), 'Half an idea');
      await t.pump();
      await t.tap(key('save-draft'));
      await t.pumpAndSettle();
      expect(host.saved.single.$1.title, 'Half an idea');
      expect(host.published, isEmpty);
      expect(where(router), '/host-mode/events');
    });

    testWidgets('contact_info_in_description_shows_server_error', (t) async {
      final host = FakeHost(
        profile: hostMe(),
        saveError: const HostError('contact_info_not_allowed'),
      );
      final router = await pumpApp(t, location: '/host-mode/new', host: host);
      await fillValid(t);
      await t.enterText(key('form-description'), 'call me 0123456789');
      await t.tap(key('publish'));
      await t.pumpAndSettle();
      expect(
        find.text(
          "Phone numbers and social handles aren't allowed in the title or description.",
        ),
        findsOneWidget,
      );
      expect(where(router), '/host-mode/new');
    });
  });

  group('edit and delete', () {
    final live = FakeHost(
      profile: hostMe(),
      events: [hostEvent('e1')],
      gross: 30000,
    );

    testWidgets(
      'edit_published_locks_date_venue_price_policy_and_clamps_spots_at_sold',
      (t) async {
        await pumpApp(t, location: '/host-mode/events/e1/edit', host: live);
        for (final k in [
          'lock-when',
          'lock-where',
          'lock-price',
          'lock-policy',
          'lock-accept',
          'lock-categories',
        ]) {
          expect(key(k), findsOneWidget, reason: k);
        }
        expect(t.widget<TextField>(key('form-venue')).readOnly, isTrue);
        expect(t.widget<TextField>(key('form-price')).readOnly, isTrue);
        expect(
          find.text("8 already joined, so spots can't go below 8."),
          findsOneWidget,
        );
        for (var i = 0; i < 7; i++) {
          await t.tap(key('spots-minus'));
        }
        await t.pump();
        expect(t.widget<Text>(key('spots-value')).data, '8');
        for (var i = 0; i < 40; i++) {
          await t.tap(key('spots-plus'));
        }
        await t.pump();
        expect(t.widget<Text>(key('spots-value')).data, '40');
      },
    );

    testWidgets('edit_can_change_title_description_spots_and_saves', (t) async {
      final host = FakeHost(profile: hostMe(), events: [hostEvent('e1')]);
      final router = await pumpApp(
        t,
        location: '/host-mode/events/e1/edit',
        host: host,
      );
      await t.enterText(key('form-title'), 'New title');
      await t.enterText(key('form-description'), 'New words');
      await t.tap(key('spots-minus'));
      await t.tap(key('spots-minus'));
      await t.pump();
      await t.tap(key('save-changes'));
      await t.pumpAndSettle();
      expect(host.updated, [('e1', 'New title', 'New words', 10)]);
      expect(where(router), '/host-mode/events');
    });

    testWidgets(
      'delete_sheet_shows_guest_count_and_total_and_confirms_then_returns_to_events',
      (t) async {
        final host = FakeHost(
          profile: hostMe(),
          events: [hostEvent('e1')],
          gross: 30000,
        );
        final router = await pumpApp(
          t,
          location: '/host-mode/events/e1/edit',
          host: host,
        );
        await t.tap(key('delete-event'));
        await t.pumpAndSettle();
        expect(
          find.text(
            "8 guests have paid RM 300 in total. All of them are refunded in full and told the event was cancelled. This can't be undone.",
          ),
          findsOneWidget,
        );
        await t.tap(key('delete-yes'));
        await t.pumpAndSettle();
        expect(host.deleted, ['e1']);
        expect(where(router), '/host-mode/events');
      },
    );

    testWidgets('delete_after_start_is_hidden', (t) async {
      final started = hostEvent(
        'e1',
        starts: clock.subtract(const Duration(hours: 3)),
      );
      await pumpApp(
        t,
        location: '/host-mode/events/e1/edit',
        host: FakeHost(profile: hostMe(), events: [started]),
      );
      expect(key('form-title'), findsOneWidget);
      expect(key('delete-event'), findsNothing);
    });
  });

  group('profile', () {
    testWidgets('host_profile_rows_and_switch_back_to_attendee', (t) async {
      final router = await pumpApp(t, location: '/host-mode/profile');
      expect(find.text('Mei Studio'), findsOneWidget);
      expect(find.text('★ 4.8 · 36 reviews'), findsOneWidget);
      await t.tap(find.text('View public profile'));
      await t.pumpAndSettle();
      expect(where(router), '/host/h1');
      router.go('/host-mode/profile');
      await t.pumpAndSettle();
      await t.tap(find.text('Payout account'));
      await t.pumpAndSettle();
      expect(where(router), '/host-mode/payout-account');
      expect(
        t.widget<TextField>(key('apply-holder')).controller!.text,
        'Mei Studio Sdn Bhd',
      );
      router.go('/host-mode/profile');
      await t.pumpAndSettle();
      await t.tap(key('attendee-mode-card'));
      await t.pumpAndSettle();
      expect(where(router), '/explore');
    });
  });
}
