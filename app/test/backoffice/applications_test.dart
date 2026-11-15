import 'package:flutter_test/flutter_test.dart';
import 'package:jom/backoffice/admin/admin_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, Session;

import '../helpers/fake_auth.dart';
import '../helpers/fake_backoffice.dart';
import '../helpers/pump_app.dart' show key;

Session ada() =>
    fakeSession(phone: null, email: 'ada@example.com', name: 'Ada Admin');

final _mei = PendingApplication(
  userId: 'u1',
  hostName: 'Mei Studio',
  area: 'PJ',
  createdAt: DateTime.utc(2030, 1, 2, 3),
);
const _meiFull = Application(
  hostName: 'Mei Studio',
  area: 'PJ',
  bio: 'Sunrise runs and coffee',
  ssmNumber: '202001000001',
  accountHolder: 'Mei Tan',
  bank: 'Maybank',
  accountNumber: '1122334455',
  qrPath: null,
  status: 'pending',
  rejectReason: null,
);

BoWorld world({List<PendingApplication>? pending, FakeAdmin? admin}) => BoWorld(
  isAdmin: true,
  aal2: true,
  signedIn: ada(),
  admin: admin ?? FakeAdmin(pending: pending ?? [_mei], full: {'u1': _meiFull}),
);

void main() {
  testWidgets('no_pending_applications_says_so', (t) async {
    await pumpBackOffice(t, world(pending: []));
    expect(key('app-empty'), findsOneWidget);
  });

  testWidgets('lists_each_pending_application_with_name_and_area', (t) async {
    await pumpBackOffice(t, world());
    expect(key('app-row-u1'), findsOneWidget);
    expect(find.text('Mei Studio'), findsOneWidget);
    expect(find.textContaining('PJ'), findsOneWidget);
  });

  testWidgets('opening_one_shows_the_full_application', (t) async {
    await pumpBackOffice(t, world());
    await t.tap(key('app-row-u1'));
    await t.pumpAndSettle();
    expect(key('app-detail'), findsOneWidget);
    for (final text in [
      'Sunrise runs and coffee',
      '202001000001',
      'Mei Tan',
      'Maybank',
      '1122334455',
    ]) {
      expect(find.textContaining(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('approve_calls_the_decision_and_the_row_is_gone', (t) async {
    final w = world();
    await pumpBackOffice(t, w);
    await t.tap(key('app-row-u1'));
    await t.pumpAndSettle();
    await t.tap(key('app-approve'));
    await t.pumpAndSettle();
    expect(w.admin.reviews, [('u1', 'approve', null)]);
    expect(key('app-row-u1'), findsNothing);
    expect(key('app-empty'), findsOneWidget);
  });

  testWidgets('reject_needs_a_reason_then_sends_it', (t) async {
    final w = world();
    await pumpBackOffice(t, w);
    await t.tap(key('app-row-u1'));
    await t.pumpAndSettle();
    await t.tap(key('app-reject'));
    await t.pumpAndSettle();
    await t.tap(key('app-reject-send'));
    await t.pumpAndSettle();
    expect(w.admin.reviews, isEmpty);
    expect(find.text('Give a reason first.'), findsOneWidget);
    await t.enterText(key('app-reject-reason'), '  Photos missing  ');
    await t.tap(key('app-reject-send'));
    await t.pumpAndSettle();
    expect(w.admin.reviews, [('u1', 'reject', 'Photos missing')]);
    expect(key('app-empty'), findsOneWidget);
  });

  testWidgets('a_refused_decision_says_why_and_keeps_the_application', (
    t,
  ) async {
    final admin = FakeAdmin(pending: [_mei], full: {'u1': _meiFull})
      ..reviewError = const PostgrestException(message: 'mfa_required');
    await pumpBackOffice(t, world(admin: admin));
    await t.tap(key('app-row-u1'));
    await t.pumpAndSettle();
    await t.tap(key('app-approve'));
    await t.pumpAndSettle();
    expect(find.textContaining('two-factor'), findsOneWidget);
    expect(key('app-detail'), findsOneWidget);
  });

  testWidgets('already_decided_by_someone_else_says_so', (t) async {
    final admin = FakeAdmin(pending: [_mei], full: {'u1': _meiFull})
      ..reviewError = const PostgrestException(message: 'bad_state');
    await pumpBackOffice(t, world(admin: admin));
    await t.tap(key('app-row-u1'));
    await t.pumpAndSettle();
    await t.tap(key('app-approve'));
    await t.pumpAndSettle();
    expect(find.textContaining('already been decided'), findsOneWidget);
  });

  testWidgets('list_and_detail_fit_a_phone', (t) async {
    await pumpBackOffice(t, world(), width: 390, height: 800);
    expect(key('app-row-u1'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(key('app-row-u1'));
    await t.pumpAndSettle();
    expect(key('app-detail'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
