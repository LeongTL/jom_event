import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/booking/data/receipt_picker.dart';
import 'package:jom/features/host/domain/host.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/pump_app.dart';

HostProfile empty({String? qr}) => HostProfile(
  id: 'h1',
  name: 'Mei Studio',
  area: 'Bangsar',
  holder: '',
  bank: '',
  accountNumber: '',
  qrPath: qr,
);

bool saveEnabled(WidgetTester t) {
  final b = t.widget<FilledButton>(
    find.descendant(
      of: key('details-save'),
      matching: find.byType(FilledButton),
    ),
  );
  return b.onPressed != null;
}

void main() {
  testWidgets('existing_details_are_prefilled', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/payment-details',
      host: FakeHost(profile: hostMe()),
    );
    expect(find.text('Maybank'), findsOneWidget);
    expect(find.text('1234564821'), findsOneWidget);
    expect(find.text('Mei Studio Sdn Bhd'), findsOneWidget);
  });

  testWidgets('nothing_filled_keeps_save_disabled', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/payment-details',
      host: FakeHost(profile: empty()),
    );
    expect(saveEnabled(t), isFalse);
  });

  testWidgets('partial_bank_without_qr_shows_what_is_missing', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/payment-details',
      host: FakeHost(profile: empty()),
    );
    await t.enterText(key('details-bank'), 'Maybank');
    await t.pumpAndSettle();
    expect(saveEnabled(t), isFalse);
    expect(
      find.text(
        'Add the bank, account holder and account number, or a DuitNow QR image.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('full_bank_enables_save_and_saves', (t) async {
    final h = FakeHost(profile: empty());
    await pumpApp(t, location: '/host-mode/payment-details', host: h);
    await t.enterText(key('details-holder'), 'Mei Ling');
    await t.enterText(key('details-bank'), 'Maybank');
    await t.enterText(key('details-number'), '111');
    await t.pumpAndSettle();
    expect(saveEnabled(t), isTrue);
    await t.tap(key('details-save'));
    await t.pumpAndSettle();
    expect(h.savedDetails, [('Mei Ling', 'Maybank', '111', false)]);
  });

  testWidgets('saving_uploads_the_qr_then_calls_repository', (t) async {
    final h = FakeHost(profile: empty());
    final bytes = Uint8List.fromList([1, 2, 3]);
    await pumpApp(
      t,
      location: '/host-mode/payment-details',
      host: h,
      overrides: [receiptPickerProvider.overrideWithValue((_) async => bytes)],
    );
    await t.tap(key('details-qr'));
    await t.pumpAndSettle();
    expect(saveEnabled(t), isTrue);
    await t.tap(key('details-save'));
    await t.pumpAndSettle();
    expect(h.savedDetails, [('', '', '', true)]);
  });

  testWidgets('warning_says_these_are_shown_to_guests_who_book', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/payment-details',
      host: FakeHost(profile: hostMe()),
    );
    expect(
      find.textContaining('shown to guests who book your events'),
      findsOneWidget,
    );
  });

  testWidgets('host_profile_links_to_payment_details', (t) async {
    await pumpApp(
      t,
      location: '/host-mode/profile',
      host: FakeHost(profile: hostMe()),
    );
    await t.tap(find.text('Payment details'));
    await t.pumpAndSettle();
    expect(key('payment-details'), findsOneWidget);
  });
}
